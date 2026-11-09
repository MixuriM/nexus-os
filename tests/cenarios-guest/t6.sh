#!/usr/bin/env bash
# Cenário T6 no convidado (F4.3): ponte Open vSwitch br-integrado (modo secure, sem controlador) com as regras
# OpenFlow de sdn/flows/integrado.flows, r1 e r2 do Containerlab ligados a ela, subida pelo nexus-vnf. Confere:
# up e status (0); OSPF Full dos dois lados e a rota do loopback do outro em até "limite" segundos; ping entre
# os loopbacks; n_packets maior que zero em todas as regras e nas duas do protocolo 89; PROVA DE CONTROLE: a
# regra de descarte do protocolo 89 derruba a adjacência e as rotas (limite: 3 vezes o dead interval da
# configuração) e, removida, tudo volta (limite: 30 s); down (0) sem contêiner, rede clab, porta nem ponte.
# O tests/cenario-t6.sh troca a linha #@PAYLOAD@ pelos arquivos do repositório (a RC2 ainda não os traz) e a
# linha limite= pelo parâmetro T6_LIMITE. Só para a ISO: roda por "iso-smoke --extra" como o teste "t6".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in docker containerlab ovs-vsctl ovs-ofctl base64 tar; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done
systemctl is-active --quiet nexus-images.service || fail "nexus-images.service inativo: a imagem FRR não foi carregada"
systemctl is-active --quiet openvswitch-switch.service || fail "openvswitch-switch.service inativo"

limite=120
limite_recup=30
t6dir=/run/nexus-t6
#@PAYLOAD@

br="br-integrado"
topo=$t6dir/labs/containerlab/integrado.clab.yml
flows=$t6dir/sdn/flows/integrado.flows
vnf=(bash "$t6dir/nfv/nexus-vnf.sh")
filtro=label=containerlab=integrado
descarte='priority=200,ip,nw_proto=89,actions=drop'
dead=$(sed -n 's/^ ip ospf dead-interval \([0-9]*\)$/\1/p' "$t6dir/labs/containerlab/configs/int-r1/frr.conf")
[[ $dead =~ ^[0-9]+$ ]] || fail "dead-interval não encontrado em configs/int-r1/frr.conf"
limite_queda=$((dead * 3))

agora() { date +%s.%N; }
dif() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.2f", b - a }'; }
vt() { docker exec "clab-integrado-$1" vtysh -c "$2" 2>/dev/null || true; }
full() { [[ $(vt "$1" 'show ip ospf neighbor') =~ [[:space:]]Full/ ]]; }
rota() { [[ $(vt "$1" 'show ip route ospf') == *"O>* $2/32"* ]]; }
convergiu() { full r1 && full r2 && rota r1 198.51.100.22 && rota r2 198.51.100.21; }
caiu() { ! full r1 && ! full r2 && ! rota r1 198.51.100.22 && ! rota r2 198.51.100.21; }
# espera <função> <limite em s> <mensagem> [início]: consulta a cada 1 s; o tempo decorrido fica em $espera_s.
espera() {
    local lim=$2 ini=${4:-$(agora)} s=$SECONDS
    until "$1"; do
        if [ $((SECONDS - s)) -ge "$lim" ]; then
            for n in r1 r2; do
                echo "--- $n: show ip ospf neighbor"; vt "$n" 'show ip ospf neighbor'
                echo "--- $n: show ip route ospf"; vt "$n" 'show ip route ospf'
            done
            ovs-ofctl dump-flows "$br" || true
            fail "$3 em ${lim} s"
        fi
        sleep 1
    done
    espera_s=$(dif "$ini" "$(agora)")
}
# n_packets maior que zero em toda regra do arquivo de regras e nas duas do protocolo 89.
confere_contadores() {
    local esperadas dump n ospf=0 l
    esperadas=$(grep -cvE '^[[:space:]]*(#|$)' "$flows")
    dump=$(ovs-ofctl dump-flows "$br" | grep 'n_packets=')
    echo "$dump"
    [ "$(wc -l <<<"$dump")" -eq "$esperadas" ] || fail "a ponte tem $(wc -l <<<"$dump") regra(s), esperado $esperadas"
    while IFS= read -r l; do
        n=$(sed -n 's/.*n_packets=\([0-9]*\),.*/\1/p' <<<"$l")
        [ "${n:-0}" -gt 0 ] || fail "regra sem pacotes: $l"
        [[ $l == *nw_proto=89* ]] && ospf=$((ospf + 1))
    done <<<"$dump"
    [ "$ospf" -eq 2 ] || fail "esperava 2 regras do protocolo 89 com pacotes, achei $ospf"
}
desfaz_ponte() { ovs-vsctl --if-exists del-br "$br"; }
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    "${vnf[@]}" down "$topo" >/dev/null 2>&1 || true
    desfaz_ponte >/dev/null 2>&1 || true
}
trap cleanup EXIT

