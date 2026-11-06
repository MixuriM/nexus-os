#!/usr/bin/env bash
# Cenário T2 no convidado (F4.2b): ponte Open vSwitch sem controlador, 3 portas ligadas a 3 namespaces (A, B, C)
# e regras OpenFlow escritas à mão. A para B passa; A para C é descartado por regra explícita (prioridade 300,
# acima da permissão de prioridade 50); sem a regra de descarte A para C passa; recolocada, falha de novo.
# Só para a ISO: o tests/cenario-t2.sh o roda por "iso-smoke --extra" como o teste "t2".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in ovs-vsctl ovs-ofctl ip ping; do
    command -v "$cmd" >/dev/null || fail "$cmd não instalado"
done

br="br-cen"
ip_a=192.0.2.1
ip_b=192.0.2.2
ip_c=192.0.2.3

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    ovs-vsctl --if-exists del-br "$br" >/dev/null 2>&1 || true
    for h in a b c; do
        ip netns del "cen-$h" 2>/dev/null || true
        ip link del "c$h-br" 2>/dev/null || true
    done
}
trap cleanup EXIT
cleanup

ovs-vsctl add-br "$br" -- set bridge "$br" fail_mode=secure
porta=1
for h in a b c; do
    ip netns add "cen-$h"
    ip link add "c$h-br" type veth peer name eth0 netns "cen-$h"
    ovs-vsctl add-port "$br" "c$h-br" -- set interface "c$h-br" ofport_request="$porta"
    ip link set "c$h-br" up
    ip netns exec "cen-$h" ip addr add "192.0.2.$porta/24" dev eth0
    ip netns exec "cen-$h" ip link set eth0 up
    ip netns exec "cen-$h" ip link set lo up
    porta=$((porta + 1))
done

# Premissas: modo secure e nenhum controlador.
[ "$(ovs-vsctl get-fail-mode "$br")" = secure ] || fail "fail-mode de $br não é secure"
[ -z "$(ovs-vsctl get-controller "$br")" ] || fail "$br tem controlador configurado"
echo "ponte $br: fail-mode secure, sem controlador"

regra() {
    ovs-ofctl add-flow "$br" "$1"
    echo "regra: $1"
}
regra_descarte() {
    regra "priority=300,ip,in_port=1,nw_dst=$ip_c,actions=drop"
}
# Regras escritas à mão: ARP em toda a ponte; IP de A para B e de B para A (prioridade 100); IP de A para C
# permitido por uma regra de prioridade 50, que o descarte explícito de prioridade 300 sobrepõe.
regra "priority=100,arp,actions=normal"
regra "priority=100,ip,in_port=1,nw_dst=$ip_b,actions=output:2"
regra "priority=100,ip,in_port=2,nw_dst=$ip_a,actions=output:1"
regra "priority=50,ip,in_port=1,nw_dst=$ip_c,actions=output:3"
regra "priority=50,ip,in_port=3,nw_dst=$ip_a,actions=output:1"
regra_descarte
[ "$(ovs-ofctl dump-flows "$br" | grep -c 'priority=')" -eq 6 ] || fail "dump-flows não mostra as 6 regras"

ping_de_a() { ip netns exec cen-a ping -c 3 -W 2 "$1" >/dev/null 2>&1; }
# Contador n_packets da regra cuja linha do dump-flows contém os dois trechos.
pacotes() {
    ovs-ofctl dump-flows "$br" |
        awk -v a="$1" -v b="$2" 'index($0, a) && index($0, b) { match($0, /n_packets=[0-9]+/); print substr($0, RSTART + 10, RLENGTH - 10); exit }'
}

ping_de_a "$ip_b" || fail "ping de A para B falhou com as regras de permissão"
echo "ping A para B: passou"
if ping_de_a "$ip_c"; then fail "ping de A para C passou, mas a regra de descarte devia bloqueá-lo"; fi
echo "ping A para C: falhou, como esperado"
sleep 2
permite=$(pacotes 'priority=100,' "nw_dst=$ip_b")
descarta=$(pacotes 'priority=300,' "nw_dst=$ip_c")
[ "${permite:-0}" -gt 0 ] || fail "a regra de permissão A para B não contou pacotes (n_packets=${permite:-0})"
[ "${descarta:-0}" -gt 0 ] || fail "a regra de descarte A para C não contou pacotes (n_packets=${descarta:-0})"
echo "contadores: permissão A para B n_packets=$permite, descarte A para C n_packets=$descarta"

# Sem a regra de descarte, a permissão de prioridade 50 deixa A alcançar C.
ovs-ofctl --strict del-flows "$br" "priority=300,ip,in_port=1,nw_dst=$ip_c"
echo "regra de descarte removida"
ping_de_a "$ip_c" || fail "ping de A para C falhou sem a regra de descarte"
echo "ping A para C sem o descarte: passou"

regra_descarte
if ping_de_a "$ip_c"; then fail "ping de A para C passou com a regra de descarte recolocada"; fi
echo "ping A para C com o descarte recolocado: falhou, como esperado"

sleep 2
echo "--- dump-flows final"
ovs-ofctl dump-flows "$br"
metrica pacotes_permissao_a_b "$(pacotes 'priority=100,' "nw_dst=$ip_b")"
metrica pacotes_permissao_a_c_prioridade_50 "$(pacotes 'priority=50,' "in_port=1")"
metrica pacotes_descarte_a_c "$(pacotes 'priority=300,' "nw_dst=$ip_c")"

echo "NEXUS-CENARIO-OK t2"
