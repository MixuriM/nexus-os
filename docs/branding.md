# Identidade visual do Nexus OS (F3.17)

Logo, papel de parede, tela de login, tema, ícones e fonte do Nexus OS, com a origem e a licença de cada arquivo. A base continua sendo o Debian 13: o `/etc/os-release` não muda e o sistema se apresenta como Debian nas ferramentas que leem esse arquivo. A identidade do Nexus OS é visual (login, sessão e barra); nenhuma marca ou logotipo do Debian, do XFCE ou de terceiros é usada como identidade do projeto.

## A logo e a paleta

A logo dentro da ISO é a **logo original do projeto**, `assets/logo-nexus-os.svg` (a mesma do README): o `/usr/share/pixmaps/nexus-os-logo.svg` é uma cópia idêntica dela, e o `tests/identidade.sh` confere isso com `cmp`. Escolhi o SVG porque escala sem perda (ícone da barra de 16 px até a tela de login) e pesa 10 KB; o PNG original tem 2 MB e fica só no repositório. O PNG entra apenas dentro dos fundos já compostos (papel de parede e login, 1920x1080).

A paleta é a da logo: azul-escuro `#23253e` (superfícies), azul `#2b66a8` e magenta `#8d2c79` (destaques e o gradiente da marca), mais tons do mesmo matiz para texto (`#e4e6fb`), bordas (`#3d4075`) e fundos profundos (`#14152a` e `#1b1c36`). O ícone da barra (`nexus-os.svg`) é a marca da logo original (losango com o N) sobre o quadrado azul-escuro dela, sem o texto.

## Arquivos criados para o projeto

A licença é a do repositório, GPL-3.0-or-later ([LICENSE](../LICENSE)). Os caminhos da ISO são relativos à raiz do sistema; `<inc>` abaixo é `live-build/config/includes.chroot`.

