# SMC Launcher

`smc_launcher.py` e um utilitario Python separado para preparar uma maquina PAPER com MetaTrader 5 para uso do indicador observacional SMC.

Ele pertence ao projeto `Indicadores` e nao depende do runtime do robo principal.

## O que ele faz

- Localiza uma instalacao do MetaTrader 5.
- Abre o terminal MT5, quando `--no-launch` nao e usado.
- Tenta validar a conta conectada quando o pacote Python `MetaTrader5` esta instalado.
- Localiza o data path do terminal.
- Copia os fontes do indicador e os includes `SMC` para a pasta `MQL5` do terminal.
- Seleciona o simbolo configurado no Market Watch quando a API Python do MT5 esta disponivel.
- Valida a existencia de template configurado.
- Gera logs locais em `logs/`.
- Imprime um checklist manual para abrir o grafico, selecionar timeframe e anexar o indicador.

## O que ele nao faz

- Nao envia ordens.
- Nao usa `CTrade`.
- Nao chama `OrderSend`.
- Nao importa modulos do robo principal.
- Nao conecta ao banco do robo.
- Nao compartilha risk manager, ML, configs operacionais ou runtime com outro projeto.
- Nao usa automacao fragil de clique.
- Nao anexa automaticamente o indicador no grafico quando isso depender de GUI.

## Configuracao

Arquivo versionado:

```text
config/smc_launcher.json
```

Para ajustes locais de maquina, crie uma copia ignorada pelo Git:

```text
config/smc_launcher.local.json
```

Campos principais:

- `mode`: deve permanecer `paper`.
- `mt5.terminal_path`: caminho opcional para `terminal64.exe`.
- `mt5.data_path`: caminho opcional para a pasta de dados do MT5.
- `chart.symbol`: simbolo do WIN no broker.
- `chart.timeframe`: timeframe desejado para o grafico, por padrao `M1`.
- `chart.template_name`: template opcional a validar.
- `indicator.install_sources`: copia os fontes para o terminal.
- `indicator.compile_after_install`: compila via MetaEditor se habilitado.
- `safety.allowed_account_logins`: lista opcional de contas permitidas.
- `safety.allowed_servers`: lista opcional de servidores permitidos.
- `safety.forbidden_server_keywords`: bloqueia servidores com termos como `real` e `live`.

## Uso

Validar sem abrir terminal nem copiar arquivos:

```powershell
python smc_launcher.py --dry-run --no-launch --no-install
```

Executar com config padrao:

```powershell
python smc_launcher.py
```

Executar com config local:

```powershell
python smc_launcher.py --config config/smc_launcher.local.json
```

## Checklist de execucao

1. Use uma maquina PAPER, separada do ambiente LIVE.
2. Confirme `mode=paper`.
3. Configure `chart.symbol` com o nome exato do WIN no broker.
4. Execute o launcher.
5. Confirme que a conta conectada e PAPER.
6. Abra um grafico do WIN.
7. Selecione o timeframe configurado.
8. Anexe manualmente `SMC_Observacional_WIN`.
9. Confirme que o CSV e os objetos visuais aparecem conforme esperado.

## Limitacoes de automacao do MT5

O Python consegue abrir o terminal, preparar arquivos e consultar algumas informacoes quando o pacote `MetaTrader5` esta instalado. Porem, anexar indicador a um grafico e aplicar template por GUI nao tem uma automacao Python simples, segura e documentada para este uso.

Por isso o launcher nao simula cliques, nao usa coordenadas de tela e nao tenta controlar a interface visual do terminal. Quando essa etapa for necessaria, ele orienta o usuario a executar manualmente no MT5.

## Logs

Logs locais ficam em:

```text
logs/smc_launcher_YYYYMMDD.log
```

Arquivos `.log` sao ignorados pelo Git.
