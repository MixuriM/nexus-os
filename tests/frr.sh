#!/usr/bin/env bash
# Teste do FRRouting dentro da ISO (F3.5): o pacote frr responde ao vtysh, a configuração de exemplo
# (nfv/frr/exemplo) é aplicada, o loopback e o OSPF aparecem na configuração em execução e o ospfd
# responde. Os arquivos originais de /etc/frr são restaurados no fim.
# Só para a ISO (nexus-smoke). Uso: sudo nexus-smoke frr
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exemplo=$raiz/nfv/frr/exemplo
loopback=198.51.100.10/32
limite=60

command -v vtysh >/dev/null || fail "vtysh não instalado (pacote frr)"
for f in daemons frr.conf; do
    [ -f "$exemplo/$f" ] || fail "configuração de exemplo ausente: nfv/frr/exemplo/$f"
done

versao=$(vtysh -c 'show version' 2>&1) || fail "vtysh -c 'show version' não respondeu: $versao"
grep -q '^FRRouting' <<<"$versao" || fail "versão do FRR inesperada: ${versao%%$'\n'*}"
echo "FRR do pacote: ${versao%%$'\n'*}"

tmp=$(mktemp -d)
cp -a /etc/frr/daemons /etc/frr/frr.conf "$tmp/"
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    cp -a "$tmp/daemons" "$tmp/frr.conf" /etc/frr/
    systemctl restart frr || echo "aviso: frr não reiniciou na restauração" >&2
    rm -rf "$tmp"
}
trap cleanup EXIT

install -m 0640 -o frr -g frr "$exemplo/daemons" /etc/frr/daemons
install -m 0640 -o frr -g frr "$exemplo/frr.conf" /etc/frr/frr.conf
systemctl restart frr || fail "systemctl restart frr falhou com a configuração de exemplo"

inicio=$SECONDS
until conf=$(vtysh -c 'show running-config' 2>/dev/null) && grep -q "ip address $loopback" <<<"$conf" && grep -q '^router ospf' <<<"$conf"; do
    [ $((SECONDS - inicio)) -lt "$limite" ] || fail "loopback $loopback e router ospf não apareceram na configuração em execução em ${limite} s"
    sleep 2
done
tempo=$((SECONDS - inicio))
echo "configuração em execução com $loopback e router ospf em ${tempo} s"

ospf=$(vtysh -c 'show ip ospf' 2>&1) || fail "ospfd não respondeu a show ip ospf: $ospf"
grep -q 'OSPF Routing Process' <<<"$ospf" || fail "ospfd respondeu sem o processo OSPF: ${ospf%%$'\n'*}"
echo "ospfd responde: $(grep -m1 'OSPF Routing Process' <<<"$ospf")"

echo "OK: tests/frr.sh (${versao%%$'\n'*}, $loopback em OSPF área 0, ${tempo} s)"
