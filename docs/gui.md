# Ambiente gráfico: especificação e escolha do desktop (F3.14)

Este documento define o que o Nexus OS entende por interface gráfica, compara por medição os candidatos do Debian 13 (trixie) `main` e registra o desktop escolhido. A ISO entregue não muda nesta etapa: a instalação do desktop na ISO é a F3.15. Os números abaixo vêm de comandos executados em 27/10/2026, **com KVM**, na VM de build do Hyper-V (veja [hyperv.md](hyperv.md)).

## Definição

"Interface gráfica de um sistema operacional atual" significa, no Nexus OS, uma sessão de desktop completa com pacotes do Debian 13 `main`, sem painel web próprio. O critério de aceite da F3.15 é a lista abaixo; cada item foi verificado nos finalistas por comando ou captura de tela.

1. Gerenciador de login com login automático do usuário `user`.
2. Sessão gráfica padrão ativa (`Type=x11` ou `wayland`, `State=active` no `loginctl`).
3. Barra e menu de aplicativos.
4. Gerenciador de janelas.
5. Gerenciador de arquivos gráfico.
6. Terminal gráfico.
7. Navegador: `firefox-esr` 153.5.1esr-1~deb13u1 (`apt-cache policy firefox-esr`).
8. Configuração de rede gráfica (NetworkManager com applet) e de vídeo.
9. Sem internet no boot e sem erro de login.

## Candidatos

Passo A, sem ISO, na VM de build (Debian 13, sem nenhum desktop instalado). Para cada candidato: metapacote do desktop, o gerenciador de login padrão dele e `firefox-esr`. Versão: `apt-cache policy <metapacote>`, linha `Candidato`. Pacotes: `apt-get install -s --no-install-recommends <metapacote> <login> firefox-esr`, linhas `Inst`. Tamanhos: `apt-get install --assume-no --no-install-recommends ...`, linhas `Need to get` (a baixar) e `After this operation` (instalado), em MB do apt.

| Candidato | Metapacote | Versão | Pacotes | A baixar (MB) | Instalado (MB) | Login |
| --- | --- | --- | --- | --- | --- | --- |
| XFCE | `xfce4` | `4.20.1` | 70 | 102 | 401 | `lightdm` |
| LXQt | `lxqt` | `33.2` | 160 | 153 | 508 | `lightdm` |
| MATE | `mate-desktop-environment` | `1.26.0+2` | 184 | 165 | 724 | `lightdm` |
| GNOME | `gnome-core` | `1:48+2` | 559 | 417 | 1645 | `gdm3` |
| KDE Plasma | `kde-plasma-desktop` | `5:162` | 499 | 292 | 1068 | `sddm` |

Versões dos gerenciadores de login: `lightdm` 1.32.0-6+b2, `gdm3` 48.0-2, `sddm` 0.21.0+git20250502.4fe234b-2.

Os três de menor tamanho instalado (XFCE, LXQt e MATE) viram finalistas. GNOME (1645 MB) e KDE Plasma (1068 MB) ficam só com estes números: instalam de 2,7 a 4,1 vezes mais que o XFCE e não foram medidos em ISO.

Conferência de sanidade: com `--no-install-recommends` o XFCE, o LXQt e o MATE ficam sem servidor X (`xorg`) e sem applet de rede. Repetido o passo A com `xorg` e `network-manager-gnome` somados, o instalado vira XFCE 659 MB (225 pacotes), LXQt 614 MB (218), MATE 793 MB (242), KDE Plasma 1112 MB (532) e GNOME 1703 MB (602): os três menores continuam sendo os mesmos.

## Medição

Passo B: uma ISO de teste por finalista, fora do repositório, em um clone temporário da VM de build, com o núcleo atual do repositório mais a lista de pacotes do desktop e nada mais (sem atalhos nem identidade visual). Lista de cada finalista, todos com `lightdm`, `lightdm-gtk-greeter`, `xorg`, `firefox-esr` e `network-manager`:

