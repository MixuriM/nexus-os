# Checklist de teste da documentação (F2.8)

Roteiro para quem nunca viu o projeto. O objetivo é descobrir se o `README.md` e os documentos de `docs/` bastam para gerar e testar a ISO do zero, **sem ajuda e sem conhecimento prévio**.

Regra principal: siga **somente** o que está escrito no repositório. Se precisar de algo que não está escrito (um pacote, um comando, uma explicação), isso é uma falha da documentação: anote e abra uma issue. Não conserte em silêncio.

Tempo estimado: 1 h de preparo e cerca de 30 min de build, mais 15 min de testes. Reserve uma tarde.

## Parte A: ficha do teste

Preencha ao longo do teste (copie esta ficha para um arquivo seu; não commite o arquivo com dados pessoais).

| Campo | Valor |
| --- | --- |
| Data do teste (DD/MM/AAAA) | |
| Branch e commit testados (`git rev-parse --short HEAD`) | |
| Máquina física (sistema, RAM, CPU) | |
| Programa de VM e versão | |
| Recursos da VM (vCPU, RAM, disco) | |
| Debian da VM (`cat /etc/debian_version`) | |
| Hora de início e de fim do `scripts/build-iso.sh` | |
| Saída do `scripts/build-iso.sh` (código de saída) | |
| SHA256 obtido (`cat dist/nexus-os-poc-amd64.iso.sha256`) | |
| Tamanho da ISO em bytes (`stat -c %s dist/nexus-os-poc-amd64.iso`) | |
| Resultado de `tests/iso.sh` (última linha impressa) | |
| Tempo até `login:` informado pelo teste | |
| Resultado de `tests/lint-repo.sh` (última linha) | |
| Resultado final (passou, passou com ressalvas, falhou) | |

## Parte B: preparar uma VM Debian 13 limpa

"Limpa" quer dizer recém-instalada, sem nada do projeto. Use o que o repositório pede em [ambiente-de-build.md](ambiente-de-build.md).

| # | O que fazer | Onde | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| B1 | Instalar um programa de VM (VirtualBox) na sua máquina | Sua máquina | | |
| B2 | Baixar a ISO netinst do Debian 13 em https://www.debian.org/releases/stable/ e conferir o SHA256 com o arquivo `SHA256SUMS` do site | Navegador e terminal | | |
| B3 | Criar a VM com 4 vCPU, 8 GB de RAM e disco de 80 GB (mínimo 40 GB), rede NAT | Programa de VM | | |
| B4 | Instalar o Debian: disco inteiro, **sem** ambiente gráfico, marcando só "SSH server" e "standard system utilities". Se pedir senha de root, deixe vazia para criar o `sudo` ao usuário comum | Janela da VM | | |
| B5 | Entrar na VM com o usuário comum e confirmar a versão: `cat /etc/debian_version` (deve começar com 13) | Terminal da VM | | |
| B6 | Instalar os pacotes da seção "Preparar a VM para o build" de `docs/ambiente-de-build.md`. Se `sudo` pedir senha e você não souber a regra, anote como falha de documentação | Terminal da VM | | |

Como saber se o B6 deu certo: `lb --version` imprime uma versão e `git --version` também. Se aparecer `command not found`, o pacote não foi instalado.

## Parte C: clonar e seguir só o README

Abra o `README.md` do repositório (no navegador, em https://github.com/MixuriM/nexus-os) e siga a seção **"Como gerar a ISO"** passo a passo. Não use o que você já sabe de outros projetos.

| # | Passo do README | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- |
| C1 | Passo 1: `git clone` e `cd nexus-os`. Anote o commit com `git rev-parse --short HEAD` | | |
| C2 | Passo 2: `sudo scripts/build-iso.sh`. Anote a hora de início. O comando fica 20 a 30 minutos sem imprimir muito: espere. Anote a hora de fim e o código de saída (`echo $?` logo depois) | | |
| C3 | Conferir os arquivos: `ls -l dist/` deve listar `nexus-os-poc-amd64.iso` e `nexus-os-poc-amd64.iso.sha256` | | |
| C4 | Anotar o SHA256 (`cat dist/nexus-os-poc-amd64.iso.sha256`) e o tamanho (`stat -c %s dist/nexus-os-poc-amd64.iso`) na ficha | | |
| C5 | Passo 3: `tests/iso.sh dist/nexus-os-poc-amd64.iso`. Sem `/dev/kvm` o teste leva de 2 a 15 minutos. A última linha deve começar com `OK:` | | |
| C6 | Passo 4: `tests/lint-repo.sh`. A última linha deve começar com `OK:` | | |
| C7 | Conferir se `docs/iso-poc.md` descreve o que você viu (tamanho, tempo, limitações). Anote diferenças | | |

Comparação com o autor: o hash da ISO **pode ser diferente** do registrado em `docs/iso-poc.md`, porque cada build gera o seu. Diferença de hash não é falha. Falha é o `tests/iso.sh` não passar.

## Parte D: componentes (opcional, só se o Marcos pedir)

Os guias estão em [sdn.md](sdn.md), [virtualizacao.md](virtualizacao.md) e [nfv.md](nfv.md). Para rodar tudo em sequência: `tests/run-fase2.sh dist/nexus-os-poc-amd64.iso`. O teste de NFV precisa de Docker e Containerlab, que os documentos explicam como instalar. Registre cada falha do mesmo modo.

| # | Teste | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- |
| D1 | `sudo tests/sdn.sh` | | |
| D2 | `sudo tests/virtualizacao.sh` | | |
| D3 | `sudo tests/nfv.sh` | | |

## Parte E: como registrar uma falha

Cada falha vira **uma issue**. O que conta como falha:

- um comando do repositório termina com erro;
- a saída é diferente da descrita na documentação;
- você precisou de algo que a documentação não diz;
- um passo é ambíguo e você teve que adivinhar.

Para abrir: página do repositório no GitHub, aba **Issues**, botão **New issue**.

- **Título:** `F2.8: <resumo curto da falha>` (por exemplo, `F2.8: build-iso.sh falha por falta de pacote`). Use `F2.3` se a falha for do build e `F2.4` se for do boot da ISO.
- **Corpo**, com estes quatro blocos:

  ```
  Passos: o que você fez, em ordem, com os comandos digitados.
  Saída: as últimas linhas da saída (copie e cole, sem editar).
  Esperado: o que a documentação dizia que aconteceria.
  Ambiente: sistema, versão do Debian, RAM, commit testado.
  ```

- Antes de colar a saída, **apague** qualquer senha, chave, token, nome de usuário pessoal ou endereço de e-mail. O repositório é público.
- Se não houver nenhuma falha, não abra issue: marque "passou" na ficha.

## Parte F: o que devolver ao Marcos

1. A ficha da Parte A preenchida.
2. As tabelas B, C e (se feita) D com passou ou falhou.
3. Os números das issues abertas.
4. O resultado final: **passou**, **passou com ressalvas** ou **falhou**.

Com isso o Marcos registra a reprodução por segunda pessoa de F2.3 e F2.4 e fecha F2.8.
