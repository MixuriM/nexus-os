#!/usr/bin/env bash
# Teste da orquestração simplificada (F3.6): ciclo de vida da VNF FRR pelo nexus-vnf (up, status, down).
# Roda na VM de laboratório (sudo tests/orquestracao.sh) e dentro da ISO (nexus-smoke orquestracao).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script=$raiz/nfv/nexus-vnf.sh
topo=$raiz/labs/containerlab/vnf-frr.clab.yml
filtro=label=containerlab=vnf-frr

[ "$(id -u)" -eq 0 ] || fail "rode como root: sudo tests/orquestracao.sh"
[ -f "$script" ] || fail "script ausente: nfv/nexus-vnf.sh"
for cmd in docker containerlab; do
    command -v "$cmd" >/dev/null || fail "$cmd não instalado"
done

# Na ISO o comando é o link /usr/local/bin/nexus-vnf, criado pelo hook.
if [ -x /usr/local/bin/nexus-vnf ]; then
    vnf=(/usr/local/bin/nexus-vnf)
else
    vnf=(bash "$script")
fi

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() { containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Executa o nexus-vnf e guarda a saída em $saida e o código em $rc.
roda() {
    if saida=$("${vnf[@]}" "$@" 2>&1); then rc=0; else rc=$?; fi
}
sobrou() { [ -n "$(docker ps -aq --filter "$filtro")" ]; }

roda up
[ "$rc" -eq 0 ] || fail "up saiu com $rc: $saida"
roda status
[ "$rc" -eq 0 ] || fail "status saiu com $rc depois do up: $saida"
grep -q 'FRRouting' <<<"$saida" || fail "status não mostra a versão do FRR: $saida"
grep -q '198\.51\.100\.11/32' <<<"$saida" || fail "status não mostra o loopback 198.51.100.11/32: $saida"

roda down
[ "$rc" -eq 0 ] || fail "down saiu com $rc: $saida"
! sobrou || fail "contêiner da VNF sobrou depois do down"
roda status
[ "$rc" -eq 1 ] || fail "status depois do down devia sair com 1, saiu com $rc: $saida"

roda up
[ "$rc" -eq 0 ] || fail "up saiu com $rc: $saida"
id1=$(docker ps -aq --filter "$filtro")
roda up
[ "$rc" -eq 0 ] || fail "segundo up saiu com $rc: $saida"
[ "$(docker ps -aq --filter "$filtro")" = "$id1" ] || fail "o segundo up recriou o contêiner"

roda down
[ "$rc" -eq 0 ] || fail "down saiu com $rc: $saida"
roda down
[ "$rc" -eq 0 ] || fail "segundo down saiu com $rc: $saida"
! sobrou || fail "contêiner da VNF sobrou depois do down"
! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do down"

roda invalido
[ "$rc" -eq 2 ] || fail "uso inválido devia sair com 2, saiu com $rc"

echo "OK: tests/orquestracao.sh (up, status, down e idempotência da VNF FRR)"
