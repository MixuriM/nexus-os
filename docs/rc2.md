# RC2 do Nexus OS (F3.17 e F3.18)

Segunda release candidate: a RC1 (núcleo da stack) mais o **ambiente gráfico** XFCE com login automático, os 10 atalhos dos componentes, a identidade visual do Nexus OS, a barra única embaixo como a do Windows, o idioma português do Brasil e programas prontos para uso (LibreOffice, Wireshark, VLC, GIMP, Inkscape, KeePassXC e mais). Não há tag Git nesta fase: a tag é do congelamento da ISO (F4.6).

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc2-amd64.iso` (cópia da ISO do build limpo, com `.sha256` regenerado para esse nome) |
| Commit do build | `fc572613` (clone novo de `origin/marcos`; a ISO anterior da rodada 5, SHA256 `8889f613...38aa`, é do commit `f10dcaa` e foi a testada no Hyper-V Geração 2) |
| Data | 2026-11-03 |
| Tamanho | 1990639616 bytes (1898 MiB) |
| SHA256 | `bb6d89c68970fb24bb6e35ec3db0a74a88490b257eed166729edb941ce673e58` |
| Tempo do build | 1355 s (ISO anterior da rodada 5: 1063 s; rodada 4: 1076 s; rodada 3: 816 s), um comando (`sudo scripts/build-iso.sh`), terminou com `Build completed successfully` |
| Ambiente do build | Debian 13 em VM Hyper-V com KVM, 4 vCPU, 6 GB estáticos |
| Onde fica | na máquina do responsável (VM de build, pasta `dist/` do clone, fora do Git) |

Esta é a **quinta rodada da RC2** (03/11/2026): as melhorias M1 a M19 pedidas depois do teste manual de 29/10/2026 (barra com menu whisker e docklike, relógio em duas linhas, tecla Super, ícones e opção de ícone padrão, 39 aplicativos novos; detalhes em [gui.md](gui.md)), sem loja de aplicativos. O teste manual de 29/10/2026 no Hyper-V Geração 2 foi feito com a ISO de SHA256 `f5516d56...fe30` (rodada 4), anterior às melhorias. A rodada 4 foi: a mesma lista de pacotes da terceira geração, com o módulo `floppy` bloqueado (o disquete virtual do Hyper-V Geração 1 deixa de aparecer, `etc/modprobe.d/nexus-os-sem-disquete.conf` e `update-initramfs` no hook) e o LibreOffice sem o aviso de primeira execução (`etc/skel/.config/libreoffice/4/user/registrymodifications.xcu`, [branding.md](branding.md)). O teste manual de 28/10/2026 no Hyper-V Geração 1 foi feito com a ISO da terceira geração (commit `e4abbf0`, SHA256 `c1a1d5c2...0eba`, 1774911488 bytes, build de 816 s), anterior à correção do disquete. A primeira (commit `7ddf021`) tinha o tema Greybird e ícones Tango; a segunda (commit `007f7ba`, SHA256 `a21a7eb9...`, 1295843328 bytes) trouxe a logo original, o tema Nexus-Dark, os ícones Papirus-Dark e a fonte Inter. Depois de a segunda ser testada no Hyper-V Geração 1, a terceira refez a barra (uma só, embaixo, com a lista de janelas), criou o tema de ícones Nexus, tirou as faixas dos fundos, trocou o menu de boot, passou o sistema para português do Brasil com teclado ABNT2, fuso de Brasília e nome de máquina `nexus-os`, acrescentou os programas (veja [gui.md](gui.md), "Programas incluídos"), a documentação em HTML, o atalho Configurações e a tecla Print. Todos os números abaixo são da ISO da rodada 4, salvo as linhas "Rodada 5" e onde indicado.

Os documentos desta pasta que entram na ISO (`/usr/share/nexus-os/docs`) são os do commit do build. `rc2.md` e `requisitos.md` (seção "Com ambiente gráfico") têm o SHA256 da ISO e por isso nascem depois dela: a ISO não os contém. Esta ISO é a do último commit com todos os documentos e testes. Os mínimos de RAM e o tempo sem KVM abaixo foram medidos na rodada 3 (ISO do commit `d9c40b8`, mesma lista de pacotes); a rodada 4 repetiu o `run-fase3` e o `all` com 4096 e 2560 MiB.

## Build limpo com um comando

Clone novo de `origin/marcos` em pasta nova, depois só `sudo scripts/build-iso.sh` (ordem interna: `lb clean`, `lb config`, `scripts/stage-iso-files.sh`, `scripts/prepare-offline.sh`, `lb build`).

| Item | Valor |
| --- | --- |
| Tempo | 1355 s (clone novo; ISO anterior da rodada 5: 1063 s) |
| Tamanho | 1990639616 bytes, +215728128 sobre a rodada 4 (1774911488), +1068941312 sobre a RC1 (921698304) |
| Origem do aumento sobre a RC2 anterior | LibreOffice, Wireshark, VLC, GIMP, Inkscape, KeePassXC, ferramentas de rede, pacotes de idioma e os demais de `nexus-desktop.list.chroot` ([gui.md](gui.md)); o tema de ícones Nexus e os fundos pesam pouco ([branding.md](branding.md)) |

## Validação da RC2

Todas as execuções abaixo são **com KVM**, exceto a indicada, na VM de build do Hyper-V, em guest QEMU limpo e sem rede. Todas usam a ISO do build limpo (SHA256 acima).

| Teste | Resultado |
| --- | --- |
| Rodada 5: RED na ISO da rodada 4 (`--extra tests/desktop.sh`) | `FALHA:` em 42 asserções novas (M1 a M17, D9, D12), sem erro de sintaxe |
| Rodada 5: `all` na ISO final (commit `fc57261`), 4096 MiB e 2560 MiB | `OK: 8 teste(s) sem falha em 216 s` (`desktop=133s`, repouso 1095 MiB, pico 2006 MiB) e em 219 s com 2560 MiB (`desktop=141s`, repouso 909 MiB, pico 1863 MiB); com KVM |
| Rodada 5: mutações do `desktop.sh` por `--extra` (18, uma por pedido, sem rebuild) | cada uma terminou em `FALHA:` com o prefixo do pedido (M1 a M17, D9 e D12); com KVM |
| Rodada 5: `tests/manual.sh` | `OK: tests/manual.sh (13 bloco(s) do manual na ISO, 94 s, com KVM)`, depois de atualizar os blocos 10, 11 e 12 do manual para a barra e os 12 atalhos |
| Rodada 5: `tests/run-fase3.sh dist/nexus-os-rc2-amd64.iso` (clone novo, commit `fc57261`) | `OK: tests/run-fase3.sh (9 testes)`: `lint-repo`, `docs`, `gui-spec`, `atalhos`, `identidade`, `iso`, `iso-smoke`, `requisitos` e `manual` (13 blocos); a execução anterior, no commit `2e79e84`, parou no `manual` porque os blocos 10 a 12 do manual ainda eram da barra antiga, e antes disso no `lint-repo` (SC2015 em `tests/gui-spec.sh`); os dois foram corrigidos; com KVM |
| Rodada 5: capturas do QEMU olhadas | barra centralizada, relógio com hora e data, menu aberto pela tecla Super, GIMP na busca, realce e dica do botão da logo, `nexus-barra esquerda`, `nexus-icone`, janela "Ícones dos aplicativos", bateria simulada (pasta falsa) e `xfce4-session-logout --halt` desligando a VM; "Monitor": 0 janelas; com KVM |
| Rodada 5: teste manual no Hyper-V Geração 2 (03/11/2026, ISO `8889f613...38aa`, Marcos, não conta como segunda pessoa) | N1 a N20 passaram; ressalvas: janela do Terminal e do Arquivos não agrupa com o ícone fixado da barra (docklike sem `StartupWMClass`, corrigido no repositório, falta nova ISO), grupo da barra cerca de 80 px à esquerda do centro, ícone "user" do Thunar fora do estilo, menu lembra o Windows 7; a bateria do notebook apareceu com 100% |
| Rodada 5: N7 refeito na ISO `bb6d89c6...3e58` (Hyper-V Geração 2, 03/11/2026, Marcos) | passou: Terminal, Arquivos e Configurações abertos pelos ícones fixados ficam sob o próprio ícone, com a linha de estado embaixo e sem ícone novo; o ícone "user" do Thunar segue simples |
| `tests/run-fase3.sh dist/nexus-os-rc2-amd64.iso` | `OK: tests/run-fase3.sh (9 testes)`: `lint-repo`, `docs`, `gui-spec`, `atalhos`, `identidade`, `iso` (36 s), `iso-smoke all`, `requisitos` e `manual` (clone limpo, ISO da rodada 4) |
| `iso-smoke all` dentro do `run-fase3.sh`, 4096 MiB | `OK: 8 teste(s) sem falha em 138 s` (`desktop` 54 s); repouso 1084 MiB, pico 1852 MiB |
| (rodada 3) `iso-smoke all`, `NEXUS_SMOKE_MEM=4096` (coleta do pico) | `OK: 8 teste(s) sem falha em 181 s` (`desktop` 64 s); pico 1827 MiB |
| `iso-smoke all`, `NEXUS_SMOKE_MEM=2560` (RAM recomendada, validação) | `OK: 8 teste(s) sem falha em 135 s` (`desktop` 56 s); repouso 930 MiB, pico 1772 MiB |
| `tests/manual.sh` | `OK: 13 bloco(s) do manual na ISO` em 94 s |
| (rodada 3) Smoke `desktop` **sem KVM** (`NEXUS_SMOKE_KVM=0 NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048`, espera por atalho de 300 s) | `OK: 1 teste(s) sem falha em 1196 s`, `desktop=782s`; repouso 836 MiB, pico 1707 MiB. Com a espera de 150 s o teste falhou: sem KVM o `nexus-vnf-up` passa de 150 s |
| Smoke `rede` (QEMU com `-nic user`, script fora do repositório) | o NetworkManager pegou `10.0.2.15/24` por DHCP em `ens3`, rota padrão por `10.0.2.2`, DNS e `HTTP/1.1 200 OK` em `deb.debian.org`; nome da máquina `nexus-os` |
| Teste manual no Hyper-V Geração 1 (28/10/2026, capturas de tela, ISO da rodada 3) | boot, desktop em 1024x768, barra, hora de Brasília, internet, Writer, Mousepad, Print e teclado ABNT2 funcionaram; o ícone "Disco Disquete" dava erro ao abrir (corrigido na rodada 4, linha abaixo) |
| Disquete virtual (QEMU com disquete vazio, `NEXUS_SMOKE_FLOPPY=1`) | RED na ISO da rodada 3: `/dev/fd0` presente, módulo `floppy` carregado aos 1,3 s (dentro do initramfs) e `gio mount -l` listava "Disco Disquete". GREEN na ISO nova: `OK: 1 teste(s) sem falha em 114 s` (`desktop` 59 s), sem `floppy` no `lsmod`, sem `/dev/fd0`. Mutação M1 (arquivo `.conf` ausente na cópia do teste): `FALHA: ... nexus-os-sem-disquete-x.conf ausente`, código 1. Com KVM. Não repetido no Hyper-V Geração 1 |
| LibreOffice sem aviso de primeira execução | RED: a captura do Writer na ISO da rodada 3 mostra a faixa "You are running version 25.2 of LibreOffice for the first time"; na ISO nova a faixa não aparece (capturas do QEMU, não versionadas). Mutação M2 (chave `ShowTipOfTheDay` alterada na cópia do teste): `FALHA: ... sem ShowTipOfTheDayX=false`, código 1. Com KVM |
| Teste manual no Hyper-V Geração 2 (29/10/2026, Secure Boot desligada, 2560 MB, 2 vCPU, `Default Switch`, capturas de tela) | rodada 1 do roteiro H: H2 a H6 passaram (barra em 22 s, nenhum ícone de disquete, hora de Brasília, `ç` e `~`, Wireshark capturando em `eth0` como `user`, VLC, GIMP, Inkscape e KeePassXC abriram, Containerlab criou e removeu `clab-frr-duo-r1` e `r2`, `poweroff` desligou a VM). Executado por Marcos, não conta como segunda pessoa |
| Botão "Monitor" sem ícone na barra (captura de 28/10/2026) | botão cinza sem ícone na lista de janelas, visto uma vez; não reproduzido no QEMU (`xwininfo -root -tree` sem janela "Monitor") nem na rodada 1 da Geração 2; segue a investigar |
| Menu de boot, BIOS (isolinux) e UEFI (GRUB, OVMF) | título "Nexus OS", logo e entradas em português; o boot inicia sozinho depois de 5 s |
| Mínimos de RAM e tempo até a sessão (23 s) | [requisitos.md](requisitos.md), seção "Com ambiente gráfico" |

O smoke `desktop` confere, além do que já conferia: a barra única embaixo (`tasklist`, sem `pager`, uma área de trabalho, janela do `xfce4-panel` na parte de baixo da tela), o idioma `pt_BR.UTF-8`, o fuso `America/Sao_Paulo`, o teclado `br`, o nome da máquina `nexus-os`, a tela sem bloqueio, o programa padrão de `.md`, texto, PDF, imagem e HTML, a presença dos programas, o `docs-html`, o grupo `wireshark` e o `dumpcap`, a tecla Print e os 10 atalhos executados (incluindo documentação no Firefox e Configurações). Os temas conferidos são Nexus-Dark (GTK e janelas) e Nexus (ícones).

Achados dos testes (não foram feitas mutações novas nesta geração): o `light-locker` vinha como recomendação do `lightdm` e o teste de tela sem bloqueio o pegou (o hook `0600` passou a removê-lo); o ID do Wireshark no `mimeapps.list` estava errado e foi corrigido pela conferência no chroot; o `shellcheck` acusou SC2015 em `tests/desktop.sh`; o `run-fase3.sh` falhou com `Permissão negada` porque três testes estavam sem bit de execução no Git (corrigido). Os REDs vieram antes: `tests/atalhos.sh`, `tests/identidade.sh` e `tests/docs.sh` falharam com `FALHA:` antes de qualquer implementação.

## Ambiente

Debian 13 em VM Hyper-V com KVM (`/dev/kvm`), 4 vCPU, 6 GB de RAM estáticos; live-build do Debian 13; QEMU do Debian 13 com `-vga std`, `-nic none` (e `-nic user` só no teste de rede) e 2 vCPU no guest. Todas as medições são com KVM, salvo a linha "sem KVM".

## Limitações e riscos conhecidos

- **`nexus-smoke.service` continua na RC2:** a unidade que executa como root o conteúdo de um CD `NEXUS_SMOKE` não foi removida. A decisão de removê-la ou condicioná-la é do congelamento da ISO (F4.6; issue 32).
- A reprodução por uma segunda pessoa e a execução do roteiro humano do desktop (parte H de [checklist-teste-documentacao.md](checklist-teste-documentacao.md)) continuam pendentes. Nada desta RC conta como tal. Em 29/10/2026 Marcos executou H2 a H6 no Hyper-V Geração 2 (tudo passou; não é segunda pessoa). O roteiro do VirtualBox (H1-C) segue sem execução.
- No Hyper-V Geração 1, a ISO da rodada 3 (SHA256 `c1a1d5c2...0eba`) subiu sozinha (2560 MB, 2 vCPU, `Default Switch`) em 28/10/2026, conferida por um integrante do grupo a partir de capturas de tela: menu de boot, desktop em janela de 1024x768 (limite do vídeo da Geração 1: use tela cheia ou outro ambiente), barra inferior, hora de Brasília, internet no Firefox, LibreOffice Writer em português, `.md` no Mousepad, tecla Print e teclado ABNT2. O ícone "Disco Disquete" dessa ISO dava `Error mounting /dev/fd0 ... Can't open blockdev`; a ISO desta rodada bloqueia o módulo `floppy` e a unidade não aparece no QEMU com disquete virtual, sem novo teste no Hyper-V Geração 1. O botão "Monitor" sem ícone visto numa captura em tela cheia não foi reproduzido no QEMU. VirtualBox e vídeo real não foram iniciados; a Geração 2 foi validada em 29/10/2026. O papel de parede foi conferido só no monitor `Virtual-1` do QEMU (issue 56).
- Mínimo de RAM: com 1792 MiB o `all` passa, mas o `desktop` leva 202 s; com 1536, 1280 e 1024 MiB falha. A recomendada é 2560 MiB. O `tests/iso.sh` chega ao `login:` com 512 MiB, sem provar a sessão gráfica.
- Mídia: a ISO é feita só para pendrive e VM, por decisão do grupo; use um pendrive (ou a ISO anexada em VM) com capacidade de pelo menos o tamanho dela (veja [requisitos.md](requisitos.md)).
- Os fluxos interativos (clique nos ícones, terminal esperando Enter, VM criada pelo `virt-manager`, abrir os programas novos) não foram exercitados: os atalhos foram lançados pelo `gtk-launch` com `NEXUS_ATALHO_TESTE=1` e os programas só tiveram a presença conferida.
- O Hyper-V precisa de `Connect-VMNetworkAdapter` para a VM ter internet ([manual.md](manual.md)); a ISO só foi testada com rede no QEMU.
- A barra da tela de login mostra o relógio e o nome de máquina (agora `nexus-os`).
- A RAM em repouso varia entre execuções (issue 33); o desligamento da live pede ENTER (issue 34).
- A RC2 não tem tag Git: a tag é do congelamento.

Falhas e limitações viram issues com o ID da tarefa no título: 54 (roteiro humano do desktop), 55 (Hyper-V e VirtualBox), 56 (papel de parede em outros monitores) e 57 (nome de máquina no login, resolvido nesta geração: a máquina agora é `nexus-os`).
