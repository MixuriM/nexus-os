#!/usr/bin/env bash
# Orquestração simplificada NFVO/VNFM (F3.6): ciclo de vida da VNF FRR (vnf1) sobre o Containerlab.
# Uso: sudo nexus-vnf up|status|down
#   up      instancia a VNF (idempotente: se já existe, avisa e sai 0)
#   status  mostra o estado do contêiner, a versão do FRR e o loopback; sai 0 se rodando, 1 se não
#   down    remove a VNF e confere que nada sobrou (idempotente)
# Códigos de saída: 0 sucesso, 1 falha ou VNF ausente (status), 2 uso inválido.
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

# Na ISO o comando é o link /usr/local/bin/nexus-vnf: resolve o caminho real do script.
raiz=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
topo=$raiz/labs/containerlab/vnf-frr.clab.yml
nome=clab-vnf-frr-vnf1
filtro=label=containerlab=vnf-frr
limite=60

ajuda() { sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
vtysh() { docker exec "$nome" vtysh -c "$1" 2>/dev/null; }
existe() { [ -n "$(docker ps -aq --filter "$filtro")" ]; }
rodando() { [ "$(docker inspect -f '{{.State.Running}}' "$nome" 2>/dev/null)" = true ]; }

preparo() {
    [ "$(id -u)" -eq 0 ] || fail "rode como root: sudo nexus-vnf $1"
    [ -f "$topo" ] || fail "topologia ausente: $topo"
    for cmd in docker containerlab; do
        command -v "$cmd" >/dev/null || fail "$cmd não instalado"
    done
}

cmd_up() {
    if rodando; then
        echo "OK: VNF vnf1 já instanciada ($nome)"
        return 0
    fi
    containerlab deploy -t "$topo" >/dev/null 2>&1 || fail "containerlab deploy falhou"
    local inicio=$SECONDS
    until vtysh 'show version' >/dev/null; do
        [ $((SECONDS - inicio)) -lt "$limite" ] || fail "FRR não respondeu em ${limite} s"
        sleep 1
    done
    echo "OK: VNF vnf1 instanciada ($nome, FRR respondeu em $((SECONDS - inicio)) s)"
}

cmd_status() {
    rodando || {
        echo "FALHA: VNF vnf1 não está rodando" >&2
        return 1
    }
    echo "contêiner: $nome ($(docker inspect -f '{{.State.Status}}' "$nome"))"
    echo "versão: $(vtysh 'show version' | head -n 1)"
    echo "loopback: $(vtysh 'show running-config' | sed -n 's/^ ip address \(198\.51\.100\.[0-9]*\/32\)$/\1/p' | head -n 1)"
    echo "OK: VNF vnf1 rodando"
}

cmd_down() {
    containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || fail "containerlab destroy falhou"
    ! existe || fail "contêiner da VNF sobrou depois do destroy"
    ! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do destroy"
    echo "OK: VNF vnf1 removida"
}

case ${1:-} in
    up | status | down)
        preparo "$1"
        "cmd_$1"
        ;;
    *)
        ajuda >&2
        exit 2
        ;;
esac
