# SMC Observacional WIN

Este modulo e um indicador para MetaTrader 5. Ele observa contexto SMC, desenha objetos no grafico e persiste eventos para estudo posterior.

Ele nao envia ordens, nao gerencia posicoes e nao compartilha estado operacional com outro sistema.

## Arquivos

```text
MQL5/Indicators/SMC_Observacional_WIN.mq5
MQL5/Include/SMC/SMC_Types.mqh
MQL5/Include/SMC/SMC_EventBus.mqh
MQL5/Include/SMC/SMC_LiquidityDetector.mqh
MQL5/Include/SMC/SMC_StructureDetector.mqh
MQL5/Include/SMC/SMC_FVGDetector.mqh
MQL5/Include/SMC/SMC_VWAPContext.mqh
MQL5/Include/SMC/SMC_ScoreEngine.mqh
MQL5/Include/SMC/SMC_Renderer.mqh
MQL5/Include/SMC/SMC_PersistenceCSV.mqh
```

## Timeframes internos

- Liquidez: M5.
- BOS e CHOCH: M1.
- FVG: M1.
- VWAP: intradiario, calculado sobre barras M1 do dia.

O timeframe do grafico onde o indicador esta anexado nao muda essas leituras internas.

## Modulos

- `CSMCLiquidityDetector`: swing highs/lows M5, equal highs/lows e sweep confirmado por fechamento alem do swing.
- `CSMCStructureDetector`: swings M1, BOS, CHOCH e displacement por corpo de candle contra ATR.
- `CSMCFVGDetector`: FVG de 3 candles, com estado mitigado ou aberto.
- `CSMCVWAPContext`: VWAP intradiaria e lado do preco em relacao a ela.
- `CSMCScoreEngine`: score 0-100 e classificacao `STRONG`, `MEDIUM`, `WEAK` ou `NOISY`.
- `CSMCRenderer`: linhas, zonas, labels, setas, VWAP e painel de contexto.
- `CSMCPersistenceCSV`: exportacao local de eventos para CSV.

## Score inicial

Pesos padrao:

- Sweep confirmado: 20.
- BOS alinhado: 20.
- FVG alinhado: 15.
- VWAP alinhada: 15.
- Displacement alinhado: 10.
- Liquidez forte: 10.
- Tendencia alinhada: 10.

As entradas do indicador permitem alterar todos os pesos.

## Persistencia CSV

Arquivo padrao:

```text
SMC_Observacional_WIN.csv
```

No MetaTrader, arquivos criados por indicadores ficam na sandbox local de arquivos do terminal, normalmente acessivel em:

```text
Arquivo > Abrir Pasta de Dados > MQL5 > Files
```

Campos exportados:

- `timestamp`
- `symbol`
- `timeframe`
- `event_type`
- `direction`
- `price`
- `price2`
- `score`
- `mitigated`
- `tag`
- `details`
- `key`

O indicador usa a chave `key` para evitar duplicidade do mesmo evento na memoria e no arquivo CSV ja existente. Se o arquivo ja existe, as chaves anteriores sao carregadas na inicializacao.

Se `FileOpen` falhar, o erro e registrado no log do MetaTrader.

## Inputs de robustez visual

- `InpObjectPrefix`: prefixo unico dos objetos no grafico. Padrao: `SMC_OBS_WIN_`.
- `InpDrawLiquidity`: liga/desliga desenho de liquidez, swings, equal highs/lows e sweeps.
- `InpDrawStructure`: liga/desliga desenho de BOS, CHOCH, displacement, continuation e mean reversion.
- `InpDrawFVG`: liga/desliga desenho das zonas de FVG.
- `InpDrawVWAP`: liga/desliga linha de VWAP.
- `InpMaxRenderEvents`: limita quantos eventos recentes podem gerar objetos no grafico.
- `InpPersistCSV`: liga/desliga persistencia CSV.
- `InpDebugLogs`: liga/desliga logs informativos de diagnostico.

Por padrao, o indicador processa apenas quando surge novo candle M1 ou M5. `InpProcessEveryTick` existe para diagnostico, mas deve permanecer desligado no uso normal.

## Compilacao

1. Copie `MQL5/Include/SMC` para a pasta `MQL5/Include` do terminal.
2. Copie `MQL5/Indicators/SMC_Observacional_WIN.mq5` para `MQL5/Indicators`.
3. Abra o indicador no MetaEditor.
4. Compile.
5. Anexe no grafico do WIN.

## Proximos modulos sugeridos

- Normalizacao de sessoes da B3 e filtro por horario.
- Camada de replay para reconstruir eventos por data.
- Export JSON alem do CSV.
- Ajuste de sensibilidade por volatilidade do WIN.
- Painel historico de ultimos eventos.
- Modo de limpeza seletiva de objetos antigos.

## Checklist pre-merge

- Objetos usam prefixo unico `SMC_OBS_WIN_`.
- `OnDeinit` remove apenas objetos registrados como criados pelo indicador na sessao atual.
- Limpeza inicial por prefixo remove apenas objetos gerenciados e ocultos do proprio indicador.
- CSV grava header apenas quando o arquivo nao existe ou esta vazio.
- CSV carrega chaves existentes para evitar duplicar eventos ja persistidos.
- Falhas de `FileOpen` sao registradas no log.
- Processamento padrao ocorre apenas em novo candle M1/M5, nao a cada tick.
- Objetos antigos no grafico sao limitados por `InpMaxRenderEvents`.
- Flags visuais existem para liquidez, estrutura, FVG e VWAP.
- Persistencia CSV e logs de debug podem ser ligados/desligados por input.
- Codigo permanece sem `CTrade`, `OrderSend`, `Buy`, `Sell`, `PositionOpen`, `PositionClose` e `trade.mqh`.
