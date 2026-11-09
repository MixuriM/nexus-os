#!/usr/bin/env bash
# Cenário T3 no convidado (F4.2c): ciclo de vida da VNF FRR pelo nexus-vnf, 3 ciclos seguidos, com a imagem
# carregada offline pelo nexus-images.service. Por ciclo: up (0, contêiner rodando), up repetido (0, mesmo
# contêiner, nenhum segundo), status (0, com o loopback 198.51.100.11/32), down (0, sem contêiner nem rede
# clab), down repetido (0) e status depois do down (1, o código documentado em nfv/nexus-vnf.sh). No fim, o uso
# inválido sai com 2. Só para a ISO: o tests/cenario-t3.sh o roda por "iso-smoke --extra" como o teste "t3".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in docker containerlab nexus-vnf; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done
systemctl is-active --quiet nexus-images.service || fail "nexus-images.service inativo: a imagem FRR não foi carregada"

nome=clab-vnf-frr-vnf1
filtro=label=containerlab=vnf-frr
loopback=198.51.100.11/32

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() { nexus-vnf down >/dev/null 2>&1 || true; }
trap cleanup EXIT

# roda <args>: executa o nexus-vnf; a saída fica em $saida e o código em $rc.
roda() {
    if saida=$(nexus-vnf "$@" 2>&1); then rc=0; else rc=$?; fi
}
agora() { date +%s.%N; }
dif() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.2f", b - a }'; }
ids() { docker ps -aq --filter "$filtro"; }
# Nada da VNF sobra: nem contêiner do laboratório, nem a rede clab.
limpo() {
    [ -z "$(ids)" ] || fail "contêiner da VNF sobrou depois do down (ciclo $1)"
    ! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do down (ciclo $1)"
}

limpo 0
for i in 1 2 3; do
    echo "--- ciclo $i"
    t0=$(agora)
    roda up
    t1=$(agora)
    [ "$rc" -eq 0 ] || fail "up saiu com $rc (ciclo $i): $saida"
    [ "$(docker inspect -f '{{.State.Running}}' "$nome" 2>/dev/null)" = true ] || fail "contêiner $nome não está em execução depois do up (ciclo $i)"
    metrica "up_s_ciclo$i" "$(dif "$t0" "$t1")"
    id1=$(ids)

    roda up
    [ "$rc" -eq 0 ] || fail "segundo up saiu com $rc (ciclo $i): $saida"
    [ "$(ids)" = "$id1" ] || fail "o segundo up criou ou recriou contêiner (ciclo $i)"

    roda status
    [ "$rc" -eq 0 ] || fail "status saiu com $rc depois do up (ciclo $i): $saida"
    grep -qF "loopback: $loopback" <<<"$saida" || fail "status não informa o loopback $loopback (ciclo $i): $saida"

    t0=$(agora)
    roda down
    t1=$(agora)
    [ "$rc" -eq 0 ] || fail "down saiu com $rc (ciclo $i): $saida"
    limpo "$i"
    metrica "down_s_ciclo$i" "$(dif "$t0" "$t1")"

    roda down
    [ "$rc" -eq 0 ] || fail "segundo down saiu com $rc (ciclo $i): $saida"
    limpo "$i"

    roda status
    [ "$rc" -eq 1 ] || fail "status depois do down devia sair com 1, saiu com $rc (ciclo $i): $saida"
    echo "ciclo $i: up, up repetido, status, down, down repetido e status ausente ok"
done

roda invalido
[ "$rc" -eq 2 ] || fail "uso inválido devia sair com 2, saiu com $rc"
metrica ciclos_ok 3

echo "NEXUS-CENARIO-OK t3"
