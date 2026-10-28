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
espera_atalho=90
menu=/usr/share/applications
atalhos="nexus-terminal nexus-virt-manager nexus-docs nexus-sdn-lab nexus-vnf-up nexus-vnf-status nexus-vnf-down nexus-clab-deploy nexus-clab-destroy"

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
            xfce4-terminal | virt-manager | thunar | nexus-atalho | nexus-sdn | nexus-vnf | containerlab | sudo)
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
# Atalhos da área de trabalho: executáveis e marcados como confiáveis (bit x mais checksum do xfdesktop).
for a in $atalhos; do
    d=$casa/Desktop/$a.desktop
    [ -x "$d" ] || fail "atalho da área de trabalho ausente ou sem bit de execução: $d"
    soma=$(sha256sum <"$d" | cut -d' ' -f1)
    lida=$(como_user gio info -a metadata::xfce-exe-checksum "$d" | sed -n 's/^ *metadata::xfce-exe-checksum: //p')
    [ "$lida" = "$soma" ] || fail "$d sem metadata::xfce-exe-checksum válido (lido: '${lida:-vazio}')"
done
echo "área de trabalho: 9 atalhos executáveis e confiáveis"
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
[ "$tema" = Greybird ] || fail "tema GTK do $usuario é '$tema', esperado Greybird"
titulo=$(como_user xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-title)
[ "$titulo" = "Nexus OS" ] || fail "título do botão do menu é '$titulo', esperado Nexus OS"
nome=$(getent passwd "$usuario" | cut -d: -f5 | cut -d, -f1)
[ "$nome" = "Nexus OS" ] || fail "nome completo do $usuario é '$nome', esperado Nexus OS"
echo "identidade: papel de parede $papel, tema $tema, menu '$titulo', nome '$nome'"

# shellcheck disable=SC2317  # chamada pelo trap
limpa() {
    command -v nexus-sdn >/dev/null && nexus-sdn down >/dev/null 2>&1
    command -v nexus-vnf >/dev/null && nexus-vnf down >/dev/null 2>&1
    command -v containerlab >/dev/null \
        && containerlab destroy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml --cleanup >/dev/null 2>&1
    como_user thunar -q >/dev/null 2>&1
    pkill -u "$usuario" -x xfce4-terminal 2>/dev/null
    pkill -u "$usuario" -f /usr/bin/virt-manager 2>/dev/null
    return 0
}
trap limpa EXIT

janelas() { como_user xwininfo -root -tree 2>/dev/null; }

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
atalho_janela nexus-docs '"docs - Thunar"' thunar 3
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

echo "OK: tests/desktop.sh (login $login, sessão $sessao ativa, $processos, sem rota padrão, 9 atalhos executados)"
