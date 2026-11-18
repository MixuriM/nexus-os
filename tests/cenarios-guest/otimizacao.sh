#!/usr/bin/env bash
# Medição e diagnóstico de boot dentro da ISO (otimização da RC4, docs/otimizacao.md). Espera a sessão gráfica do
# usuário "user" e imprime linhas "NEXUS-OTIMIZACAO <chave> <valor>": sessao_s (início do último processo do desktop,
# em segundos desde o boot do kernel, como em docs/requisitos.md), plymouth_quit_s e tela_preta_s (ESTIMATIVA: sessão
# menos a saída do Plymouth) e o diagnóstico (systemd-analyze, unidades habilitadas, maiores RSS, autostarts, logs do
# LightDM e do X). Não muda nada no sistema.
# Só para a ISO: roda por "iso-smoke --extra" como o teste "otimizacao" (veja tests/medir-desempenho.sh).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
log() { echo "NEXUS-OTIMIZACAO $*"; }
# Imprime cada linha da saída de um comando com a chave na frente (a serial é lida por grep).
bloco() {
    local chave=$1
    shift
    "$@" 2>&1 | head -n "${LINHAS:-40}" | while IFS= read -r l; do log "$chave $l"; done || true
}

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"

usuario=user
processos="xfce4-session xfce4-panel xfwm4 xfdesktop"
espera=180

# Espera os quatro processos do desktop do usuário.
inicio=$SECONDS
while :; do
    pronto=1
    for p in $processos; do pgrep -u "$usuario" -x "$p" >/dev/null || pronto=0; done
    [ "$pronto" -eq 0 ] || break
    [ $((SECONDS - inicio)) -lt "$espera" ] || fail "desktop de $usuario não subiu em ${espera} s"
    sleep 1
done

# Início de cada processo: campo 22 de /proc/<pid>/stat (ticks desde o boot do kernel).
tick=$(getconf CLK_TCK)
sessao=0
for p in $processos; do
    pid=$(pgrep -u "$usuario" -x -o "$p")
    ini=$(sed -E 's/^[0-9]+ \(.*\) //' "/proc/$pid/stat" | awk '{print $20}')
    sessao=$(awk -v a="$sessao" -v b="$ini" -v t="$tick" 'BEGIN { v = b / t; print (v > a) ? v : a }')
done
log "sessao_s $sessao"

# Instantes monotônicos (µs desde o boot) das unidades que marcam a passagem do Plymouth ao X.
mono() { systemctl show -p ActiveEnterTimestampMonotonic --value "$1" 2>/dev/null || echo 0; }
for u in plymouth-start.service plymouth-quit.service plymouth-quit-wait.service lightdm.service display-manager.service \
    live-config.service nexus-images.service var-lib-docker.mount systemd-udev-settle.service graphical.target; do
    log "monotonic_us $u $(mono "$u")"
done
# O lightdm tem Conflicts=plymouth-quit.service (o quit nunca roda): o Plymouth perde a tela quando o X sobe, então o
# início da tela preta é estimado pelo lightdm.service ativo.
pq=$(mono lightdm.service)
log "plymouth_quit_s $(awk -v m="${pq:-0}" 'BEGIN { printf "%.2f", m / 1000000 }')"
log "tela_preta_s $(awk -v s="$sessao" -v m="${pq:-0}" 'BEGIN { v = s - m / 1000000; printf "%.2f", (v > 0) ? v : 0 }')"

# Linha do tempo: "segundos unidade" por instante de ativação (o critical-chain não roda com o boot em andamento,
# porque o próprio nexus-smoke ainda é um job pendente).
linha_do_tempo() {
    systemctl list-units --all --no-legend --plain | awk '{print $1}' \
        | xargs systemctl show -p Id -p ActiveEnterTimestampMonotonic -- \
        | awk -v RS= -F'\n' '{ id = ""; t = 0
            for (i = 1; i <= NF; i++) { if ($i ~ /^Id=/) id = substr($i, 4); if ($i ~ /^ActiveEnterTimestampMonotonic=/) t = substr($i, 31) }
            if (t > 0) printf "%.2f %s\n", t / 1000000, id }' | sort -n
}
LINHAS=320 bloco tempo linha_do_tempo
for u in lightdm.service plymouth-quit.service plymouth-quit-wait.service nexus-images.service nexus-smoke.service; do
    LINHAS=50 bloco "cat-$u" systemctl cat "$u" --no-pager
    LINHAS=40 bloco "dep-$u" systemctl show -p After -p Before -p Requires -p Wants -p Conflicts "$u" --no-pager
done

log "uptime_s $(cut -d' ' -f1 /proc/uptime)"
bloco analyze systemd-analyze time
LINHAS=25 bloco blame systemd-analyze blame --no-pager
LINHAS=30 bloco chain-graphical systemd-analyze critical-chain graphical.target --no-pager
LINHAS=30 bloco chain-lightdm systemd-analyze critical-chain lightdm.service --no-pager
LINHAS=300 bloco enabled systemctl list-unit-files --state=enabled --no-legend --no-pager
LINHAS=40 bloco plymouth systemctl list-units 'plymouth*' --all --no-legend --no-pager
LINHAS=30 bloco rss bash -c 'ps -eo rss,comm --sort=-rss | head -n 26'
LINHAS=60 bloco autostart ls /etc/xdg/autostart
LINHAS=5 bloco mount findmnt -no SOURCE,FSTYPE,OPTIONS /
LINHAS=5 bloco mount findmnt -no SOURCE,FSTYPE,OPTIONS /var/lib/docker
LINHAS=5 bloco free free -m
LINHAS=60 bloco lightdm journalctl -b -u lightdm --no-pager -o short-monotonic
for x in /var/log/Xorg.0.log /var/log/lightdm/x-0.log; do
    [ -f "$x" ] || continue
    LINHAS=60 bloco "xlog $x" grep -E '^\[ +[0-9.]+\]' "$x"
done
log "fim"