- XFCE: `xfce4`, `xfce4-terminal`, `network-manager-gnome`
- LXQt: `lxqt`, `nm-tray`
- MATE: `mate-desktop-environment`, `network-manager-gnome`

Cada ISO foi iniciada duas vezes no QEMU com KVM, 4096 MiB, 2 vCPU, `-vga std`, sem rede (`-nic none`) e sem janela (`-display none`). Dentro da ISO um teste espera a sessão do `user` (`loginctl`), registra o `uptime` do guest nesse instante, espera 30 s e lê `free -m` (coluna `used`) 3 vezes com 5 s de intervalo. A coluna RAM é a média das 3 leituras. "Até a sessão" é o `uptime` do guest quando a sessão ficou `active`, em segundos.

| Finalista | Leitura | ISO (bytes) | Build (s) | RAM em repouso (MiB) | Até a sessão (s) | Modo |
| --- | --- | --- | --- | --- | --- | --- |
| XFCE | 1 | 1252147200 | 2240 | 852.7 | 28.4 | com KVM |
| XFCE | 2 | 1252147200 | 2240 | 850.7 | 25.0 | com KVM |
| LXQt | 1 | 1602748416 | 2399 | 868.3 | 26.0 | com KVM |
| LXQt | 2 | 1602748416 | 2399 | 869.7 | 26.4 | com KVM |
| MATE | 1 | 1481506816 | 655 | 889.7 | 29.0 | com KVM |
| MATE | 2 | 1481506816 | 655 | 901.7 | 26.3 | com KVM |

- A ISO do núcleo sem desktop (RC1, [rc1.md](rc1.md)) tem 921698304 bytes.
- Tamanho de `/` em uso: a raiz da live é um overlay sobre tmpfs (26 a 28 MiB usados em todos). O conteúdo do sistema está no `squashfs`, medido com `df -m /run/live/rootfs/filesystem.squashfs`: XFCE 1112 MiB, LXQt 1446 MiB, MATE 1330 MiB.
- O tempo de build do XFCE e do LXQt inclui o download frio dos pacotes (a VM baixa tudo da internet); o MATE foi construído depois, com o cache de pacotes do live-build já quente. Não compare os tempos de build entre si.
- Uma rodada anterior das mesmas ISOs, antes de acrescentar a medição do `squashfs`, deu a mesma ordem: RAM XFCE 857.3 e 846.7, LXQt 867.7 e 864.0, MATE 902.0 e 897.7 MiB.
- Checklist da definição (itens 1 a 9) nos três finalistas: todos cumprem. `lightdm` ativo, sessão do `user` em `seat0` com `Type=x11` e `State=active`, nenhuma rota padrão (`ip route`), e:

| Item | XFCE | LXQt | MATE |
| --- | --- | --- | --- |
| Barra e menu | `xfce4-panel` | `lxqt-panel` | `mate-panel` |
| Janelas | `xfwm4` | `xfwm4` | `marco` |
| Arquivos | `thunar` | `pcmanfm-qt` | `caja` |
| Terminal | `xfce4-terminal` | `qterminal` | `mate-terminal` |
| Rede | `nm-applet` | `nm-tray` | `nm-applet` |
| Vídeo | `xfce4-display-settings` | `lxqt-config-monitor` | `mate-display-properties` |

Captura de tela do XFCE (comando `screendump` do monitor do QEMU, convertida para PNG): ![Sessão XFCE no QEMU](img/gui-xfce.png)

## Escolha

Desktop escolhido: **XFCE**

Regra da decisão: entre os finalistas que cumprem os 9 itens, vale a menor RAM em repouso; diferença menor que 5% desempata pelo menor tamanho de ISO. Média das duas leituras: XFCE 851.7 MiB, LXQt 869.0 MiB, MATE 895.7 MiB. O XFCE tem a menor RAM e a diferença para o LXQt é de 2,0%, então a regra de empate também decide pelo XFCE: a ISO dele (1252147200 bytes) é a menor, 350601216 bytes abaixo da do LXQt e 229359616 abaixo da do MATE. Também tem o menor tamanho instalado no passo A e o menor `squashfs`.

