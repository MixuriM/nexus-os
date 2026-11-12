#!/usr/bin/env bash
# Teste do desktop dentro da ISO (F3.15 e F3.16): sem internet, o gerenciador de login está ativo, a
# sessão gráfica do usuário "user" fica ativa, o desktop escolhido (XFCE) está rodando, os atalhos do
# menu existem, são válidos e cada um abre e executa de verdade na sessão, e a identidade visual (papel de
# parede, tema e título do menu do Nexus OS, F3.17) é a padrão do user. Só para a ISO (nexus-smoke).
# Uso: sudo nexus-smoke desktop
set -uo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"

usuario=user
login=lightdm
processos="xfce4-session xfce4-panel xfwm4"
espera_sessao=120
espera_atalho=300
menu=/usr/share/applications
atalhos="nexus-terminal nexus-virt-manager nexus-docs nexus-sdn-lab nexus-vnf-up nexus-vnf-status nexus-vnf-down nexus-clab-deploy nexus-clab-destroy nexus-configuracoes"

# 1. Gerenciador de login ativo (espera curta: o serviço sobe depois do runner).
inicio=$SECONDS
until systemctl is-active --quiet "$login"; do
    [ $((SECONDS - inicio)) -lt "$espera_sessao" ] || fail "$login não está ativo ($(systemctl is-active "$login"))"
    sleep 2
done
echo "gerenciador de login ativo: $login"

# 2. Sessão gráfica do usuário ativa e processos do desktop no ar (laço com limite: o logind marca a sessão
# ativa antes de o painel e o gerenciador de janelas subirem).
inicio=$SECONDS
sessao=
pronto=0
while [ $((SECONDS - inicio)) -lt "$espera_sessao" ]; do
    for id in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        [ "$(loginctl show-session "$id" -p Name --value 2>/dev/null)" = "$usuario" ] || continue
        [ "$(loginctl show-session "$id" -p Type --value 2>/dev/null)" = x11 ] || continue
        [ "$(loginctl show-session "$id" -p State --value 2>/dev/null)" = active ] && sessao=$id
    done
    if [ -n "$sessao" ]; then
        pronto=1
        for p in $processos; do pgrep -u "$usuario" -x "$p" >/dev/null || pronto=0; done
        [ "$pronto" -eq 0 ] || break
    fi
    sleep 2
done
[ -n "$sessao" ] || fail "sessão gráfica de $usuario não ficou ativa em ${espera_sessao} s ($(loginctl list-sessions --no-legend | tr '\n' ';'))"
echo "sessão $sessao de $usuario ativa e gráfica em $((SECONDS - inicio)) s"

# 3. Processos do desktop rodando como o usuário.
for p in $processos; do
    pgrep -u "$usuario" -x "$p" >/dev/null || fail "processo $p não está rodando como $usuario"
done
echo "desktop rodando: $processos"

# 4. Sem internet e sem erro de login.
[ -z "$(ip route show default)" ] || fail "há rota padrão: o teste precisa rodar sem internet ($(ip route show default))"
echo "sem rota padrão: teste sem internet"
erros_login=$(journalctl -b -u "$login" -p err -q --no-pager 2>/dev/null || true)
[ -z "$erros_login" ] || fail "erros do $login no journal: $(head -n 3 <<<"$erros_login" | tr '\n' ';')"

# 5. Atalhos: existem, válidos e com Exec apontando para comando existente.
valor() { grep -m1 "^$2=" "$1" | cut -d= -f2-; }
command -v desktop-file-validate >/dev/null || fail "desktop-file-validate não instalado (pacote desktop-file-utils)"
for a in $atalhos; do
    f=$menu/$a.desktop
    [ -f "$f" ] || fail "atalho ausente: $f"
    saida=$(desktop-file-validate "$f" 2>&1) || fail "desktop-file-validate $f: $saida"
    for w in $(valor "$f" Exec | tr -d '"'); do
        case $w in
            xfce4-terminal | virt-manager | thunar | firefox-esr | xfce4-settings-manager | nexus-atalho | nexus-sdn | nexus-vnf | containerlab | sudo)
                command -v "$w" >/dev/null || fail "$f: comando $w não existe" ;;
        esac
    done
done
echo "atalhos válidos: $(wc -w <<<"$atalhos")"

# 6. Cada atalho abre e executa de verdade, como o usuário, dentro da sessão.
uid=$(id -u "$usuario")
casa=$(getent passwd "$usuario" | cut -d: -f6)
pid_sessao=$(pgrep -u "$usuario" -x xfce4-session | head -n 1)
amb() { tr '\0' '\n' <"/proc/$pid_sessao/environ" | sed -n "s/^$1=//p" | head -n 1; }
tela=$(amb DISPLAY)
xauth=$(amb XAUTHORITY)
bus=$(amb DBUS_SESSION_BUS_ADDRESS)
if [ -z "$tela" ] || [ -z "$bus" ]; then fail "sessão sem DISPLAY ou DBUS_SESSION_BUS_ADDRESS"; fi
como_user() {
    runuser -u "$usuario" -- env HOME="$casa" DISPLAY="$tela" ${xauth:+XAUTHORITY="$xauth"} \
        XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="$bus" NEXUS_ATALHO_TESTE=1 "$@"
}
janelas() { como_user xwininfo -root -tree 2>/dev/null; }
# Atalhos da área de trabalho: executáveis e marcados como confiáveis (bit x mais checksum do xfdesktop).
for a in $atalhos; do
    d=$casa/Desktop/$a.desktop
    [ -x "$d" ] || fail "atalho da área de trabalho ausente ou sem bit de execução: $d"
    soma=$(sha256sum <"$d" | cut -d' ' -f1)
    lida=$(como_user gio info -a metadata::xfce-exe-checksum "$d" | sed -n 's/^ *metadata::xfce-exe-checksum: //p')
    [ "$lida" = "$soma" ] || fail "$d sem metadata::xfce-exe-checksum válido (lido: '${lida:-vazio}')"
