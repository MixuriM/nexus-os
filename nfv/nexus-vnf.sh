#!/usr/bin/env bash
# Orquestração simplificada NFVO/VNFM (F3.6): ciclo de vida da VNF FRR (vnf1) sobre o Containerlab.
# Uso: sudo nexus-vnf up|status|down [topologia.clab.yml]
#   up      instancia a VNF (idempotente: se já existe, avisa e sai 0)
#   status  mostra o estado do contêiner, a versão do FRR e o loopback; sai 0 se rodando, 1 se não
#   down    remove a VNF e confere que nada sobrou (idempotente)
#   Sem o arquivo de topologia vale a VNF padrão (vnf-frr). Com ele, vale o laboratório daquele arquivo
#   (todos os nós FRR dele); arquivo inexistente ou argumento a mais sai com 2.
# Códigos de saída: 0 sucesso, 1 falha ou VNF ausente (status), 2 uso inválido.
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

# Na ISO o comando é o link /usr/local/bin/nexus-vnf: resolve o caminho real do script.
raiz=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
topo=$raiz/labs/containerlab/vnf-frr.clab.yml
filtro=label=containerlab=vnf-frr
rotulo="VNF vnf1"
limite=60

ajuda() { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
vtysh() { docker exec "$1" vtysh -c "$2" 2>/dev/null; }
existe() { [ -n "$(docker ps -aq --filter "$filtro")" ]; }
nos() { docker ps -a --filter "$filtro" --format '{{.Names}}' | sort; }
# Rodando: há contêiner do laboratório e todos estão em execução.
rodando() {
    local todos em_execucao
    todos=$(docker ps -aq --filter "$filtro" | wc -l)
    em_execucao=$(docker ps -q --filter "$filtro" | wc -l)
    [ "$todos" -gt 0 ] && [ "$todos" -eq "$em_execucao" ]
}

preparo() {
    [ "$(id -u)" -eq 0 ] || fail "rode como root: sudo nexus-vnf $1"
    [ -f "$topo" ] || fail "topologia ausente: $topo"
    for cmd in docker containerlab; do
        command -v "$cmd" >/dev/null || fail "$cmd não instalado"
    done
}

cmd_up() {
    local n
    if rodando; then
        echo "OK: $rotulo já instanciada ($(nos | paste -sd, - | sed 's/,/, /g'))"
        return 0
    fi
    containerlab deploy -t "$topo" >/dev/null 2>&1 || fail "containerlab deploy falhou"
    local inicio=$SECONDS
    for n in $(nos); do
        until vtysh "$n" 'show version' >/dev/null; do
            [ $((SECONDS - inicio)) -lt "$limite" ] || fail "FRR de $n não respondeu em ${limite} s"
            sleep 1
        done
    done
    echo "OK: $rotulo instanciada ($(nos | paste -sd, - | sed 's/,/, /g'), FRR respondeu em $((SECONDS - inicio)) s)"
}

cmd_status() {
    local n
    rodando || {
        echo "FALHA: $rotulo não está rodando" >&2
        return 1
    }
    for n in $(nos); do
        echo "contêiner: $n ($(docker inspect -f '{{.State.Status}}' "$n"))"
        echo "versão: $(vtysh "$n" 'show version' | head -n 1)"
        echo "loopback: $(vtysh "$n" 'show running-config' | sed -n 's/^ ip address \(198\.51\.100\.[0-9]*\/32\)$/\1/p' | head -n 1)"
    done
    echo "OK: $rotulo rodando"
}

cmd_down() {
    containerlab destroy -t "$topo" --cleanup >/dev/null 2>&1 || fail "containerlab destroy falhou"
    ! existe || fail "contêiner da VNF sobrou depois do destroy"
    ! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do destroy"
    echo "OK: $rotulo removida"
}

case ${1:-} in
    up | status | down)
        [ $# -le 2 ] || {
            ajuda >&2
            exit 2
        }
        if [ $# -eq 2 ]; then
            [ -f "$2" ] || {
                echo "FALHA: topologia não encontrada: $2" >&2
                exit 2
            }
            topo=$(readlink -f "$2")
            lab=$(sed -n 's/^name:[[:space:]]*//p' "$topo" | head -n 1)
            [[ $lab =~ ^[A-Za-z0-9_-]+$ ]] || fail "a topologia $2 não tem a linha 'name:' com um nome simples"
            filtro=label=containerlab=$lab
            rotulo="topologia $lab"
        fi
        preparo "$1"
        "cmd_$1"
        ;;
    *)
        ajuda >&2
        exit 2
        ;;
esac
