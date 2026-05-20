# Como colaborar

## Regras principais

- A branch `main` deve representar a versao estavel do projeto.
- Cada mudanca deve ser feita em uma branch separada.
- Pull Requests devem ter pelo menos uma revisao antes do merge.
- Evite commitar arquivos `.ex5`; eles sao gerados pelo MetaEditor.

## Padrao de branches

Use nomes curtos e descritivos:

```text
feature/nome-do-indicador
fix/correcao-descricao
docs/assunto
```

## Checklist antes do Pull Request

- O indicador compila no MetaEditor.
- O comportamento esperado foi testado em grafico.
- O Pull Request descreve o que mudou e como testar.
- Nao existem arquivos temporarios, logs ou compilados no commit.

## Resolvendo conflitos

Antes de começar uma nova alteracao, atualize a `main` local:

```powershell
git checkout main
git pull origin main
```

Se sua branch ficar atrasada:

```powershell
git checkout sua-branch
git merge main
```

Resolva os conflitos, compile novamente no MetaEditor e envie a branch atualizada.
