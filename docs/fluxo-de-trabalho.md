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
- Force push e apagar branch são bloqueados pelo GitHub nas branches pessoais.
- O PR da `marcos` para a `main` entra com "Rebase and merge" (histórico linear). Depois dele, a `marcos` e as branches pessoais são sincronizadas com a `main` (veja abaixo).
- Configure o e-mail de commit com um e-mail associado à sua conta do GitHub (ou o e-mail noreply dela).
- O repositório é público: nunca commite senha, chave, token nem dado pessoal.
- O build da ISO só roda em Linux. Veja `docs/ambiente-de-build.md`.

## Para o revisor final (Marcos)

- Revisar e aprovar os PRs para `marcos` e mergear com merge commit.
- Abrir e mergear o PR de `marcos` para `main`.
- O merge de `marcos` para `main` exige o bypass de Admin e o método "Rebase and merge" (precisa estar ligado em Settings, Pull Requests, "Allow rebase merging"). Na CLI use `gh pr merge <número> --rebase --admin`; na página do PR, marque "Merge without waiting for requirements to be met" e escolha "Rebase and merge".
- O rebase recria os commits na `main` com SHAs novos. A `marcos` fica divergente (mesmo conteúdo, SHAs diferentes) e o `git merge --ff-only origin/main` falha. Depois de cada merge na `main`, rode o script de sincronização:

  ```
  scripts/sync-branches.sh
  ```

  O script faz, nesta ordem:
  1. `git fetch origin --prune` e confere que o working tree está limpo.
  2. Realinha a `marcos` com a `main` (force push com `--force-with-lease`, permitido pelo bypass de Admin). Só faz isso se todos os commits da `marcos` já estiverem na `main` (conferido com `git cherry`). Se houver commit que a `main` não tem, pula a `marcos` e avisa.
  3. Avança `renato`, `giulliano`, `gudryan`, `jean` e `sayuri` por fast-forward para a `main`, sem checkout e sem merge local. Branch com commits próprios é recusada pelo servidor: o script avisa e segue para a próxima.

  O script age no repositório onde ele está e só roda se o `origin` for o `nexus-os`.
- Cada integrante precisa atualizar a própria branch depois da sincronização: `git fetch origin`, `git switch <sua-branch>` e `git merge --no-edit origin/main`.

## Erros comuns

- Push rejeitado com aviso de violação de regra do repositório: você tentou push em `main` ou `marcos`, force push ou apagar branch. Abra um PR.
- Sem botão de merge no PR: esperado, só o revisor final mergeia.