done
echo "área de trabalho: 10 atalhos executáveis e confiáveis"
command -v gtk-launch >/dev/null || fail "gtk-launch não instalado"
command -v xwininfo >/dev/null || fail "xwininfo não instalado (pacote x11-utils)"

# Identidade visual (F3.17): a configuração padrão do user aponta para os arquivos do Nexus OS.
papel=/usr/share/backgrounds/nexus-os/papel-de-parede.png
[ -f "$papel" ] || fail "papel de parede do Nexus OS ausente: $papel"
imagens=$(como_user xfconf-query -c xfce4-desktop -l | grep '/last-image$' || true)
[ -n "$imagens" ] || fail "xfce4-desktop sem nenhuma propriedade last-image para $usuario"
for p in $imagens; do
    img=$(como_user xfconf-query -c xfce4-desktop -p "$p")
    [ "$(readlink -f "$img")" = "$papel" ] || fail "$p aponta para '$img', esperado $papel"
done
mon=$(como_user xrandr --listmonitors | awk 'NR == 2 {print $NF}')
img=$(como_user xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor$mon/workspace0/last-image")
[ "$(readlink -f "$img")" = "$papel" ] || fail "monitor $mon sem o papel de parede do Nexus OS (workspace0/last-image '$img')"
# Monitor com nome de hardware real (eDP-1, HDMI-A-1...): o nexus-papel-de-parede cria a entrada dele.
[ -f /etc/xdg/autostart/nexus-papel-de-parede.desktop ] || fail "autostart do nexus-papel-de-parede ausente"
como_user env NEXUS_MONITORES=eDP-1 nexus-papel-de-parede || fail "nexus-papel-de-parede falhou"
img=$(como_user xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitoreDP-1/workspace0/last-image")
[ "$(readlink -f "$img")" = "$papel" ] || fail "nexus-papel-de-parede não definiu o papel do monitor eDP-1 (lido '$img')"
como_user xfconf-query -c xfce4-desktop -r -R -p /backdrop/screen0/monitoreDP-1
# Brilho no máximo em notebook: a regra do udev existe e é válida (a VM não tem backlight para testar o efeito).
udevadm verify /etc/udev/rules.d/90-nexus-brilho.rules || fail "regra 90-nexus-brilho.rules ausente ou inválida"
# Montagem dos discos: lsblk e udisksctl falsos. O NTFS tenta normal e depois só leitura; EFI, swap e já montado ficam de fora.
[ -f /etc/xdg/autostart/nexus-montar-discos.desktop ] || fail "autostart do nexus-montar-discos ausente"
falso=$(mktemp -d)
chmod 777 "$falso"
cat > "$falso/lsblk" <<'FALSO'
#!/bin/sh
echo 'NAME="/dev/sdx1" FSTYPE="ntfs" MOUNTPOINT="" PARTTYPE="ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"'
echo 'NAME="/dev/sdx2" FSTYPE="vfat" MOUNTPOINT="" PARTTYPE="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"'
echo 'NAME="/dev/sdx3" FSTYPE="swap" MOUNTPOINT="" PARTTYPE=""'
echo 'NAME="/dev/sdx4" FSTYPE="ext4" MOUNTPOINT="/mnt" PARTTYPE=""'
FALSO
cat > "$falso/udisksctl" <<'FALSO'
#!/bin/sh
echo "$*" >> "$(dirname "$0")/chamadas"
case "$*" in *"-o ro"*) exit 0 ;; *) exit 1 ;; esac
FALSO
chmod 755 "$falso/lsblk" "$falso/udisksctl"
como_user env PATH="$falso:$PATH" nexus-montar-discos
[ "$(cat "$falso/chamadas")" = "$(printf 'mount -b /dev/sdx1\nmount -b /dev/sdx1 -o ro')" ] \
    || fail "nexus-montar-discos: esperado montar /dev/sdx1 normal e depois só leitura, sem tocar nos outros (chamadas: $(tr '\n' ';' < "$falso/chamadas"))"
