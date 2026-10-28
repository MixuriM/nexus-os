# RC2 do Nexus OS (F3.17 e F3.18)

Segunda release candidate: a RC1 (núcleo da stack) mais o **ambiente gráfico** XFCE com login automático, os 9 atalhos dos componentes e a identidade visual do Nexus OS. Não há tag Git nesta fase: a tag é do congelamento da ISO (F4.6).

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc2-amd64.iso` (cópia da ISO do build limpo, com `.sha256` regenerado para esse nome) |
| Commit do build | `7ddf0214345ffef4e240f562c438a75524cedfe7` (clone novo de `origin/marcos`) |
| Data | 2026-10-27 |
| Tamanho | 1268842496 bytes |
| SHA256 | `0692c04a9d17a42b6d94c9591ea42b1c367ecd702f06552262d9eee9839c5520` |
| Tempo do build | 631 s, um comando (`sudo scripts/build-iso.sh`), terminou com `Build completed successfully` |
| Ambiente do build | Debian 13 em VM Hyper-V com KVM, 4 vCPU, 6 GB estáticos |
| Onde fica | na máquina do responsável (VM de build, pasta `dist/` do clone, fora do Git) |

Os documentos desta pasta que entram na ISO (`/usr/share/nexus-os/docs`) são os do commit do build. `rc2.md`, `requisitos.md` (seção "Com ambiente gráfico"), as correções do manual (contagem de 8 testes no `smoke.list`) e do `tests/identidade.sh` (aviso do `shellcheck`) nasceram depois da ISO: a ISO não os contém.

## Build limpo com um comando

Clone novo de `origin/marcos` em pasta nova, depois só `sudo scripts/build-iso.sh` (ordem interna: `lb clean`, `lb config`, `scripts/stage-iso-files.sh`, `scripts/prepare-offline.sh`, `lb build`).

| Item | Valor |
| --- | --- |
| Tempo | 631 s (de 22:51 a 23:02, com o clone) |
| Tamanho | 1268842496 bytes, +347144192 sobre a RC1 (921698304) |
| Origem do aumento | desktop XFCE, `firefox-esr`, `virt-manager`, `lightdm` e dependências (+338427904 na F3.15 e F3.16) e a identidade visual (+8716288: tema `greybird-gtk-theme` e as imagens, veja [branding.md](branding.md)) |

## Validação da RC2

Todas as execuções abaixo são **com KVM**, exceto a indicada, na VM de build do Hyper-V, em guest QEMU limpo e sem rede. Todas usam a ISO do build limpo (SHA256 acima).

| Teste | Resultado |
| --- | --- |
| `tests/run-fase3.sh dist/nexus-os-rc2-amd64.iso` | `OK: tests/run-fase3.sh (9 testes)` em 241 s: `lint-repo`, `docs`, `gui-spec`, `atalhos`, `identidade`, `iso` (33 s), `iso-smoke all`, `requisitos` e `manual` |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=4096` (primeira execução, coleta do pico) | `OK: 8 teste(s) sem falha em 126 s` (`desktop` 42 s); repouso 993 MiB, pico 1045 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=2048` (RAM recomendada, validação) | `OK: 8 teste(s) sem falha em 117 s` (`desktop` 41 s); pico 936 MiB |
| `iso-smoke all` dentro do `run-fase3.sh`, 4096 MiB | `OK: 8 teste(s) sem falha em 120 s`; pico 1012 MiB |
| `tests/manual.sh` | `OK: 12 bloco(s) do manual na ISO` em 84 s e 85 s (8 blocos do núcleo e 4 do desktop). A primeira execução achou um erro do manual (o bloco do `nexus-smoke` esperava 7 linhas em `smoke.list`; agora são 8) e foi corrigido |
| Smoke `desktop` **sem KVM** (`NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048`) | `OK: 1 teste(s) sem falha em 442 s`, `desktop=168s`; repouso 759 MiB, pico 945 MiB |
| Mínimos de RAM e tempo até a sessão (20 s) | [requisitos.md](requisitos.md), seção "Com ambiente gráfico" |

Identidade visual na ISO: o smoke `desktop` confere o papel de parede padrão do `user` (`/usr/share/backgrounds/nexus-os/papel-de-parede.png`, lido pelo `xfconf-query`), o tema Greybird, o título "Nexus OS" no menu e o nome completo "Nexus OS" do usuário. Capturas de tela da sessão e do login em [branding.md](branding.md).

Mutações: M1 (SVG do logotipo com tag sem fechar) e M2 (licença removida de `docs/branding.md`) fazem o `tests/identidade.sh` falhar; M3 (`tests/desktop.sh` esperando outro papel de parede, por `--extra`) dá `FALHA: papel de parede do Nexus OS ausente`; M4 (comando inexistente num bloco do manual) dá `FALHA: smoke com falhas: ... NEXUS-SMOKE-END manual 127`; e a remoção de uma linha numérica de `requisitos.md` faz o `tests/requisitos.sh` falhar. 4 de 4 mais a do `requisitos.sh`.

Ordem dos REDs, antes da implementação: `tests/identidade.sh` sem arquivos, `tests/requisitos.sh` e `tests/docs.sh` sem a seção nova e o smoke `desktop` na ISO anterior (`FALHA: papel de parede do Nexus OS ausente`). Dois bugs foram achados pelos próprios testes: a configuração do papel de parede com a chave errada (o smoke passava, mas a captura de tela mostrava o papel de parede do XFCE; a chave certa é `monitor<nome>/workspace0/last-image`, e o teste passou a exigi-la) e o manual com a contagem antiga.

## Ambiente

Debian 13 em VM Hyper-V com KVM (`/dev/kvm`), 4 vCPU, 6 GB de RAM estáticos; live-build do Debian 13; QEMU do Debian 13 com `-vga std`, `-nic none` e 2 vCPU no guest. Todas as medições são com KVM, salvo a linha "sem KVM".

## Limitações e riscos conhecidos

- **`nexus-smoke.service` continua na RC2:** a unidade que executa como root o conteúdo de um CD `NEXUS_SMOKE` não foi removida. A decisão de removê-la ou condicioná-la é do congelamento da ISO (F4.6; issue 32).
- A reprodução por uma segunda pessoa, a execução do roteiro humano do desktop (parte H de [checklist-teste-documentacao.md](checklist-teste-documentacao.md)) e a premissa 1 nas máquinas dos demais integrantes continuam pendentes. Nada desta RC conta como tal.
- Hyper-V (Geração 1 e 2) e VirtualBox não iniciaram a RC2 com o desktop. O papel de parede padrão foi conferido só no monitor `Virtual-1` do QEMU; em outro nome de monitor ele depende do alternativo `desktop-background` e dos blocos `monitor0` e `monitor1`, não conferidos.
- Mínimo de RAM: com 1024 MiB o `all` passa, mas o `desktop` leva 107 s; com 768 MiB falha. O `tests/iso.sh` chega ao `login:` com 512 MiB, sem provar a sessão gráfica.
- Os fluxos interativos (clique nos ícones, terminal esperando Enter, VM criada pelo `virt-manager`) não foram exercitados: os atalhos foram lançados pelo `gtk-launch` com `NEXUS_ATALHO_TESTE=1`.
- A barra da tela de login mostra o nome de máquina `debian` ([branding.md](branding.md), "Problemas conhecidos").
- A RAM em repouso varia entre execuções (issue 33); o desligamento da live pede ENTER (issue 34).
- A RC2 não tem tag Git: a tag é do congelamento.

Falhas e limitações viram issues com o ID da tarefa no título: 54 (roteiro humano do desktop), 55 (Hyper-V e VirtualBox), 56 (papel de parede em outros monitores) e 57 (nome de máquina no login).