| Arquivo no repo | Arquivo na ISO | Origem | Licença | Onde é usado |
| --- | --- | --- | --- | --- |
| `live-build/config/includes.chroot/usr/share/pixmaps/nexus-os-logo.svg` | `/usr/share/pixmaps/nexus-os-logo.svg` | logo original do projeto (`assets/logo-nexus-os.svg`), copiada sem alteração | GPL-3.0-or-later | logo completa (marca e nome) para documentos e telas |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-os.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-os.svg` | marca recortada da logo original (`scripts/gerar-identidade.py`) | GPL-3.0-or-later | ícone `nexus-os`: botão do menu da barra e imagem do usuário no login |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-terminal.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-terminal.svg` | criado para o projeto (`scripts/gerar-identidade.py`) | GPL-3.0-or-later | atalho "Terminal do Nexus OS" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-vm.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-vm.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Gerenciador de máquinas virtuais" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-sdn.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-sdn.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Laboratório Open vSwitch" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-vnf-up.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-vnf-up.svg` | criado para o projeto | GPL-3.0-or-later | atalho "VNF FRR: instanciar" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-vnf-status.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-vnf-status.svg` | criado para o projeto | GPL-3.0-or-later | atalho "VNF FRR: estado" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-vnf-down.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-vnf-down.svg` | criado para o projeto | GPL-3.0-or-later | atalho "VNF FRR: remover" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-clab-up.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-clab-up.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Topologia Containerlab: criar" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-clab-down.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-clab-down.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Topologia Containerlab: remover" |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-docs.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-docs.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Documentação do Nexus OS" |
| `live-build/config/includes.chroot/usr/share/backgrounds/nexus-os/papel-de-parede.svg` | `/usr/share/backgrounds/nexus-os/papel-de-parede.svg` | composição própria com a logo original (`scripts/gerar-identidade.py`) | GPL-3.0-or-later | fonte vetorial do papel de parede |
| `live-build/config/includes.chroot/usr/share/backgrounds/nexus-os/papel-de-parede.png` | `/usr/share/backgrounds/nexus-os/papel-de-parede.png` | convertido do SVG (1920x1080) | GPL-3.0-or-later | papel de parede padrão da sessão do `user` |
| `live-build/config/includes.chroot/usr/share/backgrounds/nexus-os/tela-de-login.svg` | `/usr/share/backgrounds/nexus-os/tela-de-login.svg` | composição própria com a logo original | GPL-3.0-or-later | fonte vetorial do fundo do login |
| `live-build/config/includes.chroot/usr/share/backgrounds/nexus-os/tela-de-login.png` | `/usr/share/backgrounds/nexus-os/tela-de-login.png` | convertido do SVG (1920x1080) | GPL-3.0-or-later | fundo da tela de login, com a logo original |
| `live-build/config/includes.chroot/usr/share/themes/Nexus-Dark/index.theme` | `/usr/share/themes/Nexus-Dark/index.theme` | criado para o projeto | GPL-3.0-or-later | descreve o tema Nexus-Dark |
| `live-build/config/includes.chroot/usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css` | `/usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css` | criado para o projeto: importa o Adwaita escuro do GTK 3 (`libgtk-3-common` 3.24.49-3, LGPL-2.1+) e redefine as cores com a paleta da logo | GPL-3.0-or-later (o Adwaita importado mantém a licença do pacote) | tema GTK: janelas, barra, menus, gerenciador de arquivos, login |
| `live-build/config/includes.chroot/usr/share/themes/Nexus-Dark/xfwm4/themerc` | `/usr/share/themes/Nexus-Dark/xfwm4/themerc` (mais 56 arquivos `.xpm` na mesma pasta) | derivado do tema Greybird-dark (`greybird-gtk-theme` 3.23.3-1), recolorido por `scripts/gerar-tema-xfwm4.py` | GPL-2+ ou CC-BY-SA-3.0+ (a do Greybird, à escolha) | bordas, barra de título e botões das janelas |
| `live-build/config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf` | `/etc/lightdm/lightdm-gtk-greeter.conf` | criado para o projeto (substitui o arquivo de comentários do pacote) | GPL-3.0-or-later | fundo, tema, ícones, fonte e imagem do usuário no login |
| `live-build/config/includes.chroot/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml` | `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml` | criado para o projeto | GPL-3.0-or-later | papel de parede padrão do XFCE (`Virtual-1`, `monitor0` e `monitor1`) e ícones da área de trabalho |
| `live-build/config/includes.chroot/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml` | `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml` | criado para o projeto | GPL-3.0-or-later | tema e fonte do título das janelas |
| `live-build/config/includes.chroot/etc/xdg/xfce4/terminal/terminalrc` | `/etc/xdg/xfce4/terminal/terminalrc` | criado para o projeto | GPL-3.0-or-later | cores do terminal na paleta da logo |
| `live-build/config/includes.chroot/etc/X11/xorg.conf.d/20-hyperv.conf` | `/etc/X11/xorg.conf.d/20-hyperv.conf` | criado para o projeto | GPL-3.0-or-later | fixa o dispositivo de vídeo `/dev/dri/card0` (Hyper-V Geração 1, issue 55) |
| `live-build/config/includes.chroot/etc/modprobe.d/nexus-os-sem-disquete.conf` | `/etc/modprobe.d/nexus-os-sem-disquete.conf` | criado para o projeto | GPL-3.0-or-later | bloqueia o módulo `floppy`: o disquete virtual do Hyper-V Geração 1 não vira `/dev/fd0` nem ícone na área de trabalho |
| `live-build/config/includes.chroot/etc/skel/.config/libreoffice/4/user/registrymodifications.xcu` | `/etc/skel/.config/libreoffice/4/user/registrymodifications.xcu` (copiado para `/home/user`) | criado para o projeto | GPL-3.0-or-later | perfil padrão do LibreOffice sem o aviso "Você está executando a versão X pela primeira vez" (`WhatsNew` em `org.openoffice.Setup/Product` e em `org.openoffice.Office.UI.Infobar/Enabled`) e sem a dica do dia (`ShowTipOfTheDay`); chaves lidas do `main.xcd` da ISO |
| `live-build/config/includes.chroot/usr/share/icons/hicolor/scalable/apps/nexus-configuracoes.svg` | `/usr/share/icons/hicolor/scalable/apps/nexus-configuracoes.svg` | criado para o projeto | GPL-3.0-or-later | atalho "Configurações" |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/index.theme` | `/usr/share/icons/Nexus/index.theme` | criado para o projeto: tema de ícones `Nexus`, herda do `Papirus-Dark` e do `hicolor` | GPL-3.0-or-later | descreve o tema de ícones padrão do desktop e do login |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/places/user-home.svg` | `/usr/share/icons/Nexus/scalable/places/user-home.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | pasta pessoal na área de trabalho e no Thunar |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/places/user-trash.svg` | `/usr/share/icons/Nexus/scalable/places/user-trash.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | lixeira vazia |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/places/user-trash-full.svg` | `/usr/share/icons/Nexus/scalable/places/user-trash-full.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | lixeira com arquivos |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/media-floppy.svg` | `/usr/share/icons/Nexus/scalable/devices/media-floppy.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | disquete (a máquina virtual do Hyper-V mostra um) |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/media-optical.svg` | `/usr/share/icons/Nexus/scalable/devices/media-optical.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | mídia óptica (a ISO montada) |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/drive-optical.svg` | `/usr/share/icons/Nexus/scalable/devices/drive-optical.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | unidade óptica |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/drive-removable-media.svg` | `/usr/share/icons/Nexus/scalable/devices/drive-removable-media.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | pendrive e disco removível |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/drive-harddisk.svg` | `/usr/share/icons/Nexus/scalable/devices/drive-harddisk.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | disco |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/devices/computer.svg` | `/usr/share/icons/Nexus/scalable/devices/computer.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | sistema de arquivos e computador |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/apps/org.xfce.thunar.svg` | `/usr/share/icons/Nexus/scalable/apps/org.xfce.thunar.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | gerenciador de arquivos (Thunar) na barra e no menu |
| `live-build/config/includes.chroot/usr/share/icons/Nexus/scalable/apps/system-file-manager.svg` | `/usr/share/icons/Nexus/scalable/apps/system-file-manager.svg` | criado para o projeto (`scripts/gerar-identidade.py`), no estilo dos ícones dos atalhos | GPL-3.0-or-later | ícone genérico de gerenciador de arquivos |
| `live-build/config/includes.chroot/etc/xdg/xfce4/panel/default.xml` | `/etc/xdg/xfce4/panel/default.xml` | criado para o projeto (substitui o do pacote `xfce4-panel`) | GPL-3.0-or-later | barra única embaixo, como a do Windows: menu Nexus OS, lançadores, janelas abertas, bandeja, relógio; sem seletor de áreas de trabalho |
| `live-build/config/includes.chroot/usr/share/firefox-esr/distribution/policies.json` | `/usr/share/firefox-esr/distribution/policies.json` | criado para o projeto | GPL-3.0-or-later | Firefox sem página de boas-vindas e sem verificar navegador padrão; a página inicial é a documentação em HTML (funciona sem internet) |
| `live-build/config/includes.chroot/etc/xdg/mimeapps.list` | `/etc/xdg/mimeapps.list` | criado para o projeto | GPL-3.0-or-later | programa padrão por tipo de arquivo (`.md` e texto no Mousepad, PDF no Evince, imagens no Ristretto, HTML no Firefox) |
| `live-build/config/includes.chroot/etc/X11/xorg.conf.d/00-nexus-teclado.conf` | `/etc/X11/xorg.conf.d/00-nexus-teclado.conf` | criado para o projeto | GPL-3.0-or-later | teclado ABNT2 (`br`) no X |
| `live-build/config/includes.chroot/etc/X11/xorg.conf.d/10-nexus-sem-bloqueio.conf` | `/etc/X11/xorg.conf.d/10-nexus-sem-bloqueio.conf` | criado para o projeto | GPL-3.0-or-later | a tela não apaga nem bloqueia sozinha |
| `live-build/config/includes.chroot/usr/local/bin/nexus-docs-html` | `/usr/local/bin/nexus-docs-html` | criado para o projeto (usa `python3-markdown`) | GPL-3.0-or-later | converte `docs/*.md` em HTML (`/usr/share/nexus-os/docs-html`) no build; o atalho "Documentação" abre o `index.html` no Firefox, sem internet |
| `live-build/config/preseed/nexus-wireshark.cfg.chroot` | não vai para a ISO (roda no build) | criado para o projeto | GPL-3.0-or-later | captura de pacotes sem root no Wireshark (`dumpcap` para o grupo `wireshark`) |
| `live-build/config/bootloaders/splash.svg` | convertido pelo live-build para `splash.png` (isolinux e GRUB) | composição própria com a logo original (`scripts/gerar-identidade.py`) | GPL-3.0-or-later | fundo do menu de boot |
| `live-build/config/bootloaders/syslinux_common/menu.cfg` | `/isolinux/menu.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | título "Nexus OS" e menu de boot sem a pasta de utilitários |
| `live-build/config/bootloaders/syslinux_common/live.cfg.in` | `/isolinux/live.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | entradas "Iniciar o Nexus OS" e "modo de compatibilidade" |
| `live-build/config/bootloaders/syslinux_common/stdmenu.cfg` | `/isolinux/stdmenu.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | cores do menu de boot na paleta da logo |
| `live-build/config/bootloaders/isolinux/isolinux.cfg` | `/isolinux/isolinux.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | contagem de 5 s: o Nexus OS inicia sozinho |
| `live-build/config/bootloaders/grub-pc/config.cfg` | `/boot/grub/config.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | GRUB (UEFI) com contagem de 5 s e sem o toque sonoro |
| `live-build/config/bootloaders/grub-pc/grub.cfg` | `/boot/grub/grub.cfg` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | entradas do GRUB com o nome Nexus OS |
| `live-build/config/bootloaders/grub-pc/theme.cfg` | `/boot/grub/theme.cfg` | cópia do modelo do live-build, sem alteração de conteúdo | GPL-3.0-or-later | liga o tema do GRUB quando existe o `splash.png` |
| `live-build/config/bootloaders/grub-pc/live-theme/theme.txt` | `/boot/grub/live-theme/theme.txt` | criado para o projeto (a partir do modelo do live-build) | GPL-3.0-or-later | título "Nexus OS" e cores do GRUB |
| `live-build/config/hooks/live/0600-nexus-identidade.hook.chroot` | não vai para a ISO (roda no build) | criado para o projeto | GPL-3.0-or-later | título e ícone do menu, tamanho da barra, tema, ícones e fonte padrão, papel de parede como alternativa do Debian |
| `scripts/gerar-identidade.py` | não vai para a ISO | criado para o projeto | GPL-3.0-or-later | gera os ícones, os fundos e a marca a partir da logo original |
| `scripts/gerar-tema-xfwm4.py` | não vai para a ISO | criado para o projeto | GPL-3.0-or-later | gera o tema das janelas a partir do Greybird-dark |
| `docs/img/login.png` | não vai para a ISO | captura de tela da ISO (QEMU, `screendump`) | GPL-3.0-or-later (os elementos de pacotes na imagem mantêm a licença do pacote) | tela de login da ISO |
| `docs/img/sessao.png` | não vai para a ISO | captura de tela da ISO (QEMU, `screendump`) | GPL-3.0-or-later (os elementos de pacotes na imagem mantêm a licença do pacote) | sessão do `user` com a barra, o papel de parede e os atalhos |

Linhas acrescentadas a arquivos que já existiam (mesma licença do repositório):

- `live-build/config/includes.chroot/etc/live/config.conf.d/nexus.conf`: `LIVE_USER_FULLNAME="Nexus OS"`, o nome completo do usuário `user` mostrado na barra (o padrão do live-config é "Debian Live user").
- `live-build/config/package-lists/nexus-desktop.list.chroot`: `papirus-icon-theme`, `fonts-inter` e, na rodada 3, os programas do desktop (veja [gui.md](gui.md), "Programas incluídos").
- Os 10 atalhos `nexus-*.desktop` (menu e área de trabalho): a chave `Icon=` aponta para os ícones próprios acima.

## Arquivos de pacotes do Debian

O que vem de pacote do Debian 13 `main` mantém a licença do pacote (lida em `/usr/share/doc/<pacote>/copyright`) e não é identidade do Nexus OS.

| Pacote | Versão | Licença | Onde é usado |
| --- | --- | --- | --- |
| `papirus-icon-theme` | 20250501-1 | GPL-3 | ícones do desktop (`Papirus-Dark`), acrescentado pela F3.17 |
| `fonts-inter` | 4.1+ds-1 | OFL-1.1 e Apache-2.0 | fonte da interface (`Inter`), acrescentado pela F3.17 |
| `greybird-gtk-theme` | 3.23.3-1 | GPL-2+ ou CC-BY-SA-3.0+ | só a origem das formas do tema das janelas; o pacote **não** vai para a ISO, os arquivos recoloridos estão em `Nexus-Dark/xfwm4` |
| `libgtk-3-common` | 3.24.49-3 | LGPL-2.1+ | o Adwaita escuro que o `gtk.css` do Nexus-Dark importa |
| `tango-icon-theme` | 0.9.0-1 | CC0-1.0 (um arquivo, `application-pdf.png`, em LGPL-2.1) | ícones de apoio (instalado como dependência, não é mais o padrão) |
| `fonts-dejavu-core` | 2.37-8 | Bitstream Vera (as mudanças do DejaVu são de domínio público) | fonte do terminal (`DejaVu Sans Mono`) |
| `desktop-base` | 13.0.4 | veja `/usr/share/doc/desktop-base/copyright` | dependência do desktop: traz papéis de parede e o logotipo do Debian, que **não** são usados como identidade do Nexus OS |
| `lightdm-gtk-greeter` | 2.0.9-1 | veja `/usr/share/doc/lightdm-gtk-greeter/copyright` | a tela de login em si |
| `xfce4-panel`, `xfdesktop4`, `xfwm4` | 4.20.4-1, 4.20.1-1, 4.20.0-1 | veja `/usr/share/doc/<pacote>/copyright` | barra, área de trabalho e janelas |

## Tamanho

| Item | Valor |
| --- | --- |
| ISO da RC2 anterior (identidade com Papirus-Dark e Inter, sem os programas novos) | 1295843328 bytes |
| ISO da RC2 atual (rodada 3) | 1774911488 bytes |
| Diferença | +479068160 bytes (456,9 MiB): quase tudo são os programas (LibreOffice, Wireshark, VLC, GIMP, Inkscape e demais); o tema de ícones Nexus, os fundos com ruído e o menu de boot somam poucos MiB. A estimativa de download feita antes do build era de cerca de 380 MB |
| Origem da diferença | os pacotes dos programas e os de idioma; o `papirus-icon-theme` (22,6 MB no `.deb`) e a fonte Inter já vinham da RC2 anterior |

## Como a identidade é aplicada

- **Login:** `/etc/lightdm/lightdm-gtk-greeter.conf` aponta `background` para `tela-de-login.png` (a logo original), `theme-name` para Nexus-Dark, `icon-theme-name` para Nexus e `default-user-image` para a marca. O `gtk.css` estiliza a janela de login (`#login_window`). Com o login automático (padrão da ISO) a tela de login não aparece; para vê-la, inicie com o parâmetro de boot `live-config.noautologin`.
- **Sessão:** o `xfce4-desktop.xml` do `/etc/xdg` é o padrão do XFCE para qualquer usuário novo, inclusive o `user` que o live-config cria no boot; o `xsettings.xml` (tema, ícones e fonte) e o painel (título "Nexus OS", ícone da marca e altura) são ajustados no hook; o `xfwm4.xml` define o tema das janelas. O live-config só cria o usuário a partir do `/etc/skel` e não toca nesses arquivos de `/etc/xdg`: o smoke `desktop` confirma em boot limpo, como o `user` recém-criado, o papel de parede, os temas, o título do menu e o nome completo.
- **Papel de parede em outros monitores:** o xfdesktop guarda uma configuração por monitor e por área de trabalho. O padrão cobre o monitor `Virtual-1` (o vídeo das VMs do QEMU) e os blocos `monitor0` e `monitor1`; o hook também registra o papel de parede como alternativa `desktop-background` do Debian, o que cobre o caminho padrão `/usr/share/images/desktop-base/default`.
- **Vídeo no Hyper-V:** na Geração 1 o Xorg não sobe sem o `20-hyperv.conf` (o log mostra `Cannot run in framebuffer mode`); com ele fixando `/dev/dri/card0` a sessão abriu na VM do Hyper-V.
- **Debian:** `/etc/os-release` não tem arquivo em `includes.chroot` (o `tests/identidade.sh` confere).

