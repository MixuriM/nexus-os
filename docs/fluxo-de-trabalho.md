# Fluxo de trabalho

## Branches

- `main`: versão integrada. Só recebe PR da branch `marcos`, aberto e mergeado apenas por Marcos (revisor final).
- `marcos`: branch de integração. Recebe os PRs dos colegas. Só Marcos mergeia.
- `renato`, `giulliano`, `gudryan`, `jean`, `sayuri`: uma branch por pessoa.

## Primeira vez

1. Aceite o convite de colaborador (chega por e-mail e também fica em https://github.com/MixuriM/nexus-os/invitations).
2. Clone o repositório e configure seu nome e e-mail neste repositório (use o e-mail da sua conta do GitHub ou o noreply dela):

   ```
   git clone https://github.com/MixuriM/nexus-os.git
   cd nexus-os
   git config user.name "Seu Nome"
   git config user.email "email-da-sua-conta-github"
   ```

## Passo a passo para quem não é o revisor final

Use o nome da sua branch no lugar de `<sua-branch>`.

1. Antes de trabalhar, atualize a sua branch:

   ```
   git fetch origin
   git switch <sua-branch>
   git merge --no-edit origin/marcos
   ```

2. Trabalhe em commits pequenos:

   ```
   git add <arquivos>
   git commit -m "tipo: descrição curta"
   git push origin <sua-branch>
   ```

3. No GitHub, abra o PR com base `marcos` e comparação `<sua-branch>`. O GitHub sugere `main` como base por padrão: troque para `marcos`. Nunca use `main` como base.
4. Aguarde a revisão. Marcos aprova e faz o merge. O botão de merge não aparece para você, e isso é esperado.
5. Depois do merge, atualize a sua branch:

   ```
   git fetch origin
   git merge --no-edit origin/marcos
   ```

## Regras

- PRs pequenos e frequentes.
- Se o PR tiver conflito, resolva na sua branch: `git merge origin/marcos`, corrija os arquivos, faça o commit e o push.
- Nunca commite na branch de outra pessoa.
- Só merge commit. Force push e apagar branch são bloqueados pelo GitHub.
- Configure o e-mail de commit com um e-mail associado à sua conta do GitHub (ou o e-mail noreply dela).
- O repositório é público: nunca commite senha, chave, token nem dado pessoal.
- O build da ISO só roda em Linux. Veja `docs/ambiente-de-build.md`.

## Para o revisor final (Marcos)

- Revisar e aprovar os PRs para `marcos` e mergear com merge commit.
- Abrir e mergear o PR de `marcos` para `main`.
- Depois de cada merge na `main`, atualizar a `marcos`:

  ```
  git fetch origin
  git merge --ff-only origin/main
  git push origin marcos
  ```

  Se o `--ff-only` falhar (a `marcos` recebeu commits depois do merge), rode `git merge --no-edit origin/main` e depois `git push origin marcos`.

## Erros comuns

- Push rejeitado com aviso de violação de regra do repositório: você tentou push em `main` ou `marcos`, force push ou apagar branch. Abra um PR.
- Sem botão de merge no PR: esperado, só o revisor final mergeia.
