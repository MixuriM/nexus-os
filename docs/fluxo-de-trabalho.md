# Fluxo de trabalho: passo a passo completo

Este documento explica, do zero, como trabalhar no repositório do Nexus OS com Git e GitHub. Foi escrito para quem **nunca usou Git**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. Leia a seção do passo inteira antes de executá-lo. A oficina de 1 hora que ensina este fluxo está em [oficina-git.md](oficina-git.md).

## Sumário

1. [Conceitos que você precisa saber](#conceitos-que-você-precisa-saber)
2. [Branches](#branches)
3. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
4. [O que você precisa ter antes](#o-que-você-precisa-ter-antes)
5. [Primeira vez](#primeira-vez)
6. [Passo a passo para quem não é o revisor final](#passo-a-passo-para-quem-não-é-o-revisor-final)
7. [Regras](#regras)
8. [Para o revisor final (Marcos)](#para-o-revisor-final-marcos)
9. [Erros comuns](#erros-comuns)
10. [Como pedir ajuda ou relatar um problema](#como-pedir-ajuda-ou-relatar-um-problema)

## Conceitos que você precisa saber

| Palavra | O que é | Por que importa aqui |
| --- | --- | --- |
| **Repositório** | A pasta do projeto com todo o histórico de mudanças | O repositório do Nexus OS está no GitHub e é **público** |
| **Clone** | Uma cópia do repositório no seu computador | Você trabalha na cópia, não direto no GitHub |
| **Branch** (ramo) | Uma linha de trabalho paralela | Cada pessoa tem a sua, para ninguém mexer no trabalho do outro |
| **Commit** | Um conjunto de mudanças gravado com uma mensagem | É o "salvar" do projeto, com autor e descrição |
| **Push** | Enviar os seus commits ao GitHub | Só depois do push os outros veem o seu trabalho |
| **PR** (*pull request*) | Um pedido para juntar a sua branch a outra | É como o seu trabalho entra, depois da revisão |
| **Merge** | Juntar uma branch a outra | Aqui só o revisor final (Marcos) faz |

## Branches

- `main`: versão integrada. Só recebe PR da branch `marcos`, aberto e mergeado apenas por Marcos (revisor final).
- `marcos`: branch de integração. Recebe os PRs dos colegas. Só Marcos mergeia.
- `renato`, `giulliano`, `gudryan`, `jean`, `sayuri`: uma branch por pessoa.

Todo merge, em qualquer PR, é feito somente por Marcos e sempre com "Rebase and merge" (histórico linear, sem merge commit).

## Regras que valem o tempo todo

1. **Nunca commite na branch de outra pessoa nem direto na `main` ou na `marcos`.** O GitHub bloqueia, e o push é rejeitado.
2. **O repositório é público:** nunca commite senha, chave, token nem dado pessoal.
3. **Se não souber o que fazer, pare e pergunte** (seção "Como pedir ajuda ou relatar um problema"). Não force nada: não use `git push --force` nem apague branch.
4. **Commits pequenos e frequentes**, com mensagem que diga o que mudou.

## O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | O **convite de colaborador** aceito | Sem ele o push é recusado | Chega por e-mail e também fica em https://github.com/MixuriM/nexus-os/invitations |
| 2 | O **Git** instalado | É o programa que faz tudo abaixo | `git --version` imprime uma versão; se não, instale (https://git-scm.com/downloads) |
| 3 | Acesso ao GitHub pelo terminal | O `git push` precisa autenticar | HTTPS com a sua conta ou SSH |
| 4 | Um **terminal** | Os comandos rodam nele | No Windows, o **Git Bash** (vem com o Git); no Linux, o terminal |
| 5 | O **nome da sua branch** | Aparece como `<sua-branch>` nos comandos | A lista está em "Branches" |

## Primeira vez

### Passo 1: aceitar o convite

**Onde:** e-mail e navegador. **O que fazer:** aceite o convite de colaborador. **Por quê:** é a permissão para enviar o seu trabalho. **Deve aparecer:** no GitHub, o repositório `MixuriM/nexus-os` aparece na sua conta. **Se não aparecer:** confira o e-mail de spam e a página de convites do item 1 da tabela.

### Passo 2: clonar e configurar o seu nome

**Onde:** terminal, numa pasta onde você guarda projetos (por exemplo `Documentos`).

**O que fazer:** clone o repositório e configure seu nome e e-mail **neste** repositório (use o e-mail da sua conta do GitHub ou o noreply dela):

```
git clone https://github.com/MixuriM/nexus-os.git
cd nexus-os
git config user.name "Seu Nome"
git config user.email "email-da-sua-conta-github"
```

**Por quê:** o `git clone` baixa uma cópia do projeto para a pasta `nexus-os`; o `cd` entra nela; os dois `git config` gravam o autor dos seus commits, só neste repositório.

**Deve aparecer:** o `git clone` mostra o progresso e termina sem erro; `git config user.email` imprime o e-mail que você escreveu.

**Se não aparecer:** `Repository not found` ou `Permission denied` indica que o convite não foi aceito ou a autenticação falhou; `Could not resolve host` indica falta de internet.

## Passo a passo para quem não é o revisor final

Use o nome da sua branch no lugar de `<sua-branch>`.

### Passo 1: atualizar a sua branch antes de trabalhar

**O que fazer:**

```
git fetch origin
git switch <sua-branch>
git merge --no-edit origin/marcos
```

**Por quê:** `git fetch origin` baixa as novidades do GitHub sem mexer nos seus arquivos; `git switch` muda para a sua branch; `git merge --no-edit origin/marcos` traz para ela o que mudou na `marcos`, sem abrir o editor de mensagem.

**Deve aparecer:** `git status` diz que o diretório de trabalho está limpo (`working tree clean`, ou `nada a commitar, diretório de trabalho limpo` em português).

**Se não aparecer:** `CONFLICT` indica que o mesmo trecho mudou nos dois lados: veja o "Exercício de conflito" de [oficina-git.md](oficina-git.md) para resolver.

### Passo 2: trabalhar em commits pequenos

**O que fazer:**

```
git add <arquivos>
git commit -m "tipo: descrição curta"
git push origin <sua-branch>
```

**Por quê:** `git add` escolhe os arquivos que entram no commit (sempre por nome, nunca todos de uma vez); `git commit -m` grava o commit com a mensagem (o `tipo` é uma palavra como `docs`, `feat`, `fix` ou `test`); `git push origin <sua-branch>` envia para o GitHub.

**Deve aparecer:** o `push` termina com uma linha `<sua-branch> -> <sua-branch>`.

**Se não aparecer:** `rejected ... violação de regra do repositório` indica que você tentou push em `main` ou `marcos` (veja "Erros comuns").

### Passo 3: abrir o PR

**Onde:** no GitHub, aba **Pull requests**, **New pull request**.

**O que fazer:** abra o PR com base `marcos` e comparação `<sua-branch>`. O GitHub sugere `main` como base por padrão: **troque para `marcos`**. Nunca use `main` como base.

**Por quê:** a `main` só recebe o que já passou pela `marcos`.

**Deve aparecer:** o PR na lista, sem botão de merge para você.

### Passo 4: esperar a revisão

Marcos aprova e faz o merge, sempre com "Rebase and merge". O botão de merge não aparece para você, e isso é esperado. Nunca faça o merge do seu próprio PR.

### Passo 5: atualizar a sua branch depois do merge

**O que fazer:**

```
git fetch origin
git merge --no-edit origin/marcos
```

**Por quê:** o "Rebase and merge" recria os seus commits na `marcos` com SHAs novos (o conteúdo é o mesmo). Por isso o `git log` da sua branch pode mostrar os commits duas vezes e o merge acima pode gerar um merge commit na sua branch. Isso é esperado, não é erro.

## Regras

- PRs pequenos e frequentes.
- Integrantes abrem PR somente para a `marcos`, nunca direto para a `main`. Só Marcos abre PR para a `main`, e sempre a partir da `marcos`, porque a `main` só recebe o que já passou pela `marcos`.
- Se o PR tiver conflito, resolva na sua branch: `git merge origin/marcos`, corrija os arquivos, faça o commit e o push.
- Nunca commite na branch de outra pessoa.
- Force push e apagar branch são bloqueados pelo GitHub nas branches pessoais.
- Só Marcos faz merge, sempre com "Rebase and merge": tanto nos PRs dos colegas para a `marcos` quanto no PR da `marcos` para a `main`. Depois do merge na `main`, a `marcos` e as branches pessoais são sincronizadas com a `main` (veja abaixo).
- Configure o e-mail de commit com um e-mail associado à sua conta do GitHub (ou o e-mail noreply dela).
- O repositório é público: nunca commite senha, chave, token nem dado pessoal.
- O build da ISO só roda em Linux. Veja [ambiente-de-build.md](ambiente-de-build.md).

## Para o revisor final (Marcos)

- Revisar e aprovar os PRs para `marcos` e mergear sempre com "Rebase and merge" (na CLI, `gh pr merge <número> --rebase`).
- Abrir e mergear o PR de `marcos` para `main`.
- O merge de `marcos` para `main` exige o bypass de Admin e o método "Rebase and merge" (precisa estar ligado em Settings, Pull Requests, "Allow rebase merging"). Na CLI use `gh pr merge <número> --rebase --admin`; na página do PR, marque "Merge without waiting for requirements to be met" e escolha "Rebase and merge".
- O rebase recria os commits na `main` com SHAs novos. A `marcos` fica divergente (mesmo conteúdo, SHAs diferentes) e o `git merge --ff-only origin/main` falha. Depois de cada merge na `main`, rode o script de sincronização:

  ```
  scripts/sync-branches.sh
  ```

  **Deve aparecer:** o script termina na branch `marcos`, com o upstream em `origin/marcos`, e avisa de cada branch que não conseguiu avançar. O script faz, nesta ordem:
  1. `git fetch origin --prune` e confere que o working tree está limpo.
  2. Realinha a `marcos` com a `main` (force push com `--force-with-lease`, permitido pelo bypass de Admin). Só faz isso se todos os commits da `marcos` já estiverem na `main` (conferido com `git cherry`). Se houver commit que a `main` não tem, pula a `marcos` e avisa.
  3. Avança `renato`, `giulliano`, `gudryan`, `jean` e `sayuri` por fast-forward para a `main`, sem checkout e sem merge local. Branch com commits próprios é recusada pelo servidor: o script avisa e segue para a próxima. Isso é comum para quem teve o PR mergeado com rebase, porque os commits originais da branch não existem na `main`. Essa pessoa resolve com o `git merge --no-edit origin/main` descrito abaixo.
  4. Avança a `main` local para a `origin/main`, só se for fast-forward.
  5. Termina na branch `marcos`, com o upstream em `origin/marcos`.

  O script age no repositório onde ele está e só roda se o `origin` for o `nexus-os`.
- Cada integrante precisa atualizar a própria branch depois da sincronização: `git fetch origin`, `git switch <sua-branch>` e `git merge --no-edit origin/main`.

## Erros comuns

| O que aparece | O que significa | O que fazer |
| --- | --- | --- |
| Push rejeitado com aviso de violação de regra do repositório | Você tentou push em `main` ou `marcos`, force push ou apagar branch | Abra um PR; nunca force |
| Sem botão de merge no PR | Esperado: só o revisor final mergeia | Aguarde a revisão |
| PR aberto com base `main` por engano | A base errada | Feche e abra de novo com base `marcos` |
| `CONFLICT` ao atualizar a branch | O mesmo trecho mudou nos dois lados | Edite o arquivo, apague as marcações `<<<<<<<`, `=======` e `>>>>>>>`, `git add`, `git commit` e `git push` ([oficina-git.md](oficina-git.md)) |
| `git log` mostra os commits duas vezes depois do merge | Efeito do "Rebase and merge" | Esperado, não é erro |

## Como pedir ajuda ou relatar um problema

**Quando:** para qualquer erro de comando deste documento, para tudo que ele não explicou e para qualquer dúvida sobre qual comando usar.

**Como:** escreva no grupo da equipe ou abra uma issue no GitHub com: **o que você tentou** (os comandos exatos, na ordem), **a saída exata** (copie e cole; não resuma) e **o que esperava**. Sem dado pessoal. Uma pergunta por mensagem.
