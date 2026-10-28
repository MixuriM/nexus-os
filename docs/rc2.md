# RC2 do Nexus OS (F3.17 e F3.18)

Segunda release candidate: a RC1 (núcleo da stack) mais o **ambiente gráfico** XFCE com login automático, os 9 atalhos dos componentes e a identidade visual do Nexus OS. Não há tag Git nesta fase: a tag é do congelamento da ISO (F4.6).

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc2-amd64.iso` (cópia da ISO do build limpo, com `.sha256` regenerado para esse nome) |
| Commit do build | `007f7ba0b53e74f4c16d4868cf0bbd1a1be768ad` (clone novo de `origin/marcos`) |
| Data | 2026-10-28 |
| Tamanho | 1295843328 bytes |
| SHA256 | `a21a7eb9506646ad567c6c92a6bac0c32153be247face0a5a41839ddc319913c` |
| Tempo do build | 703 s, um comando (`sudo scripts/build-iso.sh`), terminou com `Build completed successfully` |
| Ambiente do build | Debian 13 em VM Hyper-V com KVM, 4 vCPU, 6 GB estáticos |
| Onde fica | na máquina do responsável (VM de build, pasta `dist/` do clone, fora do Git) |

Esta é a **segunda geração da RC2**: a primeira (commit `7ddf021`, SHA256 `0692c04a...`, 1268842496 bytes) tinha o tema Greybird, os ícones Tango e uma marca desenhada à parte; depois de testar a ISO numa VM do Hyper-V, a identidade foi refeita com a logo original, o tema Nexus-Dark, ícones Papirus-Dark e fonte Inter (F3.17), e o vídeo do Hyper-V Geração 1 passou a ser fixado no `/dev/dri/card0`. Todos os números abaixo são da ISO nova.

Os documentos desta pasta que entram na ISO (`/usr/share/nexus-os/docs`) são os do commit do build. `rc2.md` e `requisitos.md` (seção "Com ambiente gráfico") têm o SHA256 da ISO e por isso nascem depois dela: a ISO não os contém.

## Build limpo com um comando

Clone novo de `origin/marcos` em pasta nova, depois só `sudo scripts/build-iso.sh` (ordem interna: `lb clean`, `lb config`, `scripts/stage-iso-files.sh`, `scripts/prepare-offline.sh`, `lb build`).

| Item | Valor |
| --- | --- |
| Tempo | 703 s (com o clone) |
| Tamanho | 1295843328 bytes, +374145024 sobre a RC1 (921698304) |
| Origem do aumento | desktop XFCE, `firefox-esr`, `virt-manager`, `lightdm` e dependências (+338427904 na F3.15 e F3.16) e a identidade visual (+35717120: tema de ícones `papirus-icon-theme`, fonte `fonts-inter` e as imagens, veja [branding.md](branding.md)) |

## Validação da RC2

Todas as execuções abaixo são **com KVM**, exceto a indicada, na VM de build do Hyper-V, em guest QEMU limpo e sem rede. Todas usam a ISO do build limpo (SHA256 acima).

| Teste | Resultado |
| --- | --- |
| `tests/run-fase3.sh dist/nexus-os-rc2-amd64.iso` | `OK: tests/run-fase3.sh (9 testes)` em 270 s: `lint-repo`, `docs`, `gui-spec`, `atalhos`, `identidade`, `iso` (36 s), `iso-smoke all`, `requisitos` e `manual` |
| `iso-smoke all` dentro do `run-fase3.sh`, 4096 MiB | `OK: 8 teste(s) sem falha em 135 s` (`desktop` 50 s); repouso 1164 MiB, pico 1452 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=4096` (coleta do pico) | `OK: 8 teste(s) sem falha em 141 s` (`desktop` 53 s); pico 1439 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=2048` (RAM recomendada, validação) | `OK: 8 teste(s) sem falha em 129 s` (`desktop` 51 s); pico 1296 MiB |
| `tests/manual.sh` | `OK: 12 bloco(s) do manual na ISO` em 93 s (8 blocos do núcleo e 4 do desktop) |
| Smoke `desktop` **sem KVM** (`NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048`) | `OK: 1 teste(s) sem falha em 505 s`, `desktop=244s`; repouso 811 MiB, pico 1303 MiB |
| Mínimos de RAM e tempo até a sessão (20 s) | [requisitos.md](requisitos.md), seção "Com ambiente gráfico" |

Identidade visual na ISO: o smoke `desktop` confere o papel de parede padrão do `user` (`/usr/share/backgrounds/nexus-os/papel-de-parede.png`, lido pelo `xfconf-query` do monitor ativo), os temas GTK, de ícones e de janelas (Nexus-Dark, Papirus-Dark e Nexus-Dark), o título "Nexus OS" no menu e o nome completo "Nexus OS" do usuário. Capturas de tela da sessão e do login em [branding.md](branding.md).

Mutações: M1 (SVG com tag sem fechar), M2 (licença removida de `docs/branding.md`) e M5 (logo da ISO diferente da original de `assets/`) fazem o `tests/identidade.sh` falhar; M3 (`tests/desktop.sh` esperando outro papel de parede, por `--extra`) dá `FALHA: papel de parede do Nexus OS ausente`; M4 (comando inexistente num bloco do manual, feita na primeira geração da RC2) dá `FALHA: smoke com falhas: ... NEXUS-SMOKE-END manual 127`; e a remoção de uma linha numérica de `requisitos.md` faz o `tests/requisitos.sh` falhar.

Ordem dos REDs, antes da implementação: `tests/identidade.sh` sem arquivos, `tests/requisitos.sh` e `tests/docs.sh` sem a seção nova e o smoke `desktop` na ISO anterior (`FALHA: papel de parede do Nexus OS ausente`). Os testes acharam três bugs: a chave errada do papel de parede do xfdesktop (o smoke passava, a captura mostrava o papel de parede do XFCE), o manual com a contagem antiga de 7 testes no `smoke.list` e o `lint-repo.sh` tratando o gerador em Python como shell. O teste na VM do Hyper-V Geração 1 achou o bug do vídeo (`lightdm` em laço, `Cannot run in framebuffer mode`), que nenhum teste em QEMU podia pegar e que o `20-hyperv.conf` corrige.

## Ambiente

Debian 13 em VM Hyper-V com KVM (`/dev/kvm`), 4 vCPU, 6 GB de RAM estáticos; live-build do Debian 13; QEMU do Debian 13 com `-vga std`, `-nic none` e 2 vCPU no guest. Todas as medições são com KVM, salvo a linha "sem KVM".

## Limitações e riscos conhecidos

- **`nexus-smoke.service` continua na RC2:** a unidade que executa como root o conteúdo de um CD `NEXUS_SMOKE` não foi removida. A decisão de removê-la ou condicioná-la é do congelamento da ISO (F4.6; issue 32).
- A reprodução por uma segunda pessoa, a execução do roteiro humano do desktop (parte H de [checklist-teste-documentacao.md](checklist-teste-documentacao.md)) e a premissa 1 nas máquinas dos demais integrantes continuam pendentes. Nada desta RC conta como tal.
- O desktop abriu numa VM do Hyper-V Geração 1 da primeira geração da RC2, mas só depois de a configuração de vídeo ser digitada à mão no console; a **ISO desta geração, com o `20-hyperv.conf`, ainda não foi iniciada no Hyper-V** (issue 55). VirtualBox, Geração 2 e vídeo real também não foram iniciados. O papel de parede foi conferido só no monitor `Virtual-1` do QEMU (issue 56).
- Mínimo de RAM: com 1536 MiB o `all` passa, mas o `desktop` leva 82 s; com 1280, 1024 e 768 MiB falha. O `tests/iso.sh` chega ao `login:` com 512 MiB, sem provar a sessão gráfica.
- Os fluxos interativos (clique nos ícones, terminal esperando Enter, VM criada pelo `virt-manager`) não foram exercitados: os atalhos foram lançados pelo `gtk-launch` com `NEXUS_ATALHO_TESTE=1`.
- A barra da tela de login mostra o nome de máquina `debian` e o menu de boot (isolinux) ainda mostra "Debian GNU/Linux" e o capacete do live-build ([branding.md](branding.md), "Problemas conhecidos"; issue 57).
- A RAM em repouso varia entre execuções (issue 33); o desligamento da live pede ENTER (issue 34).
- A RC2 não tem tag Git: a tag é do congelamento.

Falhas e limitações viram issues com o ID da tarefa no título: 54 (roteiro humano do desktop), 55 (Hyper-V e VirtualBox), 56 (papel de parede em outros monitores) e 57 (nome de máquina no login).
