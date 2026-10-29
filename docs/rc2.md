# RC2 do Nexus OS (F3.17 e F3.18)

Segunda release candidate: a RC1 (núcleo da stack) mais o **ambiente gráfico** XFCE com login automático, os 10 atalhos dos componentes, a identidade visual do Nexus OS, a barra única embaixo como a do Windows, o idioma português do Brasil e programas prontos para uso (LibreOffice, Wireshark, VLC, GIMP, Inkscape, KeePassXC e mais). Não há tag Git nesta fase: a tag é do congelamento da ISO (F4.6).

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc2-amd64.iso` (cópia da ISO do build limpo, com `.sha256` regenerado para esse nome) |
| Commit do build | `e4abbf04fd2ccc45d33b5d5a005a639c830b427b` (clone novo de `origin/marcos`) |
| Data | 2026-10-28 |
| Tamanho | 1774911488 bytes |
| SHA256 | `c1a1d5c28c4eca5d33b53999f9aa034e04f98202fc1d694fc341f962126d0eba` |
| Tempo do build | 816 s, um comando (`sudo scripts/build-iso.sh`), terminou com `Build completed successfully` |
| Ambiente do build | Debian 13 em VM Hyper-V com KVM, 4 vCPU, 6 GB estáticos |
| Onde fica | na máquina do responsável (VM de build, pasta `dist/` do clone, fora do Git) |

Esta é a **terceira geração da RC2**. A primeira (commit `7ddf021`) tinha o tema Greybird e ícones Tango; a segunda (commit `007f7ba`, SHA256 `a21a7eb9...`, 1295843328 bytes) trouxe a logo original, o tema Nexus-Dark, os ícones Papirus-Dark e a fonte Inter. Depois de a segunda ser testada no Hyper-V Geração 1, a terceira refez a barra (uma só, embaixo, com a lista de janelas), criou o tema de ícones Nexus, tirou as faixas dos fundos, trocou o menu de boot, passou o sistema para português do Brasil com teclado ABNT2, fuso de Brasília e nome de máquina `nexus-os`, acrescentou os programas (veja [gui.md](gui.md), "Programas incluídos"), a documentação em HTML, o atalho Configurações e a tecla Print. Todos os números abaixo são da ISO nova.

Os documentos desta pasta que entram na ISO (`/usr/share/nexus-os/docs`) são os do commit do build. `rc2.md` e `requisitos.md` (seção "Com ambiente gráfico") têm o SHA256 da ISO e por isso nascem depois dela: a ISO não os contém. Esta ISO é a do último commit com todos os documentos e testes. Os números de RAM, os mínimos, o `run-fase3` e o smoke sem KVM abaixo foram medidos numa ISO anterior, do commit `d9c40b8` (SHA256 `391734920cad410da5d42464c11d0633e3ca88f9320c8e0c9fa20473ab93ffc9`, 1773174784 bytes, build de 1164 s), com a mesma lista de pacotes; essa ISO foi apagada da VM por engano e refeita no commit acima. Na ISO final foram repetidos o `tests/iso.sh` (`OK` em 36 s) e o smoke `desktop` (`OK: 1 teste(s) sem falha em 102 s`, repouso 1114 MiB, pico 1852 MiB com 4096 MiB).

## Build limpo com um comando

Clone novo de `origin/marcos` em pasta nova, depois só `sudo scripts/build-iso.sh` (ordem interna: `lb clean`, `lb config`, `scripts/stage-iso-files.sh`, `scripts/prepare-offline.sh`, `lb build`).

| Item | Valor |
| --- | --- |
| Tempo | 816 s (com o clone) |
| Tamanho | 1774911488 bytes, +853213184 sobre a RC1 (921698304) e +479068160 sobre a RC2 anterior (1295843328) |
| Origem do aumento sobre a RC2 anterior | LibreOffice, Wireshark, VLC, GIMP, Inkscape, KeePassXC, ferramentas de rede, pacotes de idioma e os demais de `nexus-desktop.list.chroot` ([gui.md](gui.md)); o tema de ícones Nexus e os fundos pesam pouco ([branding.md](branding.md)) |

## Validação da RC2

Todas as execuções abaixo são **com KVM**, exceto a indicada, na VM de build do Hyper-V, em guest QEMU limpo e sem rede. Todas usam a ISO do build limpo (SHA256 acima).

| Teste | Resultado |
| --- | --- |
| `tests/run-fase3.sh dist/nexus-os-rc2-amd64.iso` | `OK: tests/run-fase3.sh (9 testes)`: `lint-repo`, `docs`, `gui-spec`, `atalhos`, `identidade`, `iso` (36 s), `iso-smoke all`, `requisitos` e `manual` |
| `iso-smoke all` dentro do `run-fase3.sh`, 4096 MiB | `OK: 8 teste(s) sem falha em 135 s` (`desktop` 53 s); repouso 1127 MiB, pico 1786 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=4096` (coleta do pico) | `OK: 8 teste(s) sem falha em 181 s` (`desktop` 64 s); pico 1827 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=2560` (RAM recomendada, validação) | `OK: 8 teste(s) sem falha em 172 s` (`desktop` 66 s); pico 1722 MiB |
| `tests/manual.sh` | `OK: 13 bloco(s) do manual na ISO` em 94 s |
| Smoke `desktop` **sem KVM** (`NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048`, espera por atalho de 300 s) | `OK: 1 teste(s) sem falha em 1196 s`, `desktop=782s`; repouso 836 MiB, pico 1707 MiB. Com a espera de 150 s o teste falhou: sem KVM o `nexus-vnf-up` passa de 150 s |
| Smoke `rede` (QEMU com `-nic user`, script fora do repositório) | o NetworkManager pegou `10.0.2.15/24` por DHCP em `ens3`, rota padrão por `10.0.2.2`, DNS e `HTTP/1.1 200 OK` em `deb.debian.org`; nome da máquina `nexus-os` |
| Menu de boot, BIOS (isolinux) e UEFI (GRUB, OVMF) | título "Nexus OS", logo e entradas em português; o boot inicia sozinho depois de 5 s |
| Mínimos de RAM e tempo até a sessão (23 s) | [requisitos.md](requisitos.md), seção "Com ambiente gráfico" |

O smoke `desktop` confere, além do que já conferia: a barra única embaixo (`tasklist`, sem `pager`, uma área de trabalho, janela do `xfce4-panel` na parte de baixo da tela), o idioma `pt_BR.UTF-8`, o fuso `America/Sao_Paulo`, o teclado `br`, o nome da máquina `nexus-os`, a tela sem bloqueio, o programa padrão de `.md`, texto, PDF, imagem e HTML, a presença dos programas, o `docs-html`, o grupo `wireshark` e o `dumpcap`, a tecla Print e os 10 atalhos executados (incluindo documentação no Firefox e Configurações). Os temas conferidos são Nexus-Dark (GTK e janelas) e Nexus (ícones).

Achados dos testes (não foram feitas mutações novas nesta geração): o `light-locker` vinha como recomendação do `lightdm` e o teste de tela sem bloqueio o pegou (o hook `0600` passou a removê-lo); o ID do Wireshark no `mimeapps.list` estava errado e foi corrigido pela conferência no chroot; o `shellcheck` acusou SC2015 em `tests/desktop.sh`; o `run-fase3.sh` falhou com `Permissão negada` porque três testes estavam sem bit de execução no Git (corrigido). Os REDs vieram antes: `tests/atalhos.sh`, `tests/identidade.sh` e `tests/docs.sh` falharam com `FALHA:` antes de qualquer implementação.

## Ambiente

Debian 13 em VM Hyper-V com KVM (`/dev/kvm`), 4 vCPU, 6 GB de RAM estáticos; live-build do Debian 13; QEMU do Debian 13 com `-vga std`, `-nic none` (e `-nic user` só no teste de rede) e 2 vCPU no guest. Todas as medições são com KVM, salvo a linha "sem KVM".

## Limitações e riscos conhecidos

- **`nexus-smoke.service` continua na RC2:** a unidade que executa como root o conteúdo de um CD `NEXUS_SMOKE` não foi removida. A decisão de removê-la ou condicioná-la é do congelamento da ISO (F4.6; issue 32).
- A reprodução por uma segunda pessoa e a execução do roteiro humano do desktop (parte H de [checklist-teste-documentacao.md](checklist-teste-documentacao.md)) continuam pendentes. Nada desta RC conta como tal.
- Uma versão anterior da RC2 subiu sozinha no Hyper-V Geração 1, a 1080p em tela cheia e em janela de 1024x768; a **ISO desta geração ainda não foi iniciada no Hyper-V** (issue 55). VirtualBox, Geração 2 e vídeo real também não. O papel de parede foi conferido só no monitor `Virtual-1` do QEMU (issue 56).
- Mínimo de RAM: com 1792 MiB o `all` passa, mas o `desktop` leva 202 s; com 1536, 1280 e 1024 MiB falha. A recomendada é 2560 MiB. O `tests/iso.sh` chega ao `login:` com 512 MiB, sem provar a sessão gráfica.
- A ISO tem 1691 MiB: cabe em DVD e pendrive, não em CD.
- Os fluxos interativos (clique nos ícones, terminal esperando Enter, VM criada pelo `virt-manager`, abrir os programas novos) não foram exercitados: os atalhos foram lançados pelo `gtk-launch` com `NEXUS_ATALHO_TESTE=1` e os programas só tiveram a presença conferida.
- O Hyper-V precisa de `Connect-VMNetworkAdapter` para a VM ter internet ([manual.md](manual.md)); a ISO só foi testada com rede no QEMU.
- A barra da tela de login mostra o relógio e o nome de máquina (agora `nexus-os`).
- A RAM em repouso varia entre execuções (issue 33); o desligamento da live pede ENTER (issue 34).
- A RC2 não tem tag Git: a tag é do congelamento.

Falhas e limitações viram issues com o ID da tarefa no título: 54 (roteiro humano do desktop), 55 (Hyper-V e VirtualBox), 56 (papel de parede em outros monitores) e 57 (nome de máquina no login, resolvido nesta geração: a máquina agora é `nexus-os`).
