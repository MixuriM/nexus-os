#!/usr/bin/env bash
# Demonstração guiada de virtualização de redes do Nexus OS (RC3). Só roda dentro da ISO (boot=live).
# Na ISO, o link /usr/local/bin/nexus-demo aponta para este script; a entrada "modo de demonstração" do menu de boot
# abre um terminal com ele. Cada ato reutiliza os comandos reais do projeto e mostra cada um antes de executá-lo.
# Uso: nexus-demo [ato] [--auto]
#   sem ato   menu numerado
#   sdn       rede programada por regras (Open vSwitch)
#   vnf       um roteador FRR como contêiner (nexus-vnf)
#   rede      rede integrada: ponte virtual, dois roteadores em OSPF, falha e recuperação
#   vm        máquina virtual com libvirt (nexus-vm), sem iniciar sistema operacional dentro dela
#   tudo      sdn, vnf, rede e vm, nessa ordem
#   limpar    remove tudo o que a demonstração pode ter deixado
#   ajuda     mostra este texto
#   --auto    sem pausas e sem perguntas, com uma linha NEXUS-DEMO-ATO <nome> OK <segundos> por ato (usado nos testes)
# Códigos de saída: 0 sucesso, 1 falha, 2 uso inválido ou fora da ISO. Variável só para teste: NEXUS_CMDLINE.
set -euo pipefail

AUTO=0
ATO=
ATO_T0=0
LIMITE_IMAGEM=90
LIMITE_CONVERGE=120
LIMITE_VOLTA=30
BR_SDN=br-nexus
BR_INT=br-integrado
VM=demo-vm
CRIOU=" "

ajuda() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
uso() { ajuda >&2; exit 2; }

# ---------- cores (só em terminal) ----------
B='' C='' V='' A='' Z=''
if [ -t 1 ] && command -v tput >/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    B=$(tput bold) C=$(tput setaf 6) V=$(tput setaf 2) A=$(tput setaf 3) Z=$(tput sgr0)
fi

# ---------- saída ----------
titulo() { printf '\n%s== %s ==%s\n' "$B$C" "$1" "$Z"; }
explica() { printf '%sO QUE VAI ACONTECER%s\n%s\n\n' "$B" "$Z" "$1"; }
mostra() { printf '\n%sO QUE ISSO MOSTRA%s\n%s\n' "$B" "$Z" "$1"; }
aviso() { printf '%s%s%s\n' "$A" "$1" "$Z"; }
ok() { printf '%s%s%s\n' "$V" "$1" "$Z"; }
pausa() {
    [ "$AUTO" = 1 ] && return 0
    printf '\n%sAperte Enter para continuar%s ' "$B" "$Z"
    read -r _ || true
}
# exe "<comando>": mostra o comando real e o executa.
exe() {
    printf '%s$ %s%s\n' "$C" "$1" "$Z"
    bash -c "$1"
}
# exe_falha "<comando>": o comando deve falhar (é a prova de que a regra funcionou).
exe_falha() {
    printf '%s$ %s%s\n' "$C" "$1" "$Z"
    if bash -c "$1"; then
        falha "o comando deveria ter falhado e funcionou: $1"
    fi
    ok "(falhou, como esperado)"
}
falha() {
    printf '%sFALHA: %s%s\n' "$A" "$1" "$Z" >&2
    exit 1
}
# espera <função> <limite em s> <mensagem>: consulta a cada 1 s; nunca laço infinito.
espera() {
    local ini=$SECONDS
    until "$1" >/dev/null 2>&1; do
        [ $((SECONDS - ini)) -lt "$2" ] || falha "$3 (esperei $2 s)"
        sleep 1
    done
}

