#!/usr/bin/env bash
# Cenário T5 no convidado (F4.2e, parte automática): roda os blocos "bash nexus-exec" da seção Containerlab do
# manual, na ordem, sem alterá-los, e confere a topologia frr-duo por ganchos na função sudo: depois do
# "containerlab deploy" espera, consultando a cada 1 s (limite em segundos na variável limite), a vizinhança
# OSPF Full dos dois lados e a rota do loopback do outro em cada nó, e mede o tempo desde o deploy; antes do
# "containerlab destroy" confere de novo; depois dele confere que não sobrou contêiner, rede clab nem netns.
# O tests/cenario-t5.sh troca a linha #@MANUAL@ pelos blocos do manual e a linha limite= pelo parâmetro T5_LIMITE.
# Só para a ISO: roda por "iso-smoke --extra" como o teste "t5".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in docker containerlab sudo; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done
systemctl is-active --quiet nexus-images.service || fail "nexus-images.service inativo: a imagem FRR não foi carregada"

limite=120
t5_filtro=label=containerlab=frr-duo
t5_deploy=0
t5_destroy=0

t5_vt() { docker exec "clab-frr-duo-$1" vtysh -c "$2" 2>/dev/null; }
# Vizinhança Full e rota do loopback do outro nó, nos dois lados.
t5_convergiu() {
    t5_vt r1 'show ip ospf neighbor' | grep -qE '[[:space:]]Full/' &&
        t5_vt r2 'show ip ospf neighbor' | grep -qE '[[:space:]]Full/' &&
        t5_vt r1 'show ip route ospf' | grep -q '^O>\* 198\.51\.100\.2/32' &&
        t5_vt r2 'show ip route ospf' | grep -q '^O>\* 198\.51\.100\.1/32'
}
t5_espera() {
    until t5_convergiu; do
        if [ $(($(date +%s) - t5_ini)) -ge "$limite" ]; then
            for n in r1 r2; do
                echo "--- $n: show ip ospf neighbor"; t5_vt "$n" 'show ip ospf neighbor' || true
                echo "--- $n: show ip route ospf"; t5_vt "$n" 'show ip route ospf' || true
            done
            fail "OSPF não chegou a Full com as rotas em ${limite} s"
        fi
        sleep 1
    done
}
t5_residuos() {
    [ -z "$(docker ps -aq --filter "$t5_filtro")" ] || fail "contêiner do laboratório sobrou depois do destroy"
    ! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do destroy"
    [ -z "$(ip netns list | grep clab || true)" ] || fail "netns do Containerlab sobrou depois do destroy"
}

# O manual chama "sudo ...": a função abaixo cobre só deploy e destroy e repassa o resto ao sudo de verdade.
sudo() {
    case "${1:-} ${2:-}" in
        "containerlab deploy")
            t5_ini=$(date +%s)
            t5_ini_ns=$(date +%s.%N)
            command sudo "$@" || return
            t5_deploy=1
            t5_espera
            metrica convergencia_ospf_s "$(awk -v a="$t5_ini_ns" -v b="$(date +%s.%N)" 'BEGIN { printf "%.2f", b - a }')"
            metrica limite_convergencia_s "$limite"
            ;;
        "containerlab destroy")
            t5_convergiu || fail "a adjacência OSPF Full ou as rotas sumiram antes do destroy"
            command sudo "$@" || return
            t5_residuos
            t5_destroy=1
            ;;
        *) command sudo "$@" ;;
    esac
}

#@MANUAL@

[ "$t5_deploy" -eq 1 ] || fail "o manual não executou 'containerlab deploy'"
[ "$t5_destroy" -eq 1 ] || fail "o manual não executou 'containerlab destroy'"
t5_residuos
echo "NEXUS-CENARIO-OK t5"
