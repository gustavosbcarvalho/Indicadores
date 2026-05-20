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
