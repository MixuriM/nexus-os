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
espera_atalho=150
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
tema=$(como_user xfconf-query -c xsettings -p /Net/ThemeName)
[ "$tema" = Nexus-Dark ] || fail "tema GTK do $usuario é '$tema', esperado Nexus-Dark"
icones=$(como_user xfconf-query -c xsettings -p /Net/IconThemeName)
[ "$icones" = Nexus ] || fail "tema de ícones do $usuario é '$icones', esperado Nexus"
janelas_tema=$(como_user xfconf-query -c xfwm4 -p /general/theme)
[ "$janelas_tema" = Nexus-Dark ] || fail "tema das janelas do $usuario é '$janelas_tema', esperado Nexus-Dark"
[ -f /usr/share/icons/Nexus/scalable/places/user-home.svg ] || fail "tema de ícones Nexus ausente em /usr/share/icons"
[ -f /usr/share/themes/Nexus-Dark/gtk-3.0/gtk.css ] || fail "tema Nexus-Dark ausente em /usr/share/themes"
titulo=$(como_user xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-title)
[ "$titulo" = "Nexus OS" ] || fail "título do botão do menu é '$titulo', esperado Nexus OS"
nome=$(getent passwd "$usuario" | cut -d: -f5 | cut -d, -f1)
[ "$nome" = "Nexus OS" ] || fail "nome completo do $usuario é '$nome', esperado Nexus OS"

# Barra estilo Windows: uma barra só, embaixo, com a lista de janelas abertas e sem seletor de áreas de trabalho.
plugins=$(como_user xfconf-query -c xfce4-panel -lv | awk '$1 ~ /^\/plugins\/plugin-[0-9]+$/ {print $2}')
grep -qx tasklist <<<"$plugins" || fail "barra sem o plugin tasklist (plugins: $(tr '\n' ' ' <<<"$plugins"))"
! grep -qx pager <<<"$plugins" || fail "barra ainda tem o seletor de áreas de trabalho (pager)"
posicao=$(como_user xfconf-query -c xfce4-panel -p /panels/panel-1/position)
case $posicao in p=10\;*) ;; *) fail "barra fora da parte de baixo (position '$posicao', esperado p=10)" ;; esac
# Última coluna do xwininfo: posição absoluta (+x+y); a anterior: tamanho e posição dentro da raiz (LxA+x+y).
barra=$(janelas | grep '("xfce4-panel"' | awk '{ split($(NF - 1), g, /[x+]/); if (g[1] >= 400 && g[2] <= 80) { print $(NF - 1), $NF; exit } }')
[ -n "$barra" ] || fail "nenhuma janela xfce4-panel larga e baixa (barra inferior); janelas: $(janelas | grep -c xfce4-panel)"
[ "${barra##*+}" -ge 400 ] || fail "a barra está em cima ($barra)"
[ "$(como_user xprop -root _NET_NUMBER_OF_DESKTOPS | awk '{print $NF}')" = 1 ] || fail "há mais de uma área de trabalho"
echo "barra inferior $barra, plugins: $(tr '\n' ' ' <<<"$plugins"), 1 área de trabalho"

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
[ -f /usr/share/nexus-os/docs-html/index.html ] && [ -f /usr/share/nexus-os/docs-html/manual.html ]     || fail "documentação em HTML ausente em /usr/share/nexus-os/docs-html"
id -nG "$usuario" | tr ' ' '\n' | grep -qx wireshark || fail "$usuario fora do grupo wireshark (captura sem root)"
{ [ -n "$(getcap /usr/bin/dumpcap 2>/dev/null)" ] || [ -u /usr/bin/dumpcap ]; } || fail "dumpcap sem permissão de captura para o grupo wireshark"
echo "sistema: pt_BR, fuso America/Sao_Paulo, teclado br, máquina nexus-os, sem bloqueio de tela, programas padrão e documentação em HTML"
echo "identidade: papel de parede $papel, tema $tema, ícones $icones, janelas $janelas_tema, menu '$titulo', nome '$nome'"

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