inicio=$(agora)
! ovs-vsctl br-exists "$br" || fail "a ponte $br já existe antes do cenário"
[ -z "$(docker ps -aq --filter "$filtro")" ] || fail "já existe contêiner do laboratório integrado"

# A ponte é criada pelo cenário (o Containerlab não cria bridge); sem controlador, tudo é descartado até as regras.
ovs-vsctl add-br "$br" -- set bridge "$br" fail_mode=secure
[ -z "$(ovs-vsctl get-controller "$br")" ] || fail "a ponte $br tem controlador"
t0=$(agora)
"${vnf[@]}" up "$topo" || fail "nexus-vnf up da topologia integrada falhou"
metrica up_s "$(dif "$t0" "$(agora)")"
"${vnf[@]}" status "$topo" || fail "nexus-vnf status da topologia integrada falhou"
ovs-ofctl add-flows "$br" "$flows" || fail "ovs-ofctl add-flows falhou"
ovs-vsctl list-ports "$br" | sort | paste -sd' ' - | grep -qx 'ovsp1 ovsp2' || fail "a ponte não tem exatamente as portas ovsp1 e ovsp2"

espera convergiu "$limite" "OSPF não chegou a Full com as rotas" "$t0"
metrica convergencia_inicial_s "$espera_s"
metrica limite_convergencia_s "$limite"
docker exec clab-integrado-r1 ping -c 3 -W 2 -I 198.51.100.21 198.51.100.22 >/dev/null || fail "ping de r1 para o loopback de r2 falhou"
docker exec clab-integrado-r2 ping -c 3 -W 2 -I 198.51.100.22 198.51.100.21 >/dev/null || fail "ping de r2 para o loopback de r1 falhou"
echo "--- regras com contadores"
confere_contadores

# Prova de controle: a regra de descarte do protocolo 89 manda mais que a de permissão.
echo "--- prova de controle: descartar o protocolo 89"
t1=$(agora)
ovs-ofctl add-flow "$br" "$descarte"
espera caiu "$limite_queda" "a adjacência OSPF e as rotas não caíram com o descarte do protocolo 89" "$t1"
metrica queda_s "$espera_s"
metrica limite_queda_s "$limite_queda"
ovs-ofctl dump-flows "$br" | grep 'actions=drop' | grep -vq 'n_packets=0,' || fail "a regra de descarte não contou pacotes"
t2=$(agora)
ovs-ofctl --strict del-flows "$br" 'priority=200,ip,nw_proto=89'
espera convergiu "$limite_recup" "OSPF não voltou a Full com as rotas depois de remover o descarte" "$t2"
metrica recuperacao_s "$espera_s"
metrica limite_recuperacao_s "$limite_recup"

# Remoção: nexus-vnf down e nada sobra, nem a ponte criada pelo cenário.
echo "--- remoção"
t3=$(agora)
"${vnf[@]}" down "$topo" || fail "nexus-vnf down da topologia integrada falhou"
metrica down_s "$(dif "$t3" "$(agora)")"
[ -z "$(docker ps -aq --filter "$filtro")" ] || fail "contêiner do laboratório sobrou depois do down"
! docker network inspect clab >/dev/null 2>&1 || fail "rede clab sobrou depois do down"
[ -z "$(ovs-vsctl list-ports "$br")" ] || fail "porta da ponte sobrou depois do down: $(ovs-vsctl list-ports "$br")"
desfaz_ponte
! ovs-vsctl br-exists "$br" || fail "a ponte $br sobrou depois do cenário"
[ -z "$(ip netns list | grep clab || true)" ] || fail "netns do Containerlab sobrou depois do down"
metrica tempo_guest_s "$(dif "$inicio" "$(agora)")"

echo "NEXUS-CENARIO-OK t6"