# ---------- limpeza ----------
criou() { CRIOU="$CRIOU$1 "; }
desfez() { CRIOU=${CRIOU/ $1 / }; }
# Desfaz o que existir; nunca falha se nada existe.
limpa_sdn() { nexus-sdn down >/dev/null 2>&1 || true; }
limpa_lab() { # limpa_lab <nome do laboratório> <topologia>
    local ids
    ids=$(docker ps -aq --filter "label=containerlab=$1" 2>/dev/null || true)
    if [ -n "$ids" ]; then
        # shellcheck disable=SC2086  # $ids tem um identificador por palavra
        containerlab destroy -t "$2" --cleanup >/dev/null 2>&1 || docker rm -f $ids >/dev/null 2>&1 || true
    fi
    if [ -z "$(docker ps -aq --filter label=containerlab 2>/dev/null || true)" ]; then
        docker network rm clab >/dev/null 2>&1 || true
    fi
}
limpa_vnf() { limpa_lab vnf-frr "$RAIZ/labs/containerlab/vnf-frr.clab.yml"; }
limpa_rede() {
    limpa_lab integrado "$RAIZ/labs/containerlab/integrado.clab.yml"
    ovs-vsctl --if-exists del-br "$BR_INT" >/dev/null 2>&1 || true
}
limpa_vm() {
    if virsh -c qemu:///system list --all --name 2>/dev/null | grep -qx -- "$VM"; then
        virsh -c qemu:///system destroy "$VM" >/dev/null 2>&1 || true
        virsh -c qemu:///system undefine "$VM" >/dev/null 2>&1 || true
    fi
}
limpar() {
    limpa_sdn
    limpa_vnf
    limpa_lab frr-duo "$RAIZ/labs/containerlab/frr-duo.clab.yml"
    limpa_rede
    limpa_vm
}
# EXIT, INT e TERM: desfaz só o que ESTA execução criou e ainda não desfez.
sair() {
    local rc=$?
    trap - EXIT
    case $CRIOU in *" sdn "*) limpa_sdn ;; esac
    case $CRIOU in *" vnf "*) limpa_vnf ;; esac
    case $CRIOU in *" rede "*) limpa_rede ;; esac
    case $CRIOU in *" vm "*) limpa_vm ;; esac
    if [ "$rc" -ne 0 ] && [ -n "$ATO" ] && [ "$AUTO" = 1 ]; then
        echo "NEXUS-DEMO-ATO $ATO FALHA $((SECONDS - ATO_T0))"
    fi
    exit "$rc"
}

ato_inicio() { ATO=$1; ATO_T0=$SECONDS; titulo "$2"; }
ato_fim() {
    [ "$AUTO" != 1 ] || echo "NEXUS-DEMO-ATO $ATO OK $((SECONDS - ATO_T0))"
    ATO=
}

# ---------- verificações ----------
precisa() {
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null || falha "$c não encontrado: este ato precisa dele"
    done
}
imagem_pronta() { systemctl is-active --quiet nexus-images.service; }
espera_imagem() {
    if ! imagem_pronta; then
        aviso "carregando a imagem do roteador (pode levar alguns segundos)..."
        espera imagem_pronta "$LIMITE_IMAGEM" "a imagem do roteador não ficou pronta (nexus-images.service)"
    fi
}
aviso_memoria() {
    local mib
    mib=$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)
    if [ "$mib" -lt 2300 ]; then
        aviso "Atenção: esta máquina tem $mib MiB de memória. A demonstração recomenda 2560 MiB; com menos, o ato 'rede' pode falhar."
    fi
}

# ---------- ato sdn ----------
ping_h1() { ip netns exec h1 ping -c 1 -W 1 192.0.2.2; }
ato_sdn() {
    ato_inicio sdn "Ato 1: rede programada por regras (SDN)"
    explica "Vamos criar um switch virtual (Open vSwitch) com dois computadores de mentira, h1 e h2.
O switch só deixa passar o que as regras permitem. Depois vamos mudar as regras e ver a rede reagir."
    precisa ovs-vsctl ovs-ofctl nexus-sdn ip
    limpa_sdn
    exe "nexus-sdn up"
    criou sdn
    pausa
    exe "ovs-vsctl show"
    exe "ovs-ofctl dump-flows $BR_SDN"
    mostra "O switch tem duas portas (uma para cada computador) e regras que permitem só ARP e ping entre h1 e h2."
    pausa
    exe "ip netns exec h1 ping -c 3 -W 2 192.0.2.2"
    mostra "Com as regras de permissão, o ping de h1 para h2 funciona."
    pausa
    printf '\nAgora vamos acrescentar UMA regra, com prioridade maior, que descarta o ping de h1 para h2.\n'
    exe "ovs-ofctl add-flow $BR_SDN 'priority=200,icmp,in_port=1,nw_dst=192.0.2.2,actions=drop'"
    exe_falha "ip netns exec h1 ping -c 2 -W 1 192.0.2.2"
    mostra "Uma regra nova bloqueou o ping na hora, sem mexer em cabo nem em equipamento."
    pausa
    printf '\nAgora vamos restaurar as regras originais.\n'
    exe "nexus-sdn flows"
    espera ping_h1 "$LIMITE_VOLTA" "o ping de h1 para h2 não voltou depois de restaurar as regras"
    exe "ip netns exec h1 ping -c 3 -W 2 192.0.2.2"
    mostra "A rede é programada por regras, sem mexer no equipamento: mudou a regra, mudou o comportamento."
    pausa
    exe "nexus-sdn down"
    desfez sdn
    ato_fim
}

