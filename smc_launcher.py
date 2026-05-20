#!/usr/bin/env python3
"""Safe launcher for the SMC observational indicator environment.

This utility prepares a MetaTrader 5 installation for visual observation. It
does not send orders, import trading robot modules, connect to robot databases,
or automate fragile GUI clicks.
"""

from __future__ import annotations

import argparse
import copy
import json
import logging
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

try:
    import winreg
except ImportError:  # pragma: no cover - used only outside Windows.
    winreg = None


REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = REPO_ROOT / "config" / "smc_launcher.local.json"
EXAMPLE_CONFIG_PATH = REPO_ROOT / "config" / "smc_launcher.example.json"
LOGGER_NAME = "smc_launcher"
SUPPORTED_TIMEFRAMES = {"M1", "M5", "M15", "M30", "H1", "H4", "D1"}
SAFE_DEFAULT_CONFIG: dict[str, Any] = {
    "mode": "paper",
    "dry_run": True,
    "account": {
        "login": 0,
        "password": "",
        "server": "",
    },
    "mt5": {
        "terminal_path": "",
        "data_path": "",
        "startup_timeout_seconds": 30,
    },
    "chart": {
        "symbol": "WIN$",
        "symbol_candidates": ["WIN$"],
        "timeframe": "M1",
        "template_name": "",
    },
    "indicator": {
        "install_sources": True,
        "compile_after_install": False,
        "source_indicator": "MQL5/Indicators/SMC_Observacional_WIN.mq5",
        "source_include_dir": "MQL5/Include/SMC",
        "target_indicator_name": "SMC_Observacional_WIN.mq5",
    },
    "safety": {
        "require_paper_environment": True,
        "allowed_account_logins": [],
        "allowed_servers": [],
        "forbidden_server_keywords": ["real", "live"],
    },
    "automation": {
        "attach_indicator_automatically": False,
        "allow_gui_clicks": False,
    },
    "logging": {
        "log_dir": "logs",
        "level": "INFO",
    },
}


class LauncherError(Exception):
    """Expected launcher failure with an actionable message."""


@dataclass
class StepResult:
    name: str
    status: str
    detail: str


