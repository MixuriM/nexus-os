#!/usr/bin/env bash
# Cenário T1 no convidado (F4.2a): serviços do núcleo ativos depois do boot e fatos do ambiente (RAM visível,
# vCPU, KVM, uptime). Só para a ISO: o tests/cenario-t1.sh o roda por "iso-smoke --extra" como o teste "t1".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"

for s in openvswitch-switch libvirtd docker frr; do
    systemctl is-active --quiet "$s" || fail "serviço $s inativo depois do boot"
    echo "serviço $s: ativo"
done

metrica memtotal_mib "$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)"
metrica vcpus "$(nproc)"
if [ -e /dev/kvm ]; then metrica kvm_no_convidado sim; else metrica kvm_no_convidado nao; fi
metrica uptime_s "$(cut -d. -f1 /proc/uptime)"
metrica ram_usada_mib "$(LC_ALL=C free -m | awk '/^Mem:/ { print $3 }')"

echo "NEXUS-CENARIO-OK t1"
