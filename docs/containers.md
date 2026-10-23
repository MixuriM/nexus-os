# Contêineres: Docker e imagens offline na ISO

F3.4. A ISO traz o Docker e a imagem do FRRouting já dentro dela: depois do boot, sem internet, `docker image ls` mostra a imagem e um contêiner roda. O Containerlab (parte 4 da Fase 3) usa essa mesma imagem.

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

## Imagens offline

`scripts/prepare-offline.sh` (precisa de Docker e de internet na VM de build, como root):

1. Lê `live-build/offline/imagens.txt` (linhas em branco e `#` são ignoradas).
2. Se a imagem não existe localmente ou o digest local difere do travado, faz `docker pull`.
3. Confere o digest de `RepoDigests` com o travado. Divergindo, falha com `FALHA: digest de ... diverge`.
4. `docker save` para `live-build/config/includes.chroot/var/lib/nexus-os/images/<repositório>_<tag>.tar` (`/` e `:` viram `_`), por exemplo `quay.io_frrouting_frr_10.7.1.tar`, 199157248 bytes.

Para adicionar uma imagem:

1. `docker pull <repositório>:<tag>` na VM de build e leia o digest: `docker image inspect --format '{{index .RepoDigests 0}}' <repositório>:<tag>`.
2. Acrescente a linha `<repositório>:<tag> sha256:<digest>` em `live-build/offline/imagens.txt`.
3. Rode `sudo scripts/build-iso.sh`. O `.tar` entra na ISO e o `nexus-images.service` o carrega no boot.
4. Acrescente ao `tests/containers.sh` (ou a um teste novo) a checagem da imagem.

`nexus-images-load` lê as tags do `manifest.json` do `.tar` e só roda `docker load` se alguma tag faltar; rodar de novo imprime `já carregada`. A unidade é `Type=oneshot` com `RemainAfterExit=yes` (`ActiveState=active`, `SubState=exited` depois da carga), com `After=` e `Requires=` de `docker.service`. `nexus-smoke.service` tem `After=nexus-images.service`. O `systemd-analyze verify` das três unidades (`nexus-images.service`, `nexus-smoke.service`, `var-lib-docker.mount`) dentro da ISO deu saída vazia e código 0. A saída do `nexus-images.service` vai só para o journal: texto no console depois do `login:` fazia o `tests/iso.sh` não achar o prompt no fim da linha.

## Smoke test `containers`

`tests/containers.sh` roda só dentro da ISO (`/proc/cmdline` com `boot=live`):

1. `ip route show default` vazio (sem internet de verdade).
2. `docker info` responde; o teste imprime o driver e exige `overlay2`.
3. `docker image inspect quay.io/frrouting/frr:10.7.1` existe.
4. `docker run --rm --network none --entrypoint /usr/lib/frr/zebra <imagem> --version` imprime `zebra version 10.7.1_git`.
5. `docker ps -aq` vazio no fim.

```bash
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso containers
```

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
- O smoke `containers` só prova o Docker e a imagem do FRR. O pacote `frr` e o Containerlab entram na parte 4.
- Reprodução por segunda pessoa pendente.