# ---------- ato vnf ----------
no_vnf() { docker ps --filter label=containerlab=vnf-frr --format '{{.Names}}' | head -n 1; }
ato_vnf() {
    local n
    ato_inicio vnf "Ato 2: um roteador inteiro como contêiner (VNF)"
    explica "Um roteador de verdade (FRRouting) vai ser criado dentro de um contêiner. É uma função de rede virtual (VNF):
em vez de uma caixa física, é um programa que sobe e desce com um comando."
    precisa docker containerlab nexus-vnf
    limpa_vnf
    espera_imagem
    exe "nexus-vnf up"
    criou vnf
    pausa
    exe "nexus-vnf status"
    n=$(no_vnf)
    [ -n "$n" ] || falha "o contêiner da VNF não foi encontrado"
    exe "docker exec $n vtysh -c 'show running-config' 2>/dev/null | head -n 15"
    mostra "O roteador está no ar e responde aos comandos de configuração, como um equipamento físico."
    pausa
    exe "nexus-vnf down"
    desfez vnf
    mostra "Um roteador inteiro vira um contêiner que sobe e some em segundos."
    ato_fim
}

# ---------- ato rede ----------
vt() { docker exec "clab-integrado-$1" vtysh -c "$2" 2>/dev/null || true; }
full() { [[ $(vt "$1" 'show ip ospf neighbor') =~ [[:space:]]Full/ ]]; }
rota() { [[ $(vt "$1" 'show ip route ospf') == *"O>* $2/32"* ]]; }
convergiu() { full r1 && full r2 && rota r1 198.51.100.22 && rota r2 198.51.100.21; }
caiu() { ! full r1 && ! full r2 && ! rota r1 198.51.100.22 && ! rota r2 198.51.100.21; }
ato_rede() {
    local topo=$RAIZ/labs/containerlab/integrado.clab.yml
    local flows=$RAIZ/sdn/flows/integrado.flows
    local dead limite_queda
    ato_inicio rede "Ato 3: rede integrada, com falha e recuperação"
    explica "Vamos juntar as duas peças: o switch programável (Open vSwitch) com dois roteadores (r1 e r2) ligados a ele.
Os roteadores descobrem um ao outro sozinhos (protocolo OSPF). Depois vamos bloquear esse protocolo no switch,
ver a rede cair e, ao tirar o bloqueio, ver a rede se refazer sozinha."
    precisa docker containerlab nexus-vnf ovs-vsctl ovs-ofctl
    { [ -f "$topo" ] && [ -f "$flows" ]; } || falha "arquivos da rede integrada ausentes em $RAIZ"
    dead=$(sed -n 's/^ ip ospf dead-interval \([0-9]*\)$/\1/p' "$RAIZ/labs/containerlab/configs/int-r1/frr.conf")
    [[ $dead =~ ^[0-9]+$ ]] || falha "dead-interval não encontrado em configs/int-r1/frr.conf"
    limite_queda=$((dead * 3))
    limpa_rede
    espera_imagem
    exe "ovs-vsctl add-br $BR_INT -- set bridge $BR_INT fail_mode=secure"
    criou rede
    exe "nexus-vnf up $topo"
    exe "ovs-ofctl add-flows $BR_INT $flows"
    pausa
    aviso "esperando os roteadores se encontrarem (OSPF)..."
    espera convergiu "$LIMITE_CONVERGE" "o OSPF não chegou a Full com as rotas"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip ospf neighbor' 2>/dev/null"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip route ospf' 2>/dev/null"
    exe "docker exec clab-integrado-r1 ping -c 3 -W 2 -I 198.51.100.21 198.51.100.22"
    mostra "Os dois roteadores se acharam (Full), aprenderam a rota um do outro e conversam pelo switch."
    pausa
    printf '\nAgora vamos descartar, no switch, o protocolo OSPF (protocolo 89).\n'
    exe "ovs-ofctl add-flow $BR_INT 'priority=200,ip,nw_proto=89,actions=drop'"
    aviso "esperando a adjacência cair (até $limite_queda s)..."
    espera caiu "$limite_queda" "a adjacência OSPF e as rotas não caíram com o descarte do protocolo 89"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip ospf neighbor' 2>/dev/null"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip route ospf' 2>/dev/null"
    mostra "Sem o OSPF passando, os roteadores perderam um ao outro e as rotas sumiram."
    pausa
    printf '\nAgora vamos remover o bloqueio.\n'
    exe "ovs-ofctl --strict del-flows $BR_INT 'priority=200,ip,nw_proto=89'"
    aviso "esperando a rede se refazer..."
    espera convergiu "$LIMITE_VOLTA" "o OSPF não voltou a Full depois de remover o descarte"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip ospf neighbor' 2>/dev/null"
    exe "docker exec clab-integrado-r1 vtysh -c 'show ip route ospf' 2>/dev/null"
    mostra "Tirou a regra, a rede voltou sozinha: o controle da rede está nas regras do switch."
    pausa
    exe "nexus-vnf down $topo"
    exe "ovs-vsctl del-br $BR_INT"
    desfez rede
    ato_fim
}

