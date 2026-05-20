# Indicadores MT5

Projeto colaborativo para desenvolvimento de indicadores para MetaTrader 5.

## Indicador inicial

O primeiro modulo do projeto e o indicador observacional:

```text
MQL5/Indicators/SMC_Observacional_WIN.mq5
```

Ele desenha contexto SMC no grafico e grava eventos em CSV local. O indicador nao executa ordens e nao possui dependencia operacional com qualquer outro sistema.

## Launcher seguro

O utilitario `smc_launcher.py` prepara uma maquina PAPER com MetaTrader 5 para uso do indicador. Ele abre/valida o terminal quando possivel, copia os fontes para a pasta de dados do MT5 e orienta as etapas manuais de grafico.

Ele nao envia ordens, nao importa modulos de robo, nao conecta a banco externo e nao usa automacao fragil de clique.

## Estrutura

```text
config/        configuracao do launcher
MQL5/
  Indicators/   indicadores .mq5
  Include/SMC/  detectores, renderer, score e persistencia .mqh
docs/           documentacao do projeto
smc_launcher.py launcher isolado para ambiente PAPER
```

Arquivos fonte (`.mq5` e `.mqh`) entram no Git. Arquivos compilados (`.ex5`) e dados temporarios do terminal ficam fora do repositorio.

## Fluxo de trabalho

1. Atualize a branch principal:

   ```powershell
   git checkout main
   git pull origin main
   ```

2. Crie uma branch para sua alteracao:

   ```powershell
   git checkout -b feature/nome-do-indicador
   ```

3. Faça commits pequenos e objetivos:

   ```powershell
   git add .
   git commit -m "Cria indicador de media movel"
   ```

4. Envie a branch e abra um Pull Request:

   ```powershell
   git push origin feature/nome-do-indicador
   ```

5. Depois da revisao, o Pull Request pode ser unido na `main`.

## Uso no MetaTrader 5

Mantenha este repositorio separado da pasta de dados do MetaTrader. Para testar um indicador, copie o arquivo `.mq5` para a pasta `MQL5/Indicators` do terminal ou configure um link simbolico local.

No MetaTrader 5, a pasta de dados fica em:

```text
Arquivo > Abrir Pasta de Dados
```

## Compilacao

1. Copie a pasta `MQL5/Include/SMC` para a pasta `MQL5/Include` do terminal.
2. Copie `MQL5/Indicators/SMC_Observacional_WIN.mq5` para `MQL5/Indicators`.
3. Abra o arquivo no MetaEditor.
4. Compile.
5. Anexe o indicador ao grafico do WIN em qualquer timeframe. As leituras internas usam M5 para liquidez e M1 para estrutura.

Veja detalhes em `docs/smc-observacional.md`.

## Launcher

Crie uma configuracao local ignorada pelo Git:

```powershell
cp config/smc_launcher.example.json config/smc_launcher.local.json
```

Validacao sem abrir terminal nem copiar arquivos:

```powershell
python smc_launcher.py --dry-run --no-launch --no-install
```

Veja detalhes em `docs/smc-launcher.md`.
