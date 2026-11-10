# Modelo de manual: o padrão de detalhamento

Template para todo documento do Nexus OS que ensina alguém a **fazer** alguma coisa: manual de componente, roteiro de teste, preparo de ambiente, fluxo de trabalho. O padrão é o de [teste-virtualbox.md](teste-virtualbox.md): o leitor **nunca viu o projeto** e tem de conseguir seguir sozinho, passo a passo. Copie a estrutura abaixo, preencha o que está entre `<` e `>` e apague o que não se aplica.

Todo comando e toda saída esperada precisam vir de uma execução real. Não escreva comando, versão ou saída que ninguém executou; o que veio só da documentação oficial leva o rótulo "da documentação oficial, não executado".

## O padrão em uma frase

Cada passo diz **onde** fazer, **quando** fazer, **o que** fazer (comando exato em bloco de código), **por quê**, **o que deve aparecer** e **o que fazer se não aparecer**.

## Estrutura de um documento de instruções

1. **Título e parágrafo de abertura:** para quem é ("quem nunca viu o projeto"), o que o documento ensina e a frase "cada passo diz onde, o quê, por quê, o que deve aparecer e o que fazer se não aparecer". Avise para ler a seção do passo inteira antes de executá-lo.
2. **Sumário:** lista numerada das seções, com links.
3. **O que é e por que existe:** o que o componente ou teste é, em linguagem simples, **o resultado esperado de uma execução bem-sucedida** e o tempo estimado. Explique os termos técnicos na primeira vez (por exemplo "*live*: roda na memória, sem instalar").
4. **Regras que valem o tempo todo:** de 4 a 7 regras curtas. As fixas: faça só o que está escrito (o que faltar é falha da documentação); um passo de cada vez, na ordem; confira o "Deve aparecer" antes de seguir; o repositório é público (nunca cole senha, chave, token, e-mail nem nome de usuário do computador).
5. **O que você precisa ter antes:** tabela com `#`, **Item**, **Por quê** e **Como conseguir**, mais o nível técnico necessário e o tempo livre.
6. **Passos numerados:** cada passo com os rótulos abaixo.
7. **Tabelas de significado:** quando houver configuração (memória, processadores, modo de rede), uma tabela "o que cada configuração significa" com **Valor** e **Por que esse valor**.
8. **Ficha e o que devolver** (só em roteiro de teste): ficha do ambiente, resultado por item (passou, falhou ou passou com ressalvas), o que anexar e para quem devolver.
9. **Como relatar uma falha:** quando, onde (issue no GitHub), título `<tarefa>: <item>: <resumo curto>`, corpo com **Passos**, **Saída** (copiada e colada, sem resumir), **Esperado** e **Ambiente**; uma issue por falha; falha intermitente também vira issue, com o número de tentativas.
10. **Desligar e limpar:** como desfazer o que o roteiro criou, dizendo o que não tem volta.
11. **Problemas conhecidos (não são falha sua):** tabela com o que se vê e o detalhe.
12. **Perguntas frequentes:** dúvidas previsíveis e a resposta.

## Rótulos de cada passo

| Rótulo | O que escrever |
| --- | --- |
| **Onde** | O lugar exato: "PowerShell como administrador", "terminal da VM", "Git Bash", menu e botão (caminho completo de menus). PowerShell e bash **nunca** no mesmo bloco, e cada bloco com o rótulo da linguagem |
| **Quando** | A condição para fazer o passo ("só depois de conferir o passo 5", "com a VM desligada") |
| **O que fazer** | O comando exato em bloco de código, pronto para copiar. Nenhum "configure como preferir": todo valor é dado |
| **Por quê** | A razão do passo, em uma ou duas frases, e o que cada comando ou opção faz |
| **Deve aparecer** | O trecho exato da saída ou o que se vê na tela, com os números medidos |
| **Se não aparecer** | O erro mais provável, a causa e a correção; o que fazer quando a correção não resolve (relatar, seção "Como relatar uma falha") |

## Modelo genérico

````markdown
# <Componente ou roteiro>: passo a passo completo

Este documento explica, do zero, <o que o leitor consegue fazer ao final>. Foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. Leia a seção do passo inteira antes de executá-lo.

## Sumário