rm -rf "$falso"
tema=$(como_user xfconf-query -c xsettings -p /Net/ThemeName)
[ "$tema" = Nexus-Dark ] || fail "tema GTK do $usuario é '$tema', esperado Nexus-Dark"
icones=$(como_user xfconf-query -c xsettings -p /Net/IconThemeName)
[ "$icones" = Nexus ] || fail "tema de ícones do $usuario é '$icones', esperado Nexus"
janelas_tema=$(como_user xfconf-query -c xfwm4 -p /general/theme)
[ "$janelas_tema" = Nexus-Dark ] || fail "tema das janelas do $usuario é '$janelas_tema', esperado Nexus-Dark"
[ -f /usr/share/icons/Nexus/scalable/places/user-home.svg ] || fail "tema de ícones Nexus ausente em /usr/share/icons"
[ -f /usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css ] || fail "tema Nexus-Dark ausente em /usr/share/themes"
nome=$(getent passwd "$usuario" | cut -d: -f5 | cut -d, -f1)
[ "$nome" = "Nexus OS" ] || fail "nome completo do $usuario é '$nome', esperado Nexus OS"

# Barra estilo Windows: uma barra só, embaixo, com o menu e as janelas abertas no centro e sem seletor de áreas de trabalho.
# Os pedidos da rodada 5 da RC2 (M1 a M17, D9c e D12) usam nok(): a falha vai para a contagem e todas aparecem de uma vez.
erros_m=0
nok() { echo "FALHA: $*" >&2; erros_m=$((erros_m + 1)); }
px() { como_user xfconf-query -c xfce4-panel -p "$1" 2>/dev/null; }
mapa=$(como_user xfconf-query -c xfce4-panel -lv | awk '$1 ~ /^\/plugins\/plugin-[0-9]+$/ {sub(".*plugin-", "", $1); print $1, $2}')
plugins=$(awk '{print $2}' <<<"$mapa")
id_de() { awk -v n="$1" '$2 == n {print $1; exit}' <<<"$mapa"; }
ordem=$(px /panels/panel-1/plugin-ids | grep -E '^[0-9]+$')
ordem_nomes=$(for i in $ordem; do awk -v i="$i" '$1 == i {print $2}' <<<"$mapa"; done | tr '\n' ' ')
! grep -qx pager <<<"$plugins" || fail "barra ainda tem o seletor de áreas de trabalho (pager)"
posicao=$(como_user xfconf-query -c xfce4-panel -p /panels/panel-1/position)
case $posicao in p=10\;*) ;; *) fail "barra fora da parte de baixo (position '$posicao', esperado p=10)" ;; esac
# Última coluna do xwininfo: posição absoluta (+x+y); a anterior: tamanho e posição dentro da raiz (LxA+x+y).
barra=$(janelas | grep '("xfce4-panel"' | awk '{ split($(NF - 1), g, /[x+]/); if (g[1] >= 400 && g[2] <= 80) { print $(NF - 1), $NF; exit } }')
[ -n "$barra" ] || fail "nenhuma janela xfce4-panel larga e baixa (barra inferior); janelas: $(janelas | grep -c xfce4-panel)"
[ "${barra##*+}" -ge 400 ] || fail "a barra está em cima ($barra)"
[ "$(como_user xprop -root _NET_NUMBER_OF_DESKTOPS | awk '{print $NF}')" = 1 ] || fail "há mais de uma área de trabalho"
echo "barra inferior $barra, plugins: $(tr '\n' ' ' <<<"$plugins"), 1 área de trabalho"

# ---- Rodada 5 da RC2: barra, menu, relógio, ícones e aplicativos novos (M1 a M17, D9c e D12) ----
css=/usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css
wid=$(id_de whiskermenu)
did=$(id_de docklike)
cid=$(id_de clock)
pid_painel() { pgrep -u "$usuario" -x xfce4-panel | head -n 1; }
# O "xfce4-panel -r" reinicia o painel: espera a janela da barra voltar (até 120 s) antes do próximo passo.
espera_painel() {
    local t=$SECONDS
    sleep 5
    until janelas | grep -q '("xfce4-panel"'; do
        [ $((SECONDS - t)) -lt 120 ] || return 1
        sleep 2
    done
    sleep 5
}
# M1: sem o botão azul de mostrar a área de trabalho.
! grep -qx showdesktop <<<"$plugins" || nok "M1: a barra ainda tem o plugin showdesktop (botão azul de mostrar a área de trabalho)"
# M2: sem o plugin actions (o nome Nexus OS depois do relógio) e sem texto no botão de nenhum plugin.
! grep -qx actions <<<"$plugins" || nok "M2: a barra ainda tem o plugin actions (texto Nexus OS depois do relógio)"
for i in $ordem; do
    [ "$(px "/plugins/plugin-$i/show-button-title")" != true ] || nok "M2: o plugin $i mostra texto no botão (show-button-title verdadeiro)"
done
# M3: o menu mostra só a logo, sem o texto ao lado.
{ [ -n "$wid" ] && [ "$(px "/plugins/plugin-$wid/show-button-title")" = false ]; } \
    || nok "M3: whiskermenu ausente ou com show-button-title diferente de false (plugins: $(tr '\n' ' ' <<<"$plugins"))"
# M4: logo sem quadrado de fundo (um caminho só) e botão maior (barra de 46 a 52 px, ícones de 32 px ou mais).
logo=/usr/share/icons/hicolor/scalable/apps/nexus-os.svg
{ ! grep -q 'fill="#23253e"' "$logo" && [ "$(grep -c '<path' "$logo")" = 1 ]; } \
    || nok "M4: $logo ainda tem o quadrado de fundo (esperado só a marca)"
