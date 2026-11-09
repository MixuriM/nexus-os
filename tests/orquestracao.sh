#!/usr/bin/env bash
# Teste da orquestração simplificada (F3.6): ciclo de vida da VNF FRR pelo nexus-vnf (up, status, down).
# Roda na VM de laboratório (sudo tests/orquestracao.sh) e dentro da ISO (nexus-smoke orquestracao).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script=$raiz/nfv/nexus-vnf.sh
topo=$raiz/labs/containerlab/vnf-frr.clab.yml
filtro=label=containerlab=vnf-frr
duo=$raiz/labs/containerlab/frr-duo.clab.yml
filtro_duo=label=containerlab=frr-duo

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
cleanup() {
    containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || true
    containerlab destroy -t "$duo" --cleanup >/dev/null 2>&1 || true
}
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

# Topologia opcional (F4.3): arquivo inexistente e argumento a mais saem com 2; a topologia padrão passada
# por extenso se comporta como sem argumento; com a frr-duo o ciclo vale para os dois nós.
roda up /nao/existe.clab.yml
[ "$rc" -eq 2 ] || fail "topologia inexistente devia sair com 2, saiu com $rc: $saida"
grep -q 'topologia não encontrada' <<<"$saida" || fail "a saída não explica a topologia inexistente: $saida"
sobrou && fail "up com topologia inexistente subiu a VNF padrão"
roda up "$topo" extra
[ "$rc" -eq 2 ] || fail "argumento a mais devia sair com 2, saiu com $rc: $saida"

roda up "$topo"
[ "$rc" -eq 0 ] || fail "up com a topologia padrão por extenso saiu com $rc: $saida"
roda status "$topo"
[ "$rc" -eq 0 ] || fail "status com a topologia padrão por extenso saiu com $rc: $saida"
grep -q '198\.51\.100\.11/32' <<<"$saida" || fail "status com a topologia padrão não mostra o loopback: $saida"
roda down "$topo"
[ "$rc" -eq 0 ] || fail "down com a topologia padrão por extenso saiu com $rc: $saida"

roda up "$duo"
[ "$rc" -eq 0 ] || fail "up da frr-duo saiu com $rc: $saida"
roda status "$duo"
[ "$rc" -eq 0 ] || fail "status da frr-duo saiu com $rc: $saida"
for t in clab-frr-duo-r1 clab-frr-duo-r2 '198\.51\.100\.1/32' '198\.51\.100\.2/32'; do
    grep -q "$t" <<<"$saida" || fail "status da frr-duo não mostra $t: $saida"
done
[ -z "$(docker ps -aq --filter "$filtro")" ] || fail "a VNF padrão apareceu junto com a frr-duo"
ids2=$(docker ps -aq --filter "$filtro_duo")
roda up "$duo"
[ "$rc" -eq 0 ] || fail "segundo up da frr-duo saiu com $rc: $saida"
[ "$(docker ps -aq --filter "$filtro_duo")" = "$ids2" ] || fail "o segundo up da frr-duo recriou os contêineres"
roda down "$duo"
[ "$rc" -eq 0 ] || fail "down da frr-duo saiu com $rc: $saida"
[ -z "$(docker ps -aq --filter "$filtro_duo")" ] || fail "contêiner da frr-duo sobrou depois do down"
! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do down da frr-duo"
roda status "$duo"
[ "$rc" -eq 1 ] || fail "status da frr-duo depois do down devia sair com 1, saiu com $rc: $saida"

echo "OK: tests/orquestracao.sh (up, status, down e idempotência da VNF FRR, com topologia opcional)"