Lista de pacotes validada para a F3.15 (versões conferidas na ISO de teste, `chroot.packages.install`):

| Pacote | Versão |
| --- | --- |
| `xfce4` | 4.20.1 |
| `xfce4-terminal` | 1.1.4-1 |
| `xfce4-panel` | 4.20.4-1 |
| `xfwm4` | 4.20.0-1 |
| `xfce4-settings` | 4.20.1-1 |
| `thunar` | 4.20.2-1+deb13u1 |
| `lightdm` | 1.32.0-6+b2 |
| `lightdm-gtk-greeter` | 2.0.9-1 |
| `xorg` | 1:7.7+24+deb13u1 |
| `firefox-esr` | 153.5.1esr-1~deb13u1 |
| `network-manager` | 1.52.1-1 |
| `network-manager-gnome` | 1.36.0-3+b1 |

Login automático: o `live-config` 11.0.5 da ISO traz os scripts `0080-gdm3`, `0085-sddm` e `0100-lightdm`. O `0100-lightdm` troca, em `/etc/lightdm/lightdm.conf`, as linhas comentadas `autologin-user=` e `autologin-user-timeout=` por `autologin-user=user` e `autologin-user-timeout=0`; os parâmetros de boot `live-config.noautologin` e `live-config.nox11autologin` o desligam. Nenhuma configuração própria foi necessária: nas medições a sessão do `user` subiu sozinha.

## Sessão sem janela

O `tests/iso-smoke.sh` inicia o QEMU sem interface (`-display none`) e sem rede, com a serial em arquivo. O comando validado nas medições, com a ISO e o CD de comandos `NEXUS_SMOKE`:

```bash
qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 2 -vga std -usb -device usb-tablet \
    -drive file=<iso>,media=cdrom,readonly=on,index=2 \
    -drive file=<smoke.iso>,media=cdrom,readonly=on,index=3 \
    -boot d -nic none -display none -serial file:<serial.log> \
    -chardev pipe,id=mon,path=<fifo> -mon chardev=mon,mode=readline
```

`-vga std` e `-device usb-tablet` entram nas medições e na captura. O `tests/iso-smoke.sh` atual não passa `-vga std` nem o tablet; mesmo assim o smoke `containers` passou com a ISO do XFCE (tabela abaixo). A F3.15 deve acrescentar `-vga std` explícito ao script antes de criar o smoke `desktop`.

Dentro do guest, sem tela, a sessão é consultada por `loginctl`:

```bash
loginctl list-sessions --no-legend
loginctl show-session <id> -p Name -p Type -p State --value
```

A sessão do `user` está pronta quando `Name=user`, `Type=x11` e `State=active`. A captura de tela vem do monitor: `screendump arquivo.ppm` (PPM, convertido para PNG com Python).

RAM mínima medida com o XFCE (com KVM, 2 vCPU, uma execução por valor): o smoke `containers` (`NEXUS_SMOKE_MEM=<MiB> tests/iso-smoke.sh <iso> containers`) e a sessão ativa.

| RAM do guest (MiB) | Smoke `containers` | Sessão do `user` ativa |
| --- | --- | --- |
| 4096 | OK em 45 s, pico 989 MiB | sim (medições acima) |
| 3072 | OK em 42 s, pico 909 MiB | não medido |
| 2048 | OK em 39 s, pico 786 MiB | sim, 25.8 s, 753 MiB |
| 1536 | OK em 39 s, pico 786 MiB | sim, 27.1 s, 746 MiB |
| 1024 | OK em 45 s, pico 720 MiB | sim, 29.3 s, 741 MiB |
| 768 | FALHA: `NEXUS-SMOKE-DONE não apareceu em 300 s` | não medido |