tam=$(px /panels/panel-1/size)
ico=$(px /panels/panel-1/icon-size)
{ [ "${tam:-0}" -ge 46 ] && [ "$tam" -le 52 ] && [ "${ico:-0}" -ge 32 ]; } \
    || nok "M4: barra com size '$tam' e icon-size '$ico' (esperado size de 46 a 52 e icon-size de 32 ou mais)"
# M5: realce só no botão da logo (passar o mouse e clicar), sem realce em todos os botões, e dica de ferramenta com a tecla Windows.
{ grep -q '^#whiskermenu-button:hover' "$css" && grep -q '^#whiskermenu-button:active' "$css"; } \
    || nok "M5: $css sem o realce de #whiskermenu-button (:hover e :active)"
! grep -q '^\.xfce4-panel button:hover' "$css" || nok "M5: $css ainda realça todos os botões da barra (.xfce4-panel button:hover)"
[ "$(px "/plugins/plugin-${wid:-0}/button-title")" = "Menu do Nexus OS (tecla Windows)" ] \
    || nok "M5: dica de ferramenta (button-title) do menu é '$(px "/plugins/plugin-${wid:-0}/button-title")'"
# M6: ícone do volume menor que o da logo.
grep -qE '^#pulseaudio-button image \{ -gtk-icon-transform: scale\(0\.[0-9]+\); \}' "$css" \
    || nok "M6: $css sem a regra que reduz o ícone do volume (#pulseaudio-button image)"
# M7: dois espaçadores que crescem, menu e docklike no meio; nexus-barra leva para a esquerda e volta.
[ "$ordem_nomes" = "separator whiskermenu docklike separator systray pulseaudio clock " ] \
    || nok "M7: ordem da barra é '$ordem_nomes', esperado 'separator whiskermenu docklike separator systray pulseaudio clock'"
while read -r i; do
    [ "$(px "/plugins/plugin-$i/expand")" = true ] || nok "M7: o espaçador $i não cresce (expand diferente de true)"
done < <(awk '$2 == "separator" {print $1}' <<<"$mapa")
if command -v nexus-barra >/dev/null; then
    como_user nexus-barra esquerda >/dev/null 2>&1 || nok "M7: nexus-barra esquerda falhou"
    [ "$(px /plugins/plugin-1/expand)" = false ] || nok "M7: nexus-barra esquerda não desligou a expansão do espaçador da esquerda"
    espera_painel || nok "M7: o painel não voltou depois de nexus-barra esquerda"
    como_user nexus-barra centro >/dev/null 2>&1 || nok "M7: nexus-barra centro falhou"
    [ "$(px /plugins/plugin-1/expand)" = true ] || nok "M7: nexus-barra centro não religou a expansão do espaçador da esquerda"
    espera_painel || nok "M7: o painel não voltou depois de nexus-barra centro"
else
    nok "M7: comando nexus-barra ausente"
fi
# M8 e M9: o docklike substitui a lista de janelas e os lançadores (só ícones) e guarda os aplicativos fixados.
{ [ -n "$did" ] && ! grep -qx tasklist <<<"$plugins" && ! grep -qx launcher <<<"$plugins"; } \
    || nok "M8: a barra deve ter o docklike no lugar de tasklist e launcher (plugins: $(tr '\n' ' ' <<<"$plugins"))"
grep -qxF 'pinned=nexus-terminal;thunar;firefox-esr;nexus-virt-manager;nexus-configuracoes' /etc/xdg/xfce4/panel/docklike.rc 2>/dev/null \
    || nok "M9: /etc/xdg/xfce4/panel/docklike.rc ausente ou sem os 5 aplicativos fixados"
grep -l libdocklike /proc/[0-9]*/maps 2>/dev/null | grep -q . || nok "M9: nenhum processo do painel carregou o plugin docklike"
# M9 (rodada manual 1): o docklike agrupa a janela com o ícone fixado pelo StartupWMClass do .desktop fixado.
for par in nexus-terminal=Xfce4-terminal nexus-virt-manager=Virt-manager nexus-configuracoes=Xfce4-settings-manager; do
    [ "$(valor "/usr/share/applications/${par%%=*}.desktop" StartupWMClass)" = "${par##*=}" ] || nok "M9: ${par%%=*}.desktop sem StartupWMClass=${par##*=} (a janela abriria fora do ícone fixado)"
done
# M10: em VM não há bateria, então nenhum plugin de energia na barra; a lógica do nexus-bateria com pastas falsas.
! grep -qx power-manager-plugin <<<"$plugins" || nok "M10: a barra tem o plugin de energia numa máquina sem bateria"
dpkg -s xfce4-power-manager-plugins >/dev/null 2>&1 || nok "M10: pacote xfce4-power-manager-plugins não instalado"
[ -f /etc/xdg/autostart/nexus-bateria.desktop ] || nok "M10: /etc/xdg/autostart/nexus-bateria.desktop ausente"
if command -v nexus-bateria >/dev/null; then
    ps_falso=/tmp/nexus-power-supply-teste
    rm -rf "$ps_falso"
    mkdir -p "$ps_falso/vazio" "$ps_falso/com/BAT0"
    chmod -R 755 "$ps_falso"
    [ "$(como_user env NEXUS_POWER_SUPPLY="$ps_falso/vazio" NEXUS_BATERIA_TESTE=1 nexus-bateria)" = nada ] \
        || nok "M10: nexus-bateria sem BAT* deveria imprimir 'nada'"
    [ "$(como_user env NEXUS_POWER_SUPPLY="$ps_falso/com" NEXUS_BATERIA_TESTE=1 nexus-bateria)" = adicionar ] \
        || nok "M10: nexus-bateria com BAT0 deveria imprimir 'adicionar'"
    rm -rf "$ps_falso"
