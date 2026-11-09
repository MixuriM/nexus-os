#!/usr/bin/env bash
# Cenário T7 no convidado (F4.2f): sessão gráfica sem internet. Espera o desktop com login automático (mede o tempo
# até a sessão), cria uma VM pelo nexus-vm, abre o virt-manager pelo atalho, sobe a VNF FRR e a topologia Containerlab
# pelos atalhos e abre a documentação local. Em cada momento imprime "NEXUS-SMOKE-PONTO <nome>" e espera 5 s: nesse
# tempo o tests/iso-smoke.sh tira a captura da tela (NEXUS_SMOKE_CAPTURAS). Os atalhos rodam como o usuário "user"
# na sessão, sem NEXUS_ATALHO_TESTE: o terminal fica aberto, como na mão, e o script o fecha depois da captura.
# Só para a ISO: o tests/cenario-t7.sh o roda por "iso-smoke --extra" como o teste "t7".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }
ponto() { sleep "${T7_ANTES:-3}"; echo "NEXUS-SMOKE-PONTO $1"; sleep 5; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in virsh nexus-vm nexus-vnf containerlab docker runuser gtk-launch xwininfo getent; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done

usuario=user
processos="xfce4-session xfce4-panel xfwm4 xfdesktop"
uri=qemu:///system
vm=cen-t7
vnf=clab-vnf-frr-vnf1
lab_r1=clab-frr-duo-r1
lab_r2=clab-frr-duo-r2
virsh_() { LC_ALL=C virsh -c "$uri" "$@"; }

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
limpa() {
    pkill -u "$usuario" -x xfce4-terminal 2>/dev/null
    pkill -u "$usuario" -f /usr/bin/virt-manager 2>/dev/null
    pkill -u "$usuario" -f firefox 2>/dev/null
    nexus-vnf down >/dev/null 2>&1
    containerlab destroy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml --cleanup >/dev/null 2>&1
    virsh_ destroy "$vm" >/dev/null 2>&1
    nexus-vm remover "$vm" >/dev/null 2>&1
    return 0
}
trap 'limpa || true' EXIT

# 1. Sem internet: nenhuma rota padrão e nenhum nome resolve.
[ -z "$(ip route show default)" ] || fail "há rota padrão: o teste precisa rodar sem internet ($(ip route show default))"
if timeout 15 getent hosts example.org >/dev/null 2>&1; then fail "um nome foi resolvido: o convidado tem internet"; fi
echo "sem rota padrão e sem resolução de nomes"

# 2. Login automático: a sessão x11 do usuário fica ativa e os processos do desktop sobem.
inicio=$SECONDS
sessao=
pronto=0
while [ $((SECONDS - inicio)) -lt 180 ]; do
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
[ "$pronto" -eq 1 ] || fail "login automático: a sessão gráfica de $usuario não ficou pronta em 180 s"
# Tempo até a sessão: início do último processo do desktop, em segundos de uptime (o método de docs/requisitos.md).
hz=$(getconf CLK_TCK)
ate_sessao=0
for p in $processos; do
    t=$(awk -v hz="$hz" '{ printf "%.1f", $22 / hz }' "/proc/$(pgrep -u "$usuario" -x "$p" | head -n 1)/stat")
    ate_sessao=$(awk -v a="$ate_sessao" -v b="$t" 'BEGIN { print (b > a ? b : a) }')
done
metrica tempo_ate_sessao_s "$ate_sessao"
echo "sessão $sessao de $usuario ativa: $processos"

uid=$(id -u "$usuario")
casa=$(getent passwd "$usuario" | cut -d: -f6)
pid_sessao=$(pgrep -u "$usuario" -x xfce4-session | head -n 1)
amb() { tr '\0' '\n' <"/proc/$pid_sessao/environ" | sed -n "s/^$1=//p" | head -n 1; }
tela=$(amb DISPLAY)
xauth=$(amb XAUTHORITY)
bus=$(amb DBUS_SESSION_BUS_ADDRESS)
{ [ -n "$tela" ] && [ -n "$bus" ]; } || fail "sessão sem DISPLAY ou DBUS_SESSION_BUS_ADDRESS"
# O runner do smoke roda em C.UTF-8 (LC_ALL); as janelas abrem no idioma da sessão (LANG do xfce4-session).
lang=$(amb LANG)
como_user() {
    runuser -u "$usuario" -- env -u LC_ALL LANG="${lang:-pt_BR.UTF-8}" HOME="$casa" DISPLAY="$tela" ${xauth:+XAUTHORITY="$xauth"} \
        XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="$bus" "$@"
}
janelas() { como_user xwininfo -root -tree 2>/dev/null; }

# Atalho com janela: abre pelo gtk-launch e espera uma janela que case com o padrão (classe ou título do xwininfo).
atalho_janela() {
    local id=$1 padrao=$2 t=$SECONDS
    ! janelas | grep -qE "$padrao" || fail "$id: janela $padrao já existia antes de abrir"
    como_user gtk-launch "$id" || fail "gtk-launch $id falhou"
    until janelas | grep -qE "$padrao"; do
        [ $((SECONDS - t)) -lt 300 ] || fail "$id: nenhuma janela $padrao em 300 s"
        sleep 2
    done
    echo "atalho $id: janela $padrao aberta em $((SECONDS - t)) s"
}
# Atalho de terminal: o nexus-atalho grava o código de saída em $XDG_RUNTIME_DIR/nexus-atalho-<nome>.status e
# espera Enter (sem NEXUS_ATALHO_TESTE), então a janela fica aberta para a captura.
atalho_terminal() {
    local id=$1 nome st t=$SECONDS
    nome=$(grep -m1 '^Exec=' "/usr/share/applications/$id.desktop" | tr -d '"' | awk '{for (i = 1; i < NF; i++) if ($i == "nexus-atalho") {print $(i + 1); exit}}')
    [ -n "$nome" ] || fail "$id: Exec sem nexus-atalho <nome>"
    st=/run/user/$uid/nexus-atalho-$nome.status
    rm -f "$st"
    como_user gtk-launch "$id" || fail "gtk-launch $id falhou"
    until [ -s "$st" ]; do
        [ $((SECONDS - t)) -lt 300 ] || fail "$id: $st não apareceu em 300 s"
        sleep 1
    done
    [ "$(cat "$st")" = 0 ] || fail "$id: código de saída $(cat "$st") (esperado 0)"
    echo "atalho $id: código 0 em $((SECONDS - t)) s"
    metrica "atalho_${id}_s" "$((SECONDS - t))"
}
# Fecha o terminal do atalho com um Enter de verdade (o tests/iso-smoke.sh atende NEXUS-SMOKE-TECLA pelo monitor do
# QEMU), como a pessoa faz em "Pressione Enter para fechar...": o xfce4-terminal tem de sumir em 15 s.
teclas=0
fecha_com_enter() {
    teclas=$((teclas + 1))
    echo "NEXUS-SMOKE-TECLA $teclas ret"
    for _ in $(seq 1 15); do
        pgrep -u "$usuario" -x xfce4-terminal >/dev/null || return 0
        sleep 1
    done
    fail "o Enter não fechou o terminal do atalho: xfce4-terminal ainda aberto 15 s depois"
}
em_execucao() { [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]; }

# O xfdesktop cria _XROOTPMAP_ID ao pintar o fundo: espera até 60 s (sem a propriedade segue, e a captura decide).
for _ in $(seq 1 60); do
    como_user xprop -root _XROOTPMAP_ID 2>/dev/null | grep -q PIXMAP && break
    sleep 1
done
sleep 5
ponto desktop-pronto

# 3. A VM criada pelo nexus-vm aparece no virt-manager (atalho: virt-manager --connect qemu:///system).
nexus-vm criar "$vm" || fail "nexus-vm criar falhou"
atalho_janela nexus-virt-manager '\("virt-manager"'
sleep 15
pgrep -u "$usuario" -f 'virt-manager --connect qemu:///system' >/dev/null || fail "virt-manager não está conectado a $uri"
for _ in $(seq 1 30); do
    [ "$(virsh_ domstate "$vm" 2>/dev/null || true)" = running ] && break
    sleep 1
done
virsh_ list --name | grep -qx "$vm" || fail "a VM $vm não está em execução em $uri: o virt-manager não tem o que listar (ponto virt-manager-com-vm)"
ponto virt-manager-com-vm
pkill -u "$usuario" -f /usr/bin/virt-manager || true
sleep 2

# 4. VNF FRR pelo atalho.
atalho_terminal nexus-vnf-up
em_execucao "$vnf" || fail "contêiner $vnf não está em execução depois do atalho nexus-vnf-up"
ponto vnf-acima
fecha_com_enter
atalho_terminal nexus-vnf-down
fecha_com_enter
[ -z "$(docker ps -aq)" ] || fail "contêiner sobrou depois do atalho nexus-vnf-down: $(docker ps -aq | tr '\n' ' ')"

# 5. Topologia Containerlab pelo atalho.
atalho_terminal nexus-clab-deploy
{ em_execucao "$lab_r1" && em_execucao "$lab_r2"; } || fail "contêineres $lab_r1 e $lab_r2 não estão em execução depois do atalho nexus-clab-deploy"
ponto clab-acima
fecha_com_enter
atalho_terminal nexus-clab-destroy
fecha_com_enter
[ -z "$(docker ps -aq)" ] || fail "contêiner sobrou depois do atalho nexus-clab-destroy: $(docker ps -aq | tr '\n' ' ')"

# 6. Documentação local no navegador, sem internet: a janela do Firefox ganha o título da página (| Nexus OS).
atalho_janela nexus-docs '"[^"]*Nexus OS[^"]*": \("(Navigator|firefox-esr)"'
sleep 5
ponto docs-abertos

# 7. Limpeza e conferência: nada sobra.
limpa || true
sleep 3
[ -z "$(docker ps -aq)" ] || fail "contêiner sobrou: $(docker ps -aq | tr '\n' ' ')"
! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou"
! virsh_ list --all --name | grep -qx "$vm" || fail "a VM $vm sobrou depois do nexus-vm remover"
echo "limpeza: sem contêiner, rede clab nem VM"

echo "NEXUS-CENARIO-OK t7"
