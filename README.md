# Indicadores MT5

Projeto colaborativo para desenvolvimento de indicadores para MetaTrader 5.

## Estrutura

```text
MQL5/
  Indicators/   indicadores .mq5
  Include/      bibliotecas e helpers .mqh
  Experts/      EAs de apoio, quando necessario
docs/           documentacao do projeto
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
