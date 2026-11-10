# Contêineres: Docker e imagens offline na ISO

F3.4. A ISO traz o Docker e a imagem do FRRouting já dentro dela: depois do boot, sem internet, `docker image ls` mostra a imagem e um contêiner roda. O Containerlab (parte 4 da Fase 3) usa essa mesma imagem.

Este documento foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. **O que é:** um **contêiner** é um programa que roda isolado, empacotado com tudo o que precisa; o **Docker** é o programa que cria e roda contêineres; uma **imagem** é o pacote pronto do qual o contêiner nasce. Normalmente o Docker baixa a imagem da internet; na ISO a imagem já vem **dentro** da ISO (modo offline).

## Sumário

1. [Como funciona](#como-funciona)
2. [Driver de armazenamento](#driver-de-armazenamento)
3. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
4. [O que você precisa ter antes](#o-que-você-precisa-ter-antes)
5. [Imagens offline](#imagens-offline)
6. [Smoke test `containers`](#smoke-test-containers)
7. [Medições](#medições-23102026-vm-debian-13-no-hyper-v-com-kvm-4-vcpu-e-8-gb)
8. [Problemas conhecidos](#problemas-conhecidos)
9. [Como relatar uma falha](#como-relatar-uma-falha)

## Como funciona

| Peça | Onde | O que faz |
| --- | --- | --- |
| `docker.io` 26.1.5+dfsg1-9+deb13u1 | `live-build/config/package-lists/nexus-containers.list.chroot` | Runtime (Debian main). `docker.service` habilitado pelo hook |
| `live-build/offline/imagens.txt` | versionado | Uma linha por imagem: `repositório:tag digest` |
| `scripts/prepare-offline.sh` | chamado por `scripts/build-iso.sh` depois do stage e antes do `lb build` | Baixa a imagem, confere o digest e salva o `.tar` |
| `live-build/config/includes.chroot/var/lib/nexus-os/images/*.tar` | gerado, ignorado pelo git | Vai para `/var/lib/nexus-os/images/` da ISO |
| `nexus-images.service` e `/usr/local/bin/nexus-images-load` | `includes.chroot` | No boot, faz `docker load` de cada `.tar` cuja imagem ainda não existe |
| `var-lib-docker.mount` e `docker.service.d/nexus-tmpfs.conf` | `includes.chroot` | tmpfs em `/var/lib/docker` (veja o driver abaixo) |
| `tests/containers.sh` | smoke test `containers` | Confere o resultado dentro da ISO |

Imagem desta parte: `quay.io/frrouting/frr:10.7.1`, digest `sha256:e995beaa50fdc9edb35eadcfefa29b7f062cc06f2b812613789b68fa541554d2` (campo `RepoDigests`, medido em 23/10/2026). Dentro da imagem, `/usr/lib/frr/zebra --version` imprime `zebra version 10.7.1_git`. O entrypoint da imagem é `/sbin/tini -- /usr/lib/frr/docker-start`, por isso o teste usa `--entrypoint`.

## Driver de armazenamento

Hipótese testada: a raiz da live é overlayfs e o `overlay2` do Docker não roda sobre ela. Confirmada na ISO sem a unidade de tmpfs (com KVM):

- Log do `dockerd`: `failed to mount overlay: invalid argument` (driver `overlay2`) e `exec: "fuse-overlayfs": executable file not found in $PATH`; o kernel registra `overlay: filesystem on /var/lib/docker/check-overlayfs-support.../upper not supported as upperdir`.
- O Docker cai para `vfs` (`docker info`, campo Storage Driver). Com `vfs` a imagem de 193 MB ocupou 692 MB em `/var/lib/docker` e a RAM usada foi de 264 MB (sem imagem) para 1192 MB (com a imagem).
- A raiz da live tem só 1961 MB de espaço (overlay em RAM), então o `vfs` não cabe com pouca memória.

Solução adotada: `var-lib-docker.mount` monta um tmpfs (`size=50%`: o teto é metade da RAM e só se usa o que for escrito) em `/var/lib/docker`, e o drop-in `docker.service.d/nexus-tmpfs.conf` (`RequiresMountsFor=/var/lib/docker`) ordena a montagem antes do `dockerd`. Driver final: **`overlay2`**, com a imagem ocupando 193 MB no tmpfs. O `tests/containers.sh` exige `overlay2`: se a unidade sumir, o teste falha em vez de cair em silêncio para `vfs`.

Consequência: os dados do Docker (imagens carregadas, contêineres) somem a cada boot. A carga do `nexus-images.service` refaz as imagens.

## Regras que valem o tempo todo

1. **Faça só o que está escrito aqui** e confira o "Deve aparecer" de cada passo antes de seguir.
2. **O build da ISO exige Docker e internet** na VM de build (para o `docker pull`); dentro da ISO nada baixa.
3. **Os dados do Docker na ISO ficam em RAM** e somem a cada boot: não guarde nada neles.
4. **O repositório é público:** nunca cole em issue senha, chave, token ou dado pessoal.

## O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | Para **adicionar uma imagem**: a VM de build com Docker, `sudo` e internet | O `prepare-offline.sh` baixa e salva a imagem | [ambiente-de-build.md](ambiente-de-build.md) |
| 2 | Para **testar**: a ISO gerada em `dist/` e a VM de build com QEMU | O smoke inicia a ISO sem rede | [manual.md](manual.md), seção "Gerar a ISO" |

## Imagens offline

`scripts/prepare-offline.sh` (precisa de Docker e de internet na VM de build, como root):

1. Lê `live-build/offline/imagens.txt` (linhas em branco e `#` são ignoradas).
2. Se a imagem não existe localmente ou o digest local difere do travado, faz `docker pull`.
3. Confere o digest de `RepoDigests` com o travado. Divergindo, falha com `FALHA: digest de ... diverge`.
4. `docker save` para `live-build/config/includes.chroot/var/lib/nexus-os/images/<repositório>_<tag>.tar` (`/` e `:` viram `_`), por exemplo `quay.io_frrouting_frr_10.7.1.tar`, 199157248 bytes.

### Como adicionar uma imagem, passo a passo

**Onde:** terminal da VM de build, na raiz do repositório.

**Passo 1: baixar a imagem e ler o digest.** O *digest* é a impressão digital da imagem (`sha256:...`); travá-lo garante que o build sempre use exatamente a mesma imagem.

```bash
sudo docker pull <repositório>:<tag>
sudo docker image inspect --format '{{index .RepoDigests 0}}' <repositório>:<tag>
```

**Deve aparecer:** o `pull` termina com `Status: Downloaded newer image` (ou `Image is up to date`) e o segundo comando imprime `<repositório>@sha256:<digest>`. **Se não aparecer:** `pull access denied` ou `not found` indica nome ou tag errados; sem internet o `pull` falha.

**Passo 2: travar o digest.** Acrescente a linha `<repositório>:<tag> sha256:<digest>` em `live-build/offline/imagens.txt` (linhas em branco e `#` são ignoradas).

**Passo 3: gerar a ISO.** `sudo scripts/build-iso.sh`. **Deve aparecer:** `OK: <repositório>:<tag> sha256:<digest> -> live-build/config/includes.chroot/var/lib/nexus-os/images/...tar` e o `.tar` entra na ISO; o `nexus-images.service` o carrega no boot. **Se não aparecer:** `FALHA: digest de ... diverge` indica digest errado na linha do passo 2.

**Passo 4: testar.** Acrescente ao `tests/containers.sh` (ou a um teste novo) a checagem da imagem e rode o smoke da seção seguinte.

`nexus-images-load` lê as tags do `manifest.json` do `.tar` e só roda `docker load` se alguma tag faltar; rodar de novo imprime `já carregada`. A unidade é `Type=oneshot` com `RemainAfterExit=yes` (`ActiveState=active`, `SubState=exited` depois da carga), com `After=` e `Requires=` de `docker.service`. `nexus-smoke.service` tem `After=nexus-images.service`. O `systemd-analyze verify` das três unidades (`nexus-images.service`, `nexus-smoke.service`, `var-lib-docker.mount`) dentro da ISO deu saída vazia e código 0. A saída do `nexus-images.service` vai só para o journal: texto no console depois do `login:` fazia o `tests/iso.sh` não achar o prompt no fim da linha.

## Smoke test `containers`

`tests/containers.sh` roda só dentro da ISO (`/proc/cmdline` com `boot=live`):

1. `ip route show default` vazio (sem internet de verdade).
2. `docker info` responde; o teste imprime o driver e exige `overlay2`.
3. `docker image inspect quay.io/frrouting/frr:10.7.1` existe.
4. `docker run --rm --network none --entrypoint /usr/lib/frr/zebra <imagem> --version` imprime `zebra version 10.7.1_git`.
5. `docker ps -aq` vazio no fim.

**Como rodar** (na VM de build, depois de gerar a ISO, sem rede e sem janela):

```bash
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso containers
```

**Por quê:** inicia a ISO sem rede num QEMU e roda o `tests/containers.sh` dentro dela. **Deve aparecer:** `OK: 1 teste(s) sem falha em <segundos> s`, com `containers=2s` nos tempos por teste. **Se não aparecer:** `FALHA: smoke com falhas: ... END com erro` com a mensagem `FALHA:` do teste (por exemplo `driver de armazenamento do Docker é vfs, esperado overlay2` ou `imagem ... não carregada`); relate com ela.

## Medições (23/10/2026, VM Debian 13 no Hyper-V com KVM, 4 vCPU e 8 GB)

| Item | Valor |
| --- | --- |
| RED 1: `containers.sh` (via `--extra`) na ISO da parte 2 | `FALHA: docker não instalado (pacote docker.io)`, `DONE 1 1`, código 1 |
| RED 2: `prepare-offline.sh` com digest `0000...` | `FALHA: digest de quay.io/frrouting/frr:10.7.1 diverge`, código 1 |
| RED 3: `containers.sh` exigindo `overlay2` na ISO com `vfs` | `FALHA: driver de armazenamento do Docker é vfs, esperado overlay2` |
| Falha do `head` no teste | com 1024 MiB, `zebra --version \| head -1` deu `write /dev/stdout: broken pipe` e `FALHA: contêiner ... não rodou`; corrigido lendo a saída inteira |
| Build da ISO final | 257 s; 893386752 bytes (a ISO da parte 2 tinha 688914432: +204472320 bytes); SHA256 `9d08c4f31eac3e8f1b4d6e16655b81d5e7d63796fca9ff179b966f960831ccb9` |
| `tests/iso-smoke.sh ... containers` | `OK: 1 teste(s) sem falha em 30 s`, `containers=2s`, com KVM, sem rede |
| `tests/iso-smoke.sh ... all` | `OK: 4 teste(s) sem falha em 39 s` (`sdn=8s`, `virtualizacao=2s`, `libvirt=1s`, `containers=2s`), com KVM |
| `tests/iso-smoke.sh ... sdn,virtualizacao,libvirt` | `OK: 3 teste(s) sem falha em 36 s`, com KVM |
| `tests/iso.sh` (QEMU com 1024 MiB) | `OK: ISO chegou ao login` em 24 s, com KVM |
| Tempo do `nexus-images.service` no boot | 5,7 s (`systemd-analyze blame`); `docker.service` 2,2 s |
| RAM com `overlay2` (`free -m`, guest com 4096 MiB) | usada: 251 MB sem imagem, 647 MB com a imagem carregada (+396 MB, inclui `dockerd` e cache); 706 MB logo depois do boot |
| RAM com `vfs` (sem o tmpfs) | usada: 264 MB sem imagem, 1192 MB com a imagem (+928 MB); 692 MB em `/var/lib/docker` |
| Menor RAM do smoke `containers` | passa com 1024 MiB, falha com 768 MiB (uma medição de cada) |
| Mutação M1 (digest errado em `imagens.txt`) | `FALHA: digest de ... diverge: travado sha256:aaaaaaaa..., obtido sha256:e995beaa...`, código 1 |
| Mutação M2 (`--extra` com a imagem `frr:10.7.99`) | `FALHA: imagem quay.io/frrouting/frr:10.7.99 não carregada`, `NEXUS-SMOKE-END containers 1` |

O `tests/iso.sh` continua com 1024 MiB: a carga cabe, então não foi criada a variável `NEXUS_ISO_MEM`.

## Problemas conhecidos

- O build da ISO agora exige Docker e internet na VM de build (para o `docker pull`). Sem internet e sem a imagem local, o `prepare-offline.sh` falha.
- Os dados do Docker ficam em RAM (tmpfs) e somem no desligamento. Cada imagem a mais aumenta o uso de RAM da ISO: meça de novo ao acrescentar uma.
- Com 768 MiB o smoke `containers` falhou. A causa não foi investigada nem o mínimo exato.
- `docker load` não preserva `RepoDigests`: dentro da ISO o teste confere a tag, e o digest só é conferido no build.
- O smoke `containers` só prova o Docker e a imagem do FRR. O pacote `frr` e o Containerlab entraram na parte 4 (veja [nfv.md](nfv.md)); a lista de imagens não mudou, e o `scripts/prepare-offline.sh` agora também baixa o `.deb` do Containerlab.
- Reprodução por segunda pessoa pendente.

## Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste documento e para tudo que ele não explicou. **Onde:** uma **issue** no repositório no GitHub. **Título:** `<tarefa>: <passo>: <resumo curto>`. **Corpo:** **Passos** (comandos exatos), **Saída** (texto exato copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (Debian, versão do Docker, RAM da VM, com ou sem KVM, commit). Uma issue por falha, sem dado pessoal.
