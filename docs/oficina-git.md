# Oficina de Git (1 hora)

Roteiro para a oficina da F2.2. Ao final, cada participante abriu um PR de teste com base `marcos`.
As regras de branches, PRs e merge estão em [fluxo-de-trabalho.md](fluxo-de-trabalho.md). Este roteiro só ensina a executá-las; em caso de dúvida, vale o que está lá.

## Antes da oficina

- Cada participante aceitou o convite de colaborador do repositório.
- Git instalado (`git --version` imprime uma versão) e acesso ao GitHub pelo terminal (HTTPS com a conta ou SSH).
- Quem conduz confirmou que cada participante tem a sua branch pessoal criada (lista em `fluxo-de-trabalho.md`).

## Roteiro

| Tempo | Etapa | O que fazer | Resultado esperado |
| --- | --- | --- | --- |
| 0 a 10 min | Conceitos | Quem conduz explica branch, commit, push, PR e por que só o revisor final faz merge | Todos sabem qual é a sua branch |
| 10 a 20 min | Clone e configuração | Seção "Primeira vez" do fluxo: `git clone`, `git config user.name` e `git config user.email` | `git config user.email` mostra o e-mail da conta do GitHub |
| 20 a 30 min | Atualizar a própria branch | `git fetch origin`, `git switch <sua-branch>`, `git merge --no-edit origin/marcos` | `git status` diz `working tree clean` |
| 30 a 40 min | Commit e push | Criar `oficina/<sua-branch>.md` com uma linha de texto; `git add oficina/<sua-branch>.md`, `git commit -m "docs: teste da oficina de git"`, `git push origin <sua-branch>` | O push termina sem erro |
| 40 a 50 min | Abrir o PR | No GitHub, **Pull requests**, **New pull request**: base `marcos`, comparação `<sua-branch>`. Confirmar que a base **não** é `main` | O PR aparece na lista, sem botão de merge para você |
| 50 a 60 min | Conflito | Veja abaixo | Conflito resolvido na sua branch e PR sem conflito |

## Exercício de conflito

Quem conduz cria, na `marcos`, o arquivo `oficina/conflito.md` com uma linha. Cada participante, na própria branch, cria o mesmo arquivo com outra linha (antes de atualizar) e depois:

```
git fetch origin
git merge origin/marcos
```

O Git avisa `CONFLICT` e marca o arquivo com `<<<<<<<`, `=======` e `>>>>>>>`. Edite o arquivo, deixe o texto final desejado e apague as marcações. Depois:

```
git add oficina/conflito.md
git commit
git push origin <sua-branch>
```

O PR deixa de mostrar conflito. Quem conduz fecha os PRs de teste sem merge e remove a pasta `oficina/` da `marcos` quando a oficina acabar.

## Critério de pronto

- Cada integrante abriu um PR de teste com base `marcos`.
- Quem conduz registra a data e a lista de PRs de teste no quadro de tarefas (issue da F2.2).