class SMCLauncher:
    def __init__(self, config: dict[str, Any], args: argparse.Namespace) -> None:
        self.config = config
        self.args = args
        self.dry_run = bool(args.dry_run or config.get("dry_run", False))
        self.logger = logging.getLogger(LOGGER_NAME)
        self.results: list[StepResult] = []
        self.terminal_path: Path | None = None
        self.metaeditor_path: Path | None = None
        self.data_path: Path | None = None
        self.mt5_module: Any | None = None
        self.mt5_initialized = False

    def run(self) -> int:
        try:
            self.validate_config()
            self.locate_terminal()
            if not self.args.no_launch:
                self.launch_terminal()
            self.initialize_optional_mt5_api()
            self.resolve_data_path()
            self.validate_account_connection()
            self.ensure_indicator_available()
            self.prepare_symbol_context()
            self.validate_template()
            self.print_manual_chart_steps()
            self.add_result("Resumo", "OK", "Ambiente preparado sem acoplamento operacional.")
            return 0
        except LauncherError as exc:
            self.logger.error(str(exc))
            self.add_result("Erro", "FAIL", str(exc))
            return 2
        except Exception:
            self.logger.exception("Falha inesperada no launcher.")
            self.add_result("Erro", "FAIL", "Falha inesperada. Consulte o log local.")
            return 1
        finally:
            self.shutdown_optional_mt5_api()
            self.print_results()

    def validate_config(self) -> None:
        mode = str(self.config.get("mode", "")).strip().lower()
        if mode != "paper":
            raise LauncherError("Modo inseguro: configure 'mode' como 'paper'.")

        timeframe = self.chart_config.get("timeframe", "M1").upper()
        if timeframe not in SUPPORTED_TIMEFRAMES:
            raise LauncherError(
                f"Timeframe '{timeframe}' nao suportado. Use um de: "
                f"{', '.join(sorted(SUPPORTED_TIMEFRAMES))}."
            )

        automation = self.config.get("automation", {})
        if automation.get("allow_gui_clicks") or automation.get("attach_indicator_automatically"):
            raise LauncherError(
                "Automacao GUI/attach automatico foi solicitado, mas permanece bloqueado "
                "por seguranca. Use template manual ou anexe o indicador pelo MT5."
            )

        self.add_result("Config", "OK", f"Modo {mode.upper()} validado.")

    @property
    def mt5_config(self) -> dict[str, Any]:
        return self.config.setdefault("mt5", {})

    @property
    def chart_config(self) -> dict[str, Any]:
        return self.config.setdefault("chart", {})

    @property
    def indicator_config(self) -> dict[str, Any]:
        return self.config.setdefault("indicator", {})

    @property
    def safety_config(self) -> dict[str, Any]:
        return self.config.setdefault("safety", {})

    def locate_terminal(self) -> None:
        configured = first_non_empty(
            self.args.terminal_path,
            os.environ.get("SMC_MT5_TERMINAL_PATH"),
            self.mt5_config.get("terminal_path"),
        )

        candidates: list[Path] = []
        if configured:
            candidates.append(Path(configured).expanduser())
        candidates.extend(find_mt5_terminals())

        for candidate in candidates:
            if candidate.is_file() and candidate.name.lower() in {"terminal64.exe", "terminal.exe"}:
                self.terminal_path = candidate.resolve()
                self.metaeditor_path = find_metaeditor_near(candidate)
                detail = str(self.terminal_path)
                if self.metaeditor_path:
                    detail += f" | MetaEditor: {self.metaeditor_path}"
                self.add_result("Localizar MT5", "OK", detail)
                return

        raise LauncherError(
            "Nao encontrei terminal64.exe. Configure mt5.terminal_path no JSON "
            "ou defina SMC_MT5_TERMINAL_PATH."
        )

    def launch_terminal(self) -> None:
        if self.terminal_path is None:
            raise LauncherError("Terminal MT5 nao foi localizado.")

        if self.dry_run:
            self.add_result("Abrir MT5", "DRY-RUN", f"Abriria {self.terminal_path}")
            return

        self.logger.info("Abrindo MT5: %s", self.terminal_path)
        process = subprocess.Popen([str(self.terminal_path)], close_fds=True)

        timeout = int(self.mt5_config.get("startup_timeout_seconds", 30))
        deadline = time.time() + max(5, timeout)
        while time.time() < deadline:
            if process.poll() is not None:
                raise LauncherError(
                    f"MT5 encerrou durante a inicializacao. Exit code={process.returncode}."
                )
            time.sleep(1)
            if self._terminal_looks_ready():
                self.add_result("Abrir MT5", "OK", "Processo do terminal permanece ativo.")
                return

        self.add_result(
            "Abrir MT5",
            "WARN",
            "Processo segue ativo, mas a prontidao completa deve ser confirmada visualmente.",
        )

    def _terminal_looks_ready(self) -> bool:
        # Basic readiness: process is open long enough. Deep validation happens via
        # optional MetaTrader5 Python API when available.
        return True

    def initialize_optional_mt5_api(self) -> None:
        try:
            import MetaTrader5 as mt5  # type: ignore
        except ImportError:
            self.add_result(
                "API MT5 Python",
                "WARN",
                "Pacote MetaTrader5 nao instalado; validacoes de conta/simbolo serao manuais.",
            )
            return

        if self.args.no_launch:
            self.add_result(
                "API MT5 Python",
                "SKIP",
                "Ignorada porque --no-launch foi usado.",
            )
            return

        if self.dry_run:
            self.add_result("API MT5 Python", "DRY-RUN", "Nao inicializada em dry-run.")
            return

        self.mt5_module = mt5
        terminal = str(self.terminal_path) if self.terminal_path else None
        initialized = mt5.initialize(path=terminal) if terminal else mt5.initialize()
        if not initialized:
            last_error = mt5.last_error()
            self.add_result(
                "API MT5 Python",
                "WARN",
                f"Nao foi possivel inicializar API MT5: {last_error}. Validacao manual necessaria.",
            )
            self.mt5_module = None
            return

        self.mt5_initialized = True
        info = mt5.terminal_info()
        detail = "API inicializada."
        if info is not None:
            detail += f" Terminal data_path={getattr(info, 'data_path', '')}"
        self.add_result("API MT5 Python", "OK", detail)

    def resolve_data_path(self) -> None:
        configured = first_non_empty(
            self.args.data_path,
            os.environ.get("SMC_MT5_DATA_PATH"),
            self.mt5_config.get("data_path"),
        )

        if configured:
            path = Path(configured).expanduser()
            if not (path / "MQL5").is_dir():
                raise LauncherError(f"Data path configurado nao contem pasta MQL5: {path}")
            self.data_path = path.resolve()
            self.add_result("Data path MT5", "OK", str(self.data_path))
            return

        if self.mt5_module is not None:
            info = self.mt5_module.terminal_info()
            data_path = getattr(info, "data_path", "") if info is not None else ""
            if data_path and (Path(data_path) / "MQL5").is_dir():
                self.data_path = Path(data_path).resolve()
                self.add_result("Data path MT5", "OK", str(self.data_path))
                return

        guessed = find_recent_mt5_data_path()
        if guessed is not None:
            self.data_path = guessed
            self.add_result(
                "Data path MT5",
                "WARN",
                f"Usando pasta mais recente encontrada: {self.data_path}. Configure explicitamente se houver varios terminais.",
            )
            return

        raise LauncherError(
            "Nao consegui localizar o data path do MT5. Abra o terminal em "
            "'Arquivo > Abrir Pasta de Dados' e configure mt5.data_path."
        )

    def validate_account_connection(self) -> None:
        if self.mt5_module is None:
            self.add_result(
                "Conta conectada",
                "MANUAL",
                "Confirme no MT5 se a conta PAPER esta conectada no canto inferior direito.",
            )
            return

        account = self.mt5_module.account_info()
        if account is None:
            raise LauncherError("API MT5 nao retornou conta conectada. Faça login na conta PAPER.")

        login = int(getattr(account, "login", 0))
        server = str(getattr(account, "server", ""))

        allowed_logins = {int(value) for value in self.safety_config.get("allowed_account_logins", [])}
        allowed_servers = {str(value).lower() for value in self.safety_config.get("allowed_servers", [])}
        forbidden_keywords = [
            str(value).lower()
            for value in self.safety_config.get("forbidden_server_keywords", [])
        ]

        if allowed_logins and login not in allowed_logins:
            raise LauncherError(f"Conta {login} nao esta na lista safety.allowed_account_logins.")

        if allowed_servers and server.lower() not in allowed_servers:
            raise LauncherError(f"Servidor '{server}' nao esta em safety.allowed_servers.")

        if self.safety_config.get("require_paper_environment", True):
            lowered_server = server.lower()
            for keyword in forbidden_keywords:
                if keyword and keyword in lowered_server:
                    raise LauncherError(
                        f"Servidor '{server}' parece LIVE/REAL por conter '{keyword}'. "
                        "Use uma maquina/conta PAPER."
                    )

        self.add_result("Conta conectada", "OK", f"Login={login} Server={server}")

    def ensure_indicator_available(self) -> None:
        if self.args.no_install or not self.indicator_config.get("install_sources", True):
            self.add_result("Indicador", "SKIP", "Instalacao de fontes desativada.")
            return

        if self.data_path is None:
            raise LauncherError("Data path MT5 nao esta definido para instalar indicador.")

        source_indicator = resolve_repo_path(self.indicator_config["source_indicator"])
        source_include = resolve_repo_path(self.indicator_config["source_include_dir"])
        if not source_indicator.is_file():
            raise LauncherError(f"Indicador fonte nao encontrado: {source_indicator}")
        if not source_include.is_dir():
            raise LauncherError(f"Includes fonte nao encontrados: {source_include}")

        target_indicator = (
            self.data_path
            / "MQL5"
            / "Indicators"
            / str(self.indicator_config.get("target_indicator_name", source_indicator.name))
        )
        target_include = self.data_path / "MQL5" / "Include" / "SMC"

        if self.dry_run:
            self.add_result(
                "Indicador",
                "DRY-RUN",
                f"Copiaria {source_indicator} -> {target_indicator} e includes -> {target_include}",
            )
            return

        copy_file_if_changed(source_indicator, target_indicator, self.logger)
        copy_tree_files_if_changed(source_include, target_include, self.logger)
        self.add_result("Indicador", "OK", f"Fontes disponiveis em {target_indicator.parent}")

        if self.indicator_config.get("compile_after_install", False):
            self.compile_installed_indicator(target_indicator)
        else:
            self.add_result(
                "Compilacao",
                "SKIP",
                "compile_after_install=false. Compile pelo MetaEditor se o .ex5 ainda nao existir.",
            )

    def compile_installed_indicator(self, target_indicator: Path) -> None:
        if self.metaeditor_path is None or not self.metaeditor_path.is_file():
            self.add_result("Compilacao", "WARN", "MetaEditor nao localizado para compilacao automatica.")
            return

        if self.dry_run:
            self.add_result("Compilacao", "DRY-RUN", f"Compilaria {target_indicator}")
            return

        log_path = Path(self.config["logging"]["log_dir"]) / "metaeditor_compile.log"
        log_path = resolve_repo_path(log_path)
        log_path.parent.mkdir(parents=True, exist_ok=True)

        args = [
            str(self.metaeditor_path),
            f"/compile:{target_indicator}",
            f"/log:{log_path}",
            f"/inc:{self.data_path / 'MQL5'}",
        ]
        subprocess.run(args, check=False)
        log_text = log_path.read_text(encoding="utf-16", errors="ignore") if log_path.exists() else ""
        if "0 errors" in log_text:
            self.add_result("Compilacao", "OK", "MetaEditor retornou log sem erros.")
        else:
            self.add_result(
                "Compilacao",
                "WARN",
                f"Compile manualmente no MetaEditor. Log: {log_path}",
            )

    def prepare_symbol_context(self) -> None:
        symbol = str(self.chart_config.get("symbol", "")).strip()
        candidates = [symbol]
        candidates.extend(str(value).strip() for value in self.chart_config.get("symbol_candidates", []))
        candidates = [value for value in dedupe(candidates) if value]

        if self.mt5_module is None:
            self.add_result(
                "Simbolo WIN",
                "MANUAL",
                f"Abra o Market Watch e confirme o simbolo. Candidatos: {', '.join(candidates)}",
            )
            return

        selected = ""
        for candidate in candidates:
            info = self.mt5_module.symbol_info(candidate)
            if info is not None and self.mt5_module.symbol_select(candidate, True):
                selected = candidate
                break

        if selected:
            self.add_result("Simbolo WIN", "OK", f"Simbolo selecionado no Market Watch: {selected}")
        else:
            self.add_result(
                "Simbolo WIN",
                "WARN",
                f"Nenhum candidato foi encontrado via API. Ajuste chart.symbol. Candidatos: {', '.join(candidates)}",
            )

    def validate_template(self) -> None:
        template = str(self.chart_config.get("template_name", "")).strip()
        if not template:
            self.add_result("Template", "SKIP", "Nenhum template configurado.")
            return

        if self.data_path is None:
            self.add_result("Template", "WARN", "Data path ausente; nao foi possivel validar template.")
            return

        template_name = template if template.lower().endswith(".tpl") else f"{template}.tpl"
        candidates = [
            self.data_path / "Profiles" / "Templates" / template_name,
            self.data_path / "MQL5" / "Profiles" / "Templates" / template_name,
        ]
        for candidate in candidates:
            if candidate.is_file():
                self.add_result("Template", "OK", f"Template encontrado: {candidate}")
                return

        self.add_result(
            "Template",
            "WARN",
            f"Template '{template_name}' nao encontrado. Aplique manualmente ou ajuste chart.template_name.",
        )

    def print_manual_chart_steps(self) -> None:
        symbol = str(self.chart_config.get("symbol", "WIN$")).strip() or "WIN$"
        timeframe = str(self.chart_config.get("timeframe", "M1")).upper()
        template = str(self.chart_config.get("template_name", "")).strip()

        steps = [
            "No MT5, confirme que esta em conta PAPER.",
            f"Abra um grafico do simbolo {symbol}.",
            f"Selecione o timeframe {timeframe}.",
            "No Navigator, anexe o indicador SMC_Observacional_WIN.",
        ]
        if template:
            steps.append(f"Opcional: aplique manualmente o template {template}.")

        detail = " | ".join(steps)
        self.add_result("Checklist manual", "INFO", detail)
        self.logger.info("Checklist manual:")
        for index, step in enumerate(steps, start=1):
            self.logger.info("%d. %s", index, step)

    def shutdown_optional_mt5_api(self) -> None:
        if self.mt5_module is not None and self.mt5_initialized:
            self.mt5_module.shutdown()
            self.mt5_initialized = False

    def add_result(self, name: str, status: str, detail: str) -> None:
        self.results.append(StepResult(name, status, detail))
        log_level = logging.INFO
        if status in {"WARN", "MANUAL", "SKIP", "DRY-RUN"}:
            log_level = logging.WARNING if status == "WARN" else logging.INFO
        if status == "FAIL":
            log_level = logging.ERROR
        self.logger.log(log_level, "[%s] %s - %s", status, name, detail)

    def print_results(self) -> None:
        print("\nSMC launcher checklist")
        print("======================")
        for result in self.results:
            print(f"[{result.status}] {result.name}: {result.detail}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare MT5 for the SMC observational indicator.")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG_PATH), help="Path to JSON config.")
    parser.add_argument("--terminal-path", default="", help="Override terminal64.exe path.")
    parser.add_argument("--data-path", default="", help="Override MT5 data path.")
    parser.add_argument("--dry-run", action="store_true", help="Show actions without launching/copying.")
    parser.add_argument("--no-launch", action="store_true", help="Do not open the MT5 terminal.")
    parser.add_argument("--no-install", action="store_true", help="Do not copy indicator sources.")
    parser.add_argument("--print-config", action="store_true", help="Print resolved config and exit.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config(Path(args.config))
    setup_logging(config)

    if args.print_config:
        print(json.dumps(config, indent=2, ensure_ascii=False))
        return 0

    logging.getLogger(LOGGER_NAME).info("Iniciando SMC launcher em modo isolado.")
    launcher = SMCLauncher(config, args)
    return launcher.run()


def load_config(path: Path) -> dict[str, Any]:
    resolved_path = path.expanduser()
    default_path = DEFAULT_CONFIG_PATH.expanduser()
    if not resolved_path.is_absolute():
        resolved_path = (REPO_ROOT / resolved_path).resolve()

    if not resolved_path.is_file():
        if resolved_path == default_path:
            print(
                "Config local nao encontrado: "
                f"{DEFAULT_CONFIG_PATH.relative_to(REPO_ROOT)}\n"
                "Para configurar a maquina, copie:\n"
                "  cp config/smc_launcher.example.json config/smc_launcher.local.json\n"
                "Rodando agora com defaults seguros em dry-run, sem senha e sem abrir terminal.",
                file=sys.stderr,
            )
            return copy.deepcopy(SAFE_DEFAULT_CONFIG)

        raise SystemExit(f"Config nao encontrado: {resolved_path}")

    with resolved_path.open("r", encoding="utf-8") as file:
        config = json.load(file)

    return config


def setup_logging(config: dict[str, Any]) -> None:
    logging_config = config.setdefault("logging", {})
    log_dir = resolve_repo_path(logging_config.get("log_dir", "logs"))
    log_dir.mkdir(parents=True, exist_ok=True)

    level_name = str(logging_config.get("level", "INFO")).upper()
    level = getattr(logging, level_name, logging.INFO)
    log_file = log_dir / f"smc_launcher_{datetime.now().strftime('%Y%m%d')}.log"

    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(level)
    logger.handlers.clear()

    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

    console = logging.StreamHandler()
    console.setFormatter(formatter)
    console.setLevel(level)
    logger.addHandler(console)

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(formatter)
    file_handler.setLevel(level)
    logger.addHandler(file_handler)

    logger.info("Log local: %s", log_file)


def first_non_empty(*values: Any) -> str:
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return ""


def resolve_repo_path(value: Any) -> Path:
    path = Path(str(value)).expanduser()
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def dedupe(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        key = value.lower()
        if key not in seen:
            seen.add(key)
            result.append(value)
    return result


def find_mt5_terminals() -> list[Path]:
    candidates: list[Path] = []
    candidates.extend(find_terminals_from_registry())

    roots = [
        Path(os.environ.get("ProgramFiles", r"C:\Program Files")),
        Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")),
    ]
    for root in roots:
        if not root.is_dir():
            continue
        for directory in root.glob("MetaTrader*"):
            candidates.extend([
                directory / "terminal64.exe",
                directory / "terminal.exe",
            ])

    return list(dict.fromkeys(candidates))


def find_terminals_from_registry() -> list[Path]:
    if winreg is None:
        return []

    candidates: list[Path] = []
    registry_roots = [
        (winreg.HKEY_CURRENT_USER, r"Software\MetaQuotes\MetaTrader 5"),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\MetaQuotes\MetaTrader 5"),
        (winreg.HKEY_LOCAL_MACHINE, r"Software\WOW6432Node\MetaQuotes\MetaTrader 5"),
    ]

    for root, key_path in registry_roots:
        try:
            with winreg.OpenKey(root, key_path) as key:
                for value_name in ("InstallPath", "Path"):
                    try:
                        value, _ = winreg.QueryValueEx(key, value_name)
                    except OSError:
                        continue
                    path = Path(str(value))
                    candidates.extend([path / "terminal64.exe", path / "terminal.exe"])
        except OSError:
            continue

    return candidates


def find_metaeditor_near(terminal: Path) -> Path | None:
    for name in ("MetaEditor64.exe", "metaeditor64.exe", "MetaEditor.exe", "metaeditor.exe"):
        candidate = terminal.parent / name
        if candidate.is_file():
            return candidate.resolve()
    return None


def find_recent_mt5_data_path() -> Path | None:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None

    root = Path(appdata) / "MetaQuotes" / "Terminal"
    if not root.is_dir():
        return None

    candidates = [path for path in root.iterdir() if (path / "MQL5").is_dir()]
    if not candidates:
        return None

    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return candidates[0].resolve()


def copy_file_if_changed(source: Path, target: Path, logger: logging.Logger) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and source.read_bytes() == target.read_bytes():
        logger.info("Sem alteracao: %s", target)
        return

    shutil.copy2(source, target)
    logger.info("Copiado: %s -> %s", source, target)


def copy_tree_files_if_changed(source_dir: Path, target_dir: Path, logger: logging.Logger) -> None:
    for source in source_dir.rglob("*"):
        if source.is_dir():
            continue
        relative = source.relative_to(source_dir)
        target = target_dir / relative
        copy_file_if_changed(source, target, logger)


if __name__ == "__main__":
    sys.exit(main())