# ---------- ato vm ----------
ato_vm() {
    ato_inicio vm "Ato 4: máquina virtual (KVM e libvirt)"
    explica "Vamos criar uma máquina virtual de teste com o libvirt, listá-la, ver seus dados e removê-la.
Não vamos iniciar um sistema operacional dentro dela: o foco é mostrar a camada de virtualização."
    precisa virsh nexus-vm
    limpa_vm
    exe "nexus-vm criar $VM"
    criou vm
    pausa
    exe "nexus-vm listar"
    exe "virsh -c qemu:///system dominfo $VM"
    if command -v virt-manager >/dev/null; then
        ok "O gerenciador gráfico virt-manager está instalado: $(command -v virt-manager) (abra pelo menu para ver a mesma máquina)."
    else
        falha "virt-manager não encontrado"
    fi
    mostra "A máquina virtual existe e é gerenciada pelo libvirt; o virt-manager mostra a mesma coisa em janelas."
    pausa
    exe "nexus-vm remover $VM"
    desfez vm
    ato_fim
}

ato_tudo() { ato_sdn; ato_vnf; ato_rede; ato_vm; }

menu() {
    local op
    while true; do
        titulo "Demonstração do Nexus OS"
        printf '  1) sdn     rede programada por regras\n  2) vnf     um roteador como contêiner\n'
        printf '  3) rede    rede integrada, falha e recuperação\n  4) vm      máquina virtual\n'
        printf '  5) tudo    os quatro atos em sequência\n  6) limpar  remove o que a demonstração deixou\n  0) sair\n'
        printf '\nEscolha uma opção e aperte Enter: '
        read -r op || exit 0
        case $op in
            1) ato_sdn ;;
            2) ato_vnf ;;
            3) ato_rede ;;
            4) ato_vm ;;
            5) ato_tudo ;;
            6) limpar; ok "tudo limpo" ;;
            0 | q | sair) exit 0 ;;
            '') ;;
            *) aviso "opção inválida: $op" ;;
        esac
    done
}

# ---------- principal ----------
acao=
for a in "$@"; do
    case $a in
        --auto) AUTO=1 ;;
        sdn | vnf | rede | vm | tudo | limpar | ajuda)
            [ -z "$acao" ] || uso
            acao=$a
            ;;
        *) uso ;;
    esac
done
if [ "$acao" = ajuda ]; then
    ajuda
    exit 0
fi

grep -qw 'boot=live' "${NEXUS_CMDLINE:-/proc/cmdline}" 2>/dev/null || {
    echo "Esta demonstração só roda dentro da ISO do Nexus OS (boot=live ausente em /proc/cmdline). Nada foi alterado." >&2
    exit 2
}
[ "$(id -u)" -eq 0 ] || exec sudo -E bash "$0" "$@"
RAIZ=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)

trap sair EXIT
trap 'exit 130' INT TERM
aviso_memoria
case $acao in
    sdn) ato_sdn ;;
    vnf) ato_vnf ;;
    rede) ato_rede ;;
    vm) ato_vm ;;
    tudo) ato_tudo ;;
    limpar) limpar; ok "tudo limpo" ;;
    *)
        if [ "$AUTO" = 1 ]; then uso; fi
        menu
        ;;
esac