1. [O que é e por que existe](#o-que-é-e-por-que-existe)
2. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
3. [O que você precisa ter antes](#o-que-você-precisa-ter-antes)
4. [Passos](#passos)
5. [Como relatar uma falha](#como-relatar-uma-falha)

## O que é e por que existe

<O que é, em linguagem simples. Termos técnicos explicados.>

**Resultado esperado de uma execução bem-sucedida:** <o que se vê ao final>. **Tempo estimado:** <minutos>.

## Regras que valem o tempo todo

1. **Faça só o que está escrito aqui.** O que faltar é falha da documentação: relate.
2. **Um passo de cada vez, na ordem.**
3. **Confira o "Deve aparecer" antes de seguir.**
4. **O repositório é público:** nunca cole senha, chave, token, e-mail nem nome de usuário do computador.

## O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | <item> | <por quê> | <como> |

## Passos

### Passo 1: <ação em poucas palavras>

**Onde:** <lugar exato>.

**O que fazer:**

```bash
<comando>
```

**Por quê:** <razão e o que cada opção faz>.

**Deve aparecer:** `<trecho da saída>`.

**Se não aparecer:** `<mensagem de erro>` indica <causa>: <correção>. Se continuar, relate (seção "Como relatar uma falha").

## Como relatar uma falha

**Quando:** <...>. **Onde:** uma issue no GitHub. **Título:** `<tarefa>: <passo>: <resumo curto>`. **Corpo:** Passos, Saída, Esperado e Ambiente.
````

## Regras de escrita

- Português do Brasil, sem travessão (use vírgula ou dois-pontos), comandos em bloco de código, um passo por ação.
- Sem dado pessoal, senha pessoal, chave nem endereço privado. A credencial `user` e `live` da Debian Live é pública e pode aparecer.
- **Blocos executáveis:** no manual do Nexus OS, o bloco que o `tests/manual.sh` executa dentro da ISO é marcado com ` ```bash nexus-exec ` e tem de limpar o que criou. Os demais blocos são exemplos.
- **Blocos de código:** evite blocos de código dentro de item de lista numerada (a indentação precisa ser exata para o bloco aparecer certo); use um título de passo e rótulos em negrito, como acima.
- **Links:** para outro documento da pasta `docs/`, caminho relativo; todo link local é conferido pelo `tests/docs.sh`.

## Documentos que seguem o padrão

| Documento | Para quê |
| --- | --- |
| [manual.md](manual.md) | Manual v2.1 do Nexus OS: gerar a ISO, iniciá-la e usar cada componente |
| [teste-virtualbox.md](teste-virtualbox.md) | O documento de referência do padrão: teste da RC2 no VirtualBox |
| [hyperv.md](hyperv.md) | VM de build no Hyper-V com KVM |
| [ambiente-de-build.md](ambiente-de-build.md) | Preparo da VM de build |
| [gns3.md](gns3.md) | GNS3, instalação e uso (só documentado) |
| [sdn.md](sdn.md), [virtualizacao.md](virtualizacao.md), [containers.md](containers.md), [nfv.md](nfv.md) | Um documento por componente |
| [integracao-iso.md](integracao-iso.md) | Como a ISO é montada e testada por dentro |
| [fluxo-de-trabalho.md](fluxo-de-trabalho.md) e [oficina-git.md](oficina-git.md) | Git e GitHub para a equipe |
| [checklist-teste-documentacao.md](checklist-teste-documentacao.md) | Roteiros de teste da documentação |
| [plano-de-testes.md](plano-de-testes.md) | Como rodar os cenários T1 a T7 |

## Referência rápida por componente

Os blocos abaixo são o resumo em uma linha de cada componente. O passo a passo completo está no documento indicado.

| Componente | Documento completo | Teste |
| --- | --- | --- |
| ISO (live-build) | [manual.md](manual.md), seção "Gerar a ISO", e [iso-poc.md](iso-poc.md) | `tests/iso.sh dist/nexus-os-poc-amd64.iso` |
| Open vSwitch (SDN) | [sdn.md](sdn.md) | `sudo tests/sdn.sh` |
| libvirt (virtualização) | [virtualizacao.md](virtualizacao.md) | `sudo tests/virtualizacao.sh` |
| Containerlab com FRR | [nfv.md](nfv.md) | `sudo tests/nfv.sh` |
| Orquestração `nexus-vnf` | [nfv.md](nfv.md), seção "Orquestração" | `sudo tests/orquestracao.sh` |
| Desktop XFCE | [manual.md](manual.md), seção "Ambiente gráfico" | `tests/iso-smoke.sh <iso> desktop` |