## Como regenerar

O `scripts/gerar-identidade.py` copia a logo original, recorta a marca, desenha os 10 ícones dos atalhos, o tema de ícones Nexus, o fundo do menu de boot e os dois fundos e converte os fundos para PNG 1920x1080. Precisa de `python3` e `rsvg-convert` (pacote `librsvg2-bin`). Na VM de build, na raiz do repositório:

```bash
sudo apt-get install -y librsvg2-bin
python3 scripts/gerar-identidade.py
```

A saída é determinística. O tema das janelas sai de `scripts/gerar-tema-xfwm4.py`, que lê a pasta `xfwm4` do `Greybird-dark` (`apt-get download greybird-gtk-theme` e `dpkg -x`). Depois de gerar, rode `tests/identidade.sh` e refaça a ISO.

## Capturas de tela

As capturas usam o comando `screendump` do monitor do QEMU com `-vga std` (1280x800), convertido para PNG de 256 cores com o `python3-pil` (pacote `python3-pil`), com até 300 KB cada.

- `docs/img/sessao.png`: a ISO iniciada normalmente; a captura foi feita com a sessão do `user` já aberta.
- `docs/img/login.png`: a tela de login só aparece sem o login automático. A captura usou boot direto do kernel e do initrd da ISO com o parâmetro `live-config.noautologin`, só para essa captura; a ISO entregue não muda. O relógio e o nome de máquina que aparecem na barra do login são os do próprio boot.