else
    nok "M10: comando nexus-bateria ausente"
fi
# M11: relógio com a hora em cima e a data embaixo (digital-layout 1 = hora e data), 29/10/2026.
{ [ "$(px "/plugins/plugin-${cid:-0}/mode")" = 2 ] && [ "$(px "/plugins/plugin-${cid:-0}/digital-layout")" = 1 ] \
    && [ "$(px "/plugins/plugin-${cid:-0}/digital-time-format")" = '%R' ] \
    && [ "$(px "/plugins/plugin-${cid:-0}/digital-date-format")" = '%d/%m/%Y' ] \
    && [ -n "$(px "/plugins/plugin-${cid:-0}/digital-time-font")" ] && [ -n "$(px "/plugins/plugin-${cid:-0}/digital-date-font")" ]; } \
    || nok "M11: relógio com layout '$(px "/plugins/plugin-${cid:-0}/digital-layout")' (esperado 1: hora em cima e data embaixo, %R e %d/%m/%Y, com fontes)"
# M12 e M13: ícones do gerenciador de arquivos (o nome que o xfce4-file-manager.desktop usa) e da pasta Desktop no tema Nexus.
ic_fm=$(valor /usr/share/applications/xfce4-file-manager.desktop Icon)
for f in "apps/$ic_fm" apps/org.xfce.thunar apps/system-file-manager places/user-desktop; do
    [ -f "/usr/share/icons/Nexus/scalable/$f.svg" ] || nok "M12/M13: ícone ausente no tema Nexus: scalable/$f.svg"
done
# M14: a tecla Super (Windows ou Command) abre o menu.
for k in Super_L Super_R '<Alt>F1'; do
    [ "$(como_user xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/default/$k" 2>/dev/null)" = xfce4-popup-whiskermenu ] \
        || nok "M14: o atalho $k não chama xfce4-popup-whiskermenu"
done
command -v xfce4-popup-whiskermenu >/dev/null || nok "M14: comando xfce4-popup-whiskermenu ausente"
# M15: o GIMP aparece como GIMP; /usr/local/share vem antes de /usr/share no XDG_DATA_DIRS da sessão, então a cópia vence.
[ "$(valor /usr/local/share/applications/gimp.desktop Name 2>/dev/null)" = GIMP ] || nok "M15: /usr/local/share/applications/gimp.desktop sem Name=GIMP"
xdd=$(amb XDG_DATA_DIRS)
pos_local=$(tr ':' '\n' <<<"$xdd" | grep -nxE '/usr/local/share/?' | head -n 1 | cut -d: -f1)
pos_usr=$(tr ':' '\n' <<<"$xdd" | grep -nxE '/usr/share/?' | head -n 1 | cut -d: -f1)
{ [ -n "$pos_local" ] && [ -n "$pos_usr" ] && [ "$pos_local" -lt "$pos_usr" ]; } \
    || nok "M15: XDG_DATA_DIRS da sessão ('$xdd') não põe /usr/local/share antes de /usr/share"
# M16: o grupo Nexus OS do menu usa a logo no lugar da engrenagem.
[ "$(valor /usr/share/desktop-directories/nexus-os.directory Icon)" = nexus-os ] || nok "M16: nexus-os.directory sem Icon=nexus-os"
# M17: menu whisker em grade de ícones grandes, com os botões de sessão (sair, reiniciar e desligar) e os comandos do XFCE.
{ [ -n "$wid" ] && [ "$(px "/plugins/plugin-$wid/view-mode")" = 0 ] && [ "$(px "/plugins/plugin-$wid/launcher-icon-size")" -ge 3 ]; } 2>/dev/null \
    || nok "M17: whiskermenu ausente ou fora do modo grade com ícones grandes (view-mode, launcher-icon-size)"
for k in logout restart shutdown; do
    [ "$(px "/plugins/plugin-${wid:-0}/show-command-$k")" = true ] || nok "M17: botão de sessão '$k' não aparece no menu (show-command-$k)"
done
saida_logout=$(como_user xfce4-session-logout --help 2>&1)
for opcao in --halt --reboot --logout; do
    grep -q -- "$opcao" <<<"$saida_logout" || nok "M17: xfce4-session-logout sem a opção $opcao"
done
# D9c: opção de ícone padrão (ícone original ou do tema Nexus): comandos, atalhos, janela e execução como o usuário.
for c in nexus-icone nexus-icones nexus-icones-janela nexus-barra nexus-bateria; do
    [ -x "/usr/local/bin/$c" ] || nok "D9: /usr/local/bin/$c ausente ou sem bit de execução"
