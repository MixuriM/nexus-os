# Oficina de Git (1 hora): passo a passo completo

Roteiro para a oficina da F2.2. Ao final, cada participante abriu um PR de teste com base `marcos`. Foi escrito para quem **nunca usou Git**: cada etapa diz **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. As regras de branches, PRs e merge estão em [fluxo-de-trabalho.md](fluxo-de-trabalho.md). Este roteiro só ensina a executá-las; em caso de dúvida, vale o que está lá.

## Sumário

1. [O que é esta oficina e por que ela existe](#o-que-é-esta-oficina-e-por-que-ela-existe)
2. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
3. [Antes da oficina](#antes-da-oficina)
4. [Roteiro](#roteiro)
5. [Etapa a etapa](#etapa-a-etapa)
6. [Exercício de conflito](#exercício-de-conflito)
7. [Critério de pronto](#critério-de-pronto)
8. [Problemas comuns](#problemas-comuns)

## O que é esta oficina e por que ela existe

O projeto tem várias pessoas mexendo nos mesmos arquivos. O Git e o GitHub deixam cada pessoa trabalhar na sua **branch** (linha de trabalho própria) e enviar o resultado por um **PR** (*pull request*, pedido de junção), que só o revisor final aceita. Nesta oficina você pratica o ciclo inteiro uma vez, num arquivo de teste, para não errar no trabalho de verdade.

**Resultado esperado de uma execução bem-sucedida:** um PR de teste seu, com base `marcos`, e um conflito resolvido.

## Regras que valem o tempo todo

1. **Use a sua branch**, nunca a `main`, a `marcos` nem a de outra pessoa.
2. **O repositório é público:** nada de senha, chave, token ou dado pessoal nos arquivos de teste.
3. **Não use `git push --force`.** O GitHub bloqueia, e você só precisa de commits normais.
4. **Quem conduz** responde dúvidas; em caso de erro, copie a mensagem exata e mostre.

## Antes da oficina

| # | Item | Por quê | Como conferir |
| --- | --- | --- | --- |
| 1 | Convite de colaborador do repositório aceito | Sem ele o push é recusado | Em https://github.com/MixuriM/nexus-os/invitations não há convite pendente |
| 2 | Git instalado | É o programa que faz tudo | `git --version` imprime uma versão |
| 3 | Acesso ao GitHub pelo terminal (HTTPS com a conta ou SSH) | O `git push` precisa autenticar | O primeiro `git push` não pede nada além da sua autenticação |
| 4 | A sua branch pessoal já criada por quem conduz | É nela que você trabalha | A lista está em [fluxo-de-trabalho.md](fluxo-de-trabalho.md), seção "Branches" |

## Roteiro

| Tempo | Etapa | O que fazer | Resultado esperado |
| --- | --- | --- | --- |
| 0 a 10 min | Conceitos | Quem conduz explica branch, commit, push, PR e por que só o revisor final faz merge | Todos sabem qual é a sua branch |
| 10 a 20 min | Clone e configuração | Seção "Primeira vez" do fluxo: `git clone`, `git config user.name` e `git config user.email` | `git config user.email` mostra o e-mail da conta do GitHub |
| 20 a 30 min | Atualizar a própria branch | `git fetch origin`, `git switch <sua-branch>`, `git merge --no-edit origin/marcos` | `git status` diz `working tree clean` |
| 30 a 40 min | Commit e push | Criar `oficina/<sua-branch>.md` com uma linha de texto; `git add oficina/<sua-branch>.md`, `git commit -m "docs: teste da oficina de git"`, `git push origin <sua-branch>` | O push termina sem erro |
| 40 a 50 min | Abrir o PR | No GitHub, **Pull requests**, **New pull request**: base `marcos`, comparação `<sua-branch>`. Confirmar que a base **não** é `main` | O PR aparece na lista, sem botão de merge para você |
| 50 a 60 min | Conflito | Veja abaixo | Conflito resolvido na sua branch e PR sem conflito |

## Etapa a etapa

### Etapa 1: clone e configuração (10 a 20 min)

**Onde:** terminal (no Windows, o Git Bash).

**O que fazer:**

```
git clone https://github.com/MixuriM/nexus-os.git
cd nexus-os
git config user.name "Seu Nome"
git config user.email "email-da-sua-conta-github"
```

**Por quê:** baixa o projeto e grava o autor dos seus commits, só neste repositório. **Deve aparecer:** `git config user.email` imprime o e-mail da sua conta. **Se não aparecer:** `Repository not found` indica convite não aceito ou autenticação errada.

### Etapa 2: atualizar a própria branch (20 a 30 min)

**O que fazer:**

```
git fetch origin
git switch <sua-branch>
git merge --no-edit origin/marcos
```

**Por quê:** traz para a sua branch o que a `marcos` já tem, para você começar do ponto certo. **Deve aparecer:** `git status` com `working tree clean` (ou `nada a commitar, diretório de trabalho limpo`). **Se não aparecer:** `error: pathspec '<sua-branch>' did not match` indica que a branch não existe ou foi digitada errada: confira o nome em [fluxo-de-trabalho.md](fluxo-de-trabalho.md).

### Etapa 3: commit e push (30 a 40 min)

**O que fazer:** crie o arquivo `oficina/<sua-branch>.md` com uma linha de texto (pode ser no editor de texto; crie a pasta `oficina` se não existir) e rode:

```
git add oficina/<sua-branch>.md
git commit -m "docs: teste da oficina de git"
git push origin <sua-branch>
```

**Por quê:** `git add` escolhe o arquivo; `git commit` grava; `git push` envia para o GitHub. **Deve aparecer:** o `push` termina com uma linha `<sua-branch> -> <sua-branch>`. **Se não aparecer:** `violação de regra do repositório` indica push na branch errada: confira com `git branch --show-current`.

### Etapa 4: abrir o PR (40 a 50 min)

**Onde:** GitHub, no navegador, aba **Pull requests**, **New pull request**.

**O que fazer:** base `marcos`, comparação `<sua-branch>`. O GitHub sugere `main`: **troque**. Clique **Create pull request**.

**Por quê:** a `main` só recebe o que passou pela `marcos`. **Deve aparecer:** o PR na lista, sem botão de merge para você (esperado). **Se não aparecer:** se a base ficou `main`, feche o PR e abra de novo.

## Exercício de conflito

**O que é:** um *conflito* acontece quando duas pessoas mudam o mesmo trecho de um arquivo. O Git não sabe qual vale e pede que você decida.

**O que fazer:** quem conduz cria, na `marcos`, o arquivo `oficina/conflito.md` com uma linha. Cada participante, na própria branch, cria o mesmo arquivo com outra linha (antes de atualizar) e depois:

```
git fetch origin
git merge origin/marcos
```

**Deve aparecer:** o Git avisa `CONFLICT` e marca o arquivo com `<<<<<<<`, `=======` e `>>>>>>>`. Edite o arquivo, deixe o texto final desejado e apague as marcações. Depois:

```
git add oficina/conflito.md
git commit
git push origin <sua-branch>
```

**Por quê:** `git add` avisa ao Git que você resolveu; `git commit` (sem `-m`) abre o editor com a mensagem do merge, que pode ser salva como está; o `push` envia. **Deve aparecer:** o PR deixa de mostrar conflito. Quem conduz fecha os PRs de teste sem merge e remove a pasta `oficina/` da `marcos` quando a oficina acabar.

## Critério de pronto

- Cada integrante abriu um PR de teste com base `marcos`.
- Quem conduz registra a data e a lista de PRs de teste no quadro de tarefas (issue da F2.2).

## Problemas comuns

| O que aparece | O que significa | O que fazer |
| --- | --- | --- |
| `Permission denied` ou `Repository not found` | Convite não aceito ou autenticação errada | Aceite o convite e autentique de novo |
| Push rejeitado por violação de regra | Você está na `main` ou na `marcos` | `git switch <sua-branch>` e repita |
| O PR mostra a base `main` | Base errada | Feche e abra de novo com base `marcos` |
| O editor abre sozinho ao fazer o commit do conflito | O Git pede a mensagem do merge | Salve e feche o editor (a mensagem padrão serve) |
| Não sei qual comando usar | Dúvida | Pergunte a quem conduz com o comando e a saída exata |
