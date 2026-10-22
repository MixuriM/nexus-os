#!/usr/bin/env bash
# Teste NFV (F2.7): implanta labs/containerlab/frr-duo.clab.yml (dois nós FRR, OSPF área 0),
# espera até 90 s pela convergência e confere que cada nó aprendeu o loopback do outro via OSPF.
# Uso: sudo tests/nfv.sh
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
topo=$raiz/labs/containerlab/frr-duo.clab.yml
limite=90

[ "$(id -u)" -eq 0 ] || fail "rode como root: sudo tests/nfv.sh"
[ -f "$topo" ] || fail "topologia ausente: labs/containerlab/frr-duo.clab.yml"
for cmd in docker containerlab; do
    command -v "$cmd" >/dev/null || fail "$cmd não instalado"
done

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() { containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || true; }
trap cleanup EXIT

rota() { docker exec "clab-frr-duo-$1" vtysh -c 'show ip route ospf' 2>/dev/null; }

containerlab deploy -t "$topo" >/dev/null 2>&1 || fail "containerlab deploy falhou"

# r1 precisa aprender o loopback de r2 e vice-versa.
inicio=$SECONDS
until rota r1 | grep -q '^O>\* 198\.51\.100\.2/32' && rota r2 | grep -q '^O>\* 198\.51\.100\.1/32'; do
    [ $((SECONDS - inicio)) -lt "$limite" ] || {
        echo "--- r1" >&2; rota r1 >&2 || true
        echo "--- r2" >&2; rota r2 >&2 || true
        fail "OSPF não convergiu em ${limite} s"
    }
    sleep 3
done
tempo=$((SECONDS - inicio))

echo "--- r1: show ip route ospf"; rota r1
echo "--- r2: show ip route ospf"; rota r2

containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || fail "containerlab destroy falhou"
[ -z "$(docker ps -aq --filter label=containerlab=frr-duo)" ] || fail "container do laboratório sobrou"

echo "OK: tests/nfv.sh (r1 e r2 trocaram os loopbacks por OSPF em ${tempo} s)"