done
command -v zenity >/dev/null || nok "D9: zenity não instalado (janela Ícones dos aplicativos)"
for a in nexus-icones nexus-barra; do
    saida=$(desktop-file-validate "/usr/share/applications/$a.desktop" 2>&1) || nok "D9: desktop-file-validate $a.desktop: $saida"
done
if [ -x /usr/local/bin/nexus-icone ]; then
    # O docklike só relê o .desktop quando o painel reinicia: o nexus-icone reinicia o painel no fim.
    como_user nexus-icone xfce4-file-manager.desktop padrao >/dev/null 2>&1 || nok "D9: nexus-icone xfce4-file-manager.desktop padrao falhou"
    sub=$casa/.local/share/applications/xfce4-file-manager.desktop
    ic=$(valor "$sub" Icon 2>/dev/null)
    case $ic in
        /*) [ -f "$ic" ] || nok "D9: o ícone original $ic não existe" ;;
        *) nok "D9: a cópia $sub não tem Icon= com caminho absoluto (lido '$ic')" ;;
    esac
    espera_painel || nok "D9: o painel não voltou depois de nexus-icone padrao"
    como_user nexus-icone xfce4-file-manager.desktop nexus >/dev/null 2>&1 || nok "D9: nexus-icone xfce4-file-manager.desktop nexus falhou"
    [ ! -e "$sub" ] || nok "D9: nexus-icone ... nexus não removeu $sub"
    espera_painel || nok "D9: o painel não voltou depois de nexus-icone nexus"
fi
if [ -x /usr/local/bin/nexus-icones ]; then
    como_user nexus-icones padrao >/dev/null 2>&1 || nok "D9: nexus-icones padrao falhou"
    [ "$(como_user xfconf-query -c xsettings -p /Net/IconThemeName)" = Papirus-Dark ] || nok "D9: nexus-icones padrao não trocou o tema para Papirus-Dark"
    espera_painel || nok "D9: o painel não voltou depois de nexus-icones padrao"
    como_user nexus-icones nexus >/dev/null 2>&1 || nok "D9: nexus-icones nexus falhou"
    [ "$(como_user xfconf-query -c xsettings -p /Net/IconThemeName)" = Nexus ] || nok "D9: nexus-icones nexus não voltou o tema Nexus"
    espera_painel || nok "D9: o painel não voltou depois de nexus-icones nexus"
fi
# D12: todos os aplicativos da lista nexus-apps.list.chroot estão instalados (tests/gui-spec.sh confere que esta lista é a do arquivo).
apps_novos="libreoffice-draw libreoffice-math thunderbird thunderbird-l10n-pt-br gparted gnome-disk-utility baobab xfce4-taskmanager pavucontrol zenity zip unzip p7zip-full tree bash-completion geany meld filezilla python3-pip python3-venv ansible-core jq rsync graphviz iftop nload whois ethtool ncdu speedtest-cli remmina-plugin-rdp remmina-plugin-vnc xfce4-power-manager-plugins xfce4-whiskermenu-plugin xfce4-docklike-plugin audacity simplescreenrecorder ffmpeg fonts-noto-color-emoji"
faltam=
for p in $apps_novos; do
    dpkg -s "$p" >/dev/null 2>&1 || faltam="$faltam $p"
done
[ -z "$faltam" ] || nok "D12: pacotes da lista de aplicativos não instalados:$faltam"
[ "$erros_m" -eq 0 ] || fail "rodada 5 da RC2: $erros_m asserção(ões) falharam (veja as linhas FALHA: acima)"
echo "rodada 5 da RC2: barra [$ordem_nomes], relógio hora e data, menu whisker, Super, GIMP, ícones e $(wc -w <<<"$apps_novos") aplicativos novos"

# Idioma, teclado, fuso e nome da máquina; tela sem bloqueio; programas padrão por tipo de arquivo.
grep -qx 'LANG=pt_BR.UTF-8' /etc/default/locale || fail "/etc/default/locale sem LANG=pt_BR.UTF-8"
locale -a | grep -qiE '^pt_BR\.utf-?8$' || fail "locale pt_BR.UTF-8 não gerado"
[ "$(readlink -f /etc/localtime)" = /usr/share/zoneinfo/America/Sao_Paulo ] || fail "fuso é '$(readlink -f /etc/localtime)', esperado America/Sao_Paulo"
[ "$(hostname)" = nexus-os ] || fail "nome da máquina é '$(hostname)', esperado nexus-os"
como_user setxkbmap -query | grep -qE '^layout:[[:space:]]+br$' || fail "teclado do X não é br: $(como_user setxkbmap -query | tr '\n' ';')"
! dpkg -s xfce4-screensaver >/dev/null 2>&1 || fail "xfce4-screensaver instalado: a tela não deve bloquear"
! dpkg -s light-locker >/dev/null 2>&1 || fail "light-locker instalado: a tela não deve bloquear"
como_user xset q | grep -qE 'timeout:[[:space:]]+0[[:space:]]' || fail "a tela apaga sozinha: $(como_user xset q | grep -i 'timeout')"
for tipo in text/markdown:mousepad text/plain:mousepad application/pdf:Evince image/png:ristretto text/html:firefox; do
    padrao=$(como_user gio mime "${tipo%%:*}" | sed -n 's/^Default application for.*: //p;s/^Aplicativo padrão.*: //p' | head -n 1)
    grep -qi "${tipo##*:}" <<<"$padrao" || fail "aplicativo padrão de ${tipo%%:*} é '$padrao', esperado ${tipo##*:}"
    [ -f "/usr/share/applications/$padrao" ] || fail "${tipo%%:*}: $padrao não existe em /usr/share/applications"
done
for c in mousepad evince ristretto file-roller galculator xfce4-screenshooter vlc wireshark soffice gimp keepassxc inkscape remmina     tcpdump iperf3 mtr nmap traceroute dig nc curl wget tmux htop vim git firefox-esr; do
    command -v "$c" >/dev/null || fail "programa padrão ausente: $c"
done
[ "$(como_user xfconf-query -c xfce4-keyboard-shortcuts -p /commands/default/Print)" = xfce4-screenshooter ]     || fail "a tecla Print não chama o xfce4-screenshooter"
for h in index manual; do [ -f "/usr/share/nexus-os/docs-html/$h.html" ] || fail "documentação em HTML ausente em /usr/share/nexus-os/docs-html"; done
# Rodada humana H1 (defeito 4): a cerca "```bash nexus-exec" do manual vira caixa de código, não texto corrido.
html_manual=/usr/share/nexus-os/docs-html/manual.html
! grep -qF '```' "$html_manual" || fail "$html_manual tem cerca de código crua: a marca nexus-exec impediu a conversão em <pre>"
grep -qF '<pre><code' "$html_manual" || fail "$html_manual sem nenhuma caixa de código (<pre><code)"
# Rodada humana H1 (2ª tentativa): colar no terminal um bloco de várias linhas com sudo roda o bloco inteiro. Com a colagem em
# bloco desligada o sudo (use_pty) repassa as linhas seguintes ao comando e elas somem. O teste faz o papel do terminal: manda o
# bloco entre as marcas de colagem se o bash as pediu (ESC[?2004h) e, se não, como linhas soltas.
colagem=$(como_user python3 - 2>&1 <<'PY'
import os, pty, select, time
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("bash", ["bash", "-i"])
buf = b""
def le(limite, ate):
    global buf
    fim = time.time() + limite
    while time.time() < fim:
        if select.select([fd], [], [], 0.5)[0]:
            try:
                d = os.read(fd, 4096)
            except OSError:
                return ate in buf
            if not d:
                return ate in buf
            buf += d
        if ate in buf:
            return True
    return False
if not le(30, b"$ "):
    print("COLA-FALHA: o bash não mostrou o prompt")
    raise SystemExit
bloco = b"sudo sleep 1\recho COLA-FIM-$((1+1))\r"
if b"\x1b[?2004h" in buf:
    modo = "colagem em bloco"
    os.write(fd, b"\x1b[200~" + bloco + b"\x1b[201~\r")
else:
    modo = "linhas soltas"
    os.write(fd, bloco)
print("COLA-OK" if le(30, b"COLA-FIM-2") else "COLA-FALHA: a linha depois do sudo não rodou", "(" + modo + ")")
os.write(fd, b"exit\r")
PY
)
case $colagem in COLA-OK*) ;; *) fail "colar bloco com sudo no terminal: $colagem" ;; esac
id -nG "$usuario" | tr ' ' '\n' | grep -qx wireshark || fail "$usuario fora do grupo wireshark (captura sem root)"
{ [ -n "$(getcap /usr/bin/dumpcap 2>/dev/null)" ] || [ -u /usr/bin/dumpcap ]; } || fail "dumpcap sem permissão de captura para o grupo wireshark"
# Disquete virtual (Hyper-V Geração 1): o módulo floppy fica bloqueado, sem /dev/fd0 e sem unidade na sessão.
conf_disquete=/etc/modprobe.d/nexus-os-sem-disquete.conf
[ -f "$conf_disquete" ] || fail "$conf_disquete ausente (bloqueio do módulo floppy)"
grep -qx 'blacklist floppy' "$conf_disquete" || fail "$conf_disquete sem 'blacklist floppy'"
grep -qx 'install floppy /bin/false' "$conf_disquete" || fail "$conf_disquete sem 'install floppy /bin/false'"
! lsmod | awk '$1 == "floppy" {f = 1} END {exit !f}' || fail "módulo floppy carregado"
! compgen -G '/dev/fd[0-9]*' >/dev/null || fail "/dev/fd0 existe: $(compgen -G '/dev/fd[0-9]*' | tr '\n' ' ')"
unidades=$(como_user gio mount -l 2>&1)
! grep -qiE 'floppy|disquete|fd0' <<<"$unidades" || fail "a sessão lista disquete: ${unidades//$'\n'/|}"

# LibreOffice: sem o aviso de primeira execução (WhatsNew) e sem a dica do dia, no perfil padrão do user.
perfil_lo=$casa/.config/libreoffice/4/user/registrymodifications.xcu
[ -f "$perfil_lo" ] || fail "perfil padrão do LibreOffice ausente: $perfil_lo"
[ "$(stat -c %U "$perfil_lo")" = "$usuario" ] || fail "$perfil_lo não pertence a $usuario"
for chave in '/org.openoffice.Setup/Product|WhatsNew' '/org.openoffice.Office.UI.Infobar/Enabled|WhatsNew' '/org.openoffice.Office.Common/Misc|ShowTipOfTheDay'; do
    grep -qF "<item oor:path=\"${chave%%|*}\"><prop oor:name=\"${chave##*|}\" oor:op=\"fuse\"><value>false</value></prop></item>" "$perfil_lo" \
        || fail "$perfil_lo sem ${chave##*|}=false em ${chave%%|*}"
done
echo "sistema: pt_BR, fuso America/Sao_Paulo, teclado br, máquina nexus-os, sem bloqueio de tela, programas padrão e documentação em HTML"
echo "disquete bloqueado (sem floppy, sem /dev/fd0) e LibreOffice sem aviso de primeira execução"
echo "identidade: papel de parede $papel, tema $tema, ícones $icones, janelas $janelas_tema, menu '$(px "/plugins/plugin-${wid:-0}/button-title")', nome '$nome'"

# shellcheck disable=SC2317  # chamada pelo trap
limpa() {
    command -v nexus-sdn >/dev/null && nexus-sdn down >/dev/null 2>&1
    command -v nexus-vnf >/dev/null && nexus-vnf down >/dev/null 2>&1
    command -v containerlab >/dev/null \
        && containerlab destroy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml --cleanup >/dev/null 2>&1
    como_user thunar -q >/dev/null 2>&1
    pkill -u "$usuario" -f firefox 2>/dev/null
    pkill -u "$usuario" -x xfce4-settings-manager 2>/dev/null
    pkill -u "$usuario" -x xfce4-terminal 2>/dev/null
    pkill -u "$usuario" -f /usr/bin/virt-manager 2>/dev/null
    return 0
}
trap limpa EXIT

# Atalho com janela: abre, espera uma janela que case com o padrão (regex sobre a linha do xwininfo,
# que traz título e classe) e confere que o processo segue vivo. O padrão não pode casar antes de abrir
# (o Thunar mantém janelas ocultas do daemon, que dariam falso positivo).
atalho_janela() {
    local id=$1 padrao=$2 vivo=$3 seg=$4 t=$SECONDS
    ! janelas | grep -qE "$padrao" || fail "$id: janela $padrao já existia antes de abrir"
    como_user gtk-launch "$id" || fail "gtk-launch $id falhou"
    until janelas | grep -qE "$padrao"; do
        [ $((SECONDS - t)) -lt "$espera_atalho" ] || fail "$id: nenhuma janela $padrao em ${espera_atalho} s"
        sleep 2
    done
    sleep "$seg"
    pgrep -u "$usuario" -fi "$vivo" >/dev/null || fail "$id: processo $vivo não seguiu vivo por ${seg} s"
    echo "atalho $id: janela $padrao aberta e processo vivo depois de ${seg} s"
}

# Atalho de terminal: o nexus-atalho grava o código de saída em $XDG_RUNTIME_DIR/nexus-atalho-<nome>.status.
atalho_terminal() {
    local id=$1 nome st t=$SECONDS
    nome=$(valor "$menu/$id.desktop" Exec | tr -d '"' | awk '{for (i = 1; i < NF; i++) if ($i == "nexus-atalho") {print $(i + 1); exit}}')
    [ -n "$nome" ] || fail "$id: Exec sem nexus-atalho <nome>"
    st=/run/user/$uid/nexus-atalho-$nome.status
    rm -f "$st"
    como_user gtk-launch "$id" || fail "gtk-launch $id falhou"
    until [ -s "$st" ]; do
        [ $((SECONDS - t)) -lt "$espera_atalho" ] || fail "$id: $st não apareceu em ${espera_atalho} s"
        sleep 1
    done
    [ "$(cat "$st")" = 0 ] || fail "$id: código de saída $(cat "$st") (esperado 0)"
    echo "atalho $id: executou com código 0 em $((SECONDS - t)) s"
}

atalho_janela nexus-terminal '\("xfce4-terminal"' xfce4-terminal 3
atalho_janela nexus-docs '\("(Navigator|firefox-esr)"' firefox 3
atalho_janela nexus-configuracoes '\("xfce4-settings-manager"' xfce4-settings-manager 3
atalho_janela nexus-virt-manager '\("virt-manager"' /usr/bin/virt-manager 15
atalho_terminal nexus-sdn-lab
nexus-sdn down >/dev/null 2>&1
atalho_terminal nexus-vnf-up
atalho_terminal nexus-vnf-status
atalho_terminal nexus-vnf-down
atalho_terminal nexus-clab-deploy
atalho_terminal nexus-clab-destroy

# Nada pode sobrar dos atalhos.
[ -z "$(docker ps -aq)" ] || fail "contêiner sobrou: $(docker ps -aq | tr '\n' ' ')"
! ovs-vsctl br-exists br-nexus 2>/dev/null || fail "bridge br-nexus sobrou"

echo "OK: tests/desktop.sh (login $login, sessão $sessao ativa, $processos, sem rota padrão, 10 atalhos executados)"