![Tela de login do Nexus OS](img/login.png)

![Sessão do Nexus OS](img/sessao.png)

## Problemas conhecidos

- A barra do login mostra o relógio e o nome de máquina (`nexus-os`), porque o `lightdm-gtk-greeter` os mostra sempre.
- O `desktop-base` continua instalado (dependência do desktop) e traz o logotipo e os papéis de parede do Debian em `/usr/share`; nenhum é usado pelo Nexus OS.
- O menu de boot (isolinux e GRUB) agora tem a identidade do Nexus OS e contagem de 5 s; o texto "Automatic boot in N seconds..." do isolinux continua em inglês (vem do próprio syslinux).
- O papel de parede padrão foi conferido no monitor `Virtual-1` do QEMU; em outros vídeos (Hyper-V e VirtualBox) ele depende do alternativo `desktop-background` e dos blocos `monitor0` e `monitor1` (issue 56).
- O `20-hyperv.conf` fixa `/dev/dri/card0` para qualquer vídeo; em máquina com mais de uma placa o dispositivo certo pode ser outro.
- Reprodução por segunda pessoa e a conferência em VirtualBox e em máquina física continuam pendentes.
- No Hyper-V Geração 1 a ISO final subiu e o visual conferiu (janela de 1024x768, tema, ícones, barra e papel de parede); o ícone "Disco Disquete" (hardware da VM) que dava `Error mounting /dev/fd0 ... Can't open blockdev` deixou de aparecer porque o módulo `floppy` é bloqueado (`etc/modprobe.d/nexus-os-sem-disquete.conf`); o ícone `media-floppy` do tema fica para o botão Salvar dos aplicativos.
