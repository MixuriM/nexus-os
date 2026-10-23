#!/usr/bin/env bash
# Laboratório Open vSwitch (F2.5): bridge br-nexus em modo secure, sem controlador, com dois
# namespaces (h1 e h2) ligados por pares veth. As regras vêm de sdn/flows/basico.flows.
# Uso: sudo sdn/lab-ovs.sh up|flows|down
set -euo pipefail

raiz=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
regras=$raiz/sdn/flows/basico.flows
br='br-nexus'

fail() { echo "FALHA: $*" >&2; exit 1; }

up() {
    [ -f "$regras" ] || fail "regras ausentes: $regras"
    ovs-vsctl add-br "$br" -- set bridge "$br" fail_mode=secure
    for n in 1 2; do
        ip netns add "h$n"
        ip link add "h$n-br" type veth peer name eth0 netns "h$n"
        ovs-vsctl add-port "$br" "h$n-br" -- set interface "h$n-br" ofport_request="$n"
        ip link set "h$n-br" up
        ip netns exec "h$n" ip addr add "192.0.2.$n/24" dev eth0
        ip netns exec "h$n" ip link set eth0 up
        ip netns exec "h$n" ip link set lo up
    done
    ovs-ofctl add-flows "$br" "$regras"
    echo "laboratório no ar: $br, h1 (192.0.2.1) e h2 (192.0.2.2)"
}

flows() {
    ovs-ofctl del-flows "$br"
    ovs-ofctl add-flows "$br" "$regras"
}

down() {
    ovs-vsctl --if-exists del-br "$br"
    for n in 1 2; do
        ip netns del "h$n" 2>/dev/null || true
        ip link del "h$n-br" 2>/dev/null || true
    done
    echo "laboratório removido"
}

[ "$(id -u)" -eq 0 ] || fail "rode como root: sudo sdn/lab-ovs.sh up|flows|down"
case ${1:-} in
    up) up ;;
    flows) flows ;;
    down) down ;;
    *) fail "uso: sdn/lab-ovs.sh up|flows|down" ;;
esac