O mínimo medido com o desktop é **1024 MiB**; em 768 MiB o `containers` falha (como na ISO do núcleo, veja [requisitos.md](requisitos.md)). O `tests/iso.sh` com a ISO do XFCE passou com os 1024 MiB que ele usa: `OK: ISO chegou ao login` em 33 s, com KVM.

Recomendação: manter `NEXUS_SMOKE_MEM=4096` (padrão). Para uso interativo, 2048 MiB como valor provisório; a RAM recomendada definitiva depende do `all` com desktop, que a F3.18 mede. O `tests/iso.sh` não tem a variável `NEXUS_ISO_MEM` (a memória é fixa em 1024 MiB) e não precisou dela com o XFCE.

VMs de build:

- Hyper-V: a ISO de teste tem boot BIOS (isolinux) e UEFI (`/boot/grub/efi.img`), conferido com `xorriso -indev <iso> -report_el_torito plain`. Isso permite uma VM de Geração 2; o boot nela e o Secure Boot não foram validados.
- VirtualBox: sem KVM (em CPU AMD o KVM aninhado derruba a VM, veja [integracao-iso.md](integracao-iso.md)); o desktop não foi validado lá.

## Impacto nos requisitos

| Item | Núcleo (RC1) | Com XFCE | Fonte |
| --- | --- | --- | --- |
| ISO (bytes) | 921698304 | 1252147200 | tamanho do arquivo; +330448896 bytes (mídia de pelo menos 1195 MiB) |
| RAM mínima do smoke `containers` (MiB) | 896 (768 falha) | 1024 (768 falha) | `NEXUS_SMOKE_MEM`; com o XFCE o 896 não foi testado |
| RAM em repouso (MiB) | 796 | 852 (sessão ativa, média) | `free -m`, `used`; pontos de medição diferentes, veja abaixo |
| Disco do root em memória (MiB) | 24 | 26 a 28 | `df -m /` (overlay sobre tmpfs) |

A ISO cresce 36%. O "repouso" do núcleo foi lido pelo `nexus-smoke` antes do primeiro teste, sem sessão gráfica; o do XFCE é a média de 3 leituras 30 s depois de a sessão ficar ativa. No `containers` com 4096 MiB o runner leu 989 MiB no início, com o desktop ainda subindo. A F3.18 refaz `docs/requisitos.md` com o `all` e o desktop ativo.

## Problemas conhecidos

- Os números do passo A (candidatos) são relativos ao estado da VM de build (Docker, QEMU e outros já instalados) e usam `--no-install-recommends`; por isso a sanidade com `xorg` e o applet de rede está acima. A medição que decide é a do passo B, em ISO.
- Item 8 da definição: o `nm-applet` (XFCE e MATE) e o `nm-tray` (LXQt) estão em execução, mas o ícone não aparece na captura do XFCE (sem rede). Foi verificado por processo e por comando, não por clique. A F3.15 deve conferir o ícone com o desktop em VM com rede.
- Item 9: "sem erro de login" foi concluído pela sessão `active` e pelo `lightdm` ativo; os logs do `lightdm` não foram lidos.
- Boot em Hyper-V Geração 2, Secure Boot e VirtualBox não foram validados (veja "Sessão sem janela").
- O tempo "até a sessão" é o `uptime` do guest: não inclui firmware nem o menu do isolinux. O tempo medido no host, do início do QEMU até o marcador, ficou entre 33 s e 38 s.
- A RAM do 768 MiB foi testada em uma execução só, e o 3072 MiB e o 896 MiB não tiveram a sessão medida com o XFCE.
- `all` (os 7 smokes) não foi executado com o desktop: só `containers`, a sessão e o `tests/iso.sh`.
- Os scripts de medição (espera da sessão, três leituras de RAM, captura de tela) ficaram fora do repositório; o método está descrito acima. A F3.15 cria o smoke `desktop` definitivo.
- Reprodução por uma segunda pessoa e a medição nas máquinas dos demais integrantes continuam pendentes.
