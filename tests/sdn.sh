#!/usr/bin/env bash
# Teste do laboratório Open vSwitch (F2.5): bridge em modo secure, sem controlador, e dois
# namespaces (h1 e h2) que só conversam por causa das regras de sdn/flows/basico.flows.
# Uso: sudo tests/sdn.sh
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lab=$raiz/sdn/lab-ovs.sh
regras=$raiz/sdn/flows/basico.flows
br='br-nexus'

[ "$(id -u)" -eq 0 ] || fail "rode como root: sudo tests/sdn.sh"
[ -f "$lab" ] || fail "laboratório ausente: sdn/lab-ovs.sh"
[ -f "$regras" ] || fail "regras ausentes: sdn/flows/basico.flows"
for cmd in ovs-vsctl ovs-ofctl ip ping; do
    command -v "$cmd" >/dev/null || fail "$cmd não instalado"
done

# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() { bash "$lab" down >/dev/null 2>&1 || true; }
trap cleanup EXIT

h2_ip=192.0.2.2
ping_h1_h2() { ip netns exec h1 ping -c 2 -W 2 "$h2_ip" >/dev/null 2>&1; }

bash "$lab" up >/dev/null || fail "sdn/lab-ovs.sh up falhou"

# Premissas do laboratório: modo secure e nenhum controlador.
[ "$(ovs-vsctl get-fail-mode "$br")" = secure ] || fail "fail-mode de $br não é secure"
[ -z "$(ovs-vsctl get-controller "$br")" ] || fail "$br tem controlador configurado"

# Caso positivo: com as regras, h1 alcança h2 e dump-flows mostra as regras.
esperadas=$(grep -cvE '^[[:space:]]*(#|$)' "$regras" || true)
[ "$esperadas" -gt 0 ] || fail "sdn/flows/basico.flows não tem regras"
atuais=$(ovs-ofctl dump-flows "$br" | grep -c 'priority=')
[ "$atuais" -eq "$esperadas" ] || fail "dump-flows mostra $atuais regras, esperado $esperadas"
ping_h1_h2 || fail "ping h1 para h2 falhou com as regras carregadas"
ovs-ofctl dump-flows "$br" | grep -q "n_packets=[1-9].*icmp.*nw_dst=$h2_ip" \
    || fail "a regra ICMP para $h2_ip não contou pacotes"

# Caso negativo: sem regras, o padrão do modo secure é descartar tudo.
ovs-ofctl del-flows "$br"
[ "$(ovs-ofctl dump-flows "$br" | grep -c 'priority=')" -eq 0 ] || fail "del-flows não esvaziou a tabela"
if ping_h1_h2; then fail "ping h1 para h2 funcionou sem regras"; fi

# Recarregar as regras restaura a conectividade.
bash "$lab" flows >/dev/null || fail "sdn/lab-ovs.sh flows falhou"
ping_h1_h2 || fail "ping h1 para h2 falhou depois de recarregar as regras"

bash "$lab" down >/dev/null || fail "sdn/lab-ovs.sh down falhou"
ip netns list | grep -qE '^h[12]( |$)' && fail "namespace sobrou depois do down"
ovs-vsctl br-exists "$br" && fail "bridge $br sobrou depois do down"

echo "OK: tests/sdn.sh ($esperadas regras, ping com regras, sem ping sem regras)"
