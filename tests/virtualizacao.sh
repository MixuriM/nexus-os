#!/usr/bin/env bash
# Teste de virtualização (F2.6): registra VT-x/AMD-V e /dev/kvm, define e inicia uma VM de teste
# (nfv/libvirt/vm-teste.xml, sem disco) via virsh em qemu:///system e confirma "running".
# Sem /dev/kvm o teste segue em emulação por software (virt-type qemu) e avisa.
# Uso: sudo tests/virtualizacao.sh
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
xml=$raiz/nfv/libvirt/vm-teste.xml
uri=qemu:///system
nome=nexus-vm-teste

[ "$(id -u)" -eq 0 ] || fail "rode como root: sudo tests/virtualizacao.sh"
[ -f "$xml" ] || fail "XML ausente: nfv/libvirt/vm-teste.xml"
command -v virsh >/dev/null || fail "virsh não instalado (pacote libvirt-clients)"
command -v qemu-system-x86_64 >/dev/null || fail "qemu-system-x86_64 não instalado"

tmp=$(mktemp -d)
virsh_() { virsh -c "$uri" "$@"; }
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    virsh_ destroy "$nome" >/dev/null 2>&1 || true
    virsh_ undefine "$nome" >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT

# Premissa 1 do TAP: extensões de virtualização e /dev/kvm (registro, não bloqueia).
cpus=$(grep -Ec '(vmx|svm)' /proc/cpuinfo || true)
echo "vmx/svm: $cpus CPU(s) com a extensão"
if [ -e /dev/kvm ]; then
    ls -l /dev/kvm
    tipo=kvm
else
    echo "AVISO: /dev/kvm ausente; virtualização aninhada indisponível nesta máquina, usando emulação por software (virt-type qemu)"
    tipo=qemu
fi

[ "$(virsh_ uri)" = "$uri" ] || fail "virsh não conectou a $uri"

# O XML versionado usa type='qemu'; com /dev/kvm o teste troca para kvm.
sed "s/type='qemu'/type='$tipo'/" "$xml" >"$tmp/vm.xml"
virsh_ define "$tmp/vm.xml" >/dev/null || fail "virsh define falhou com virt-type $tipo"
virsh_ start "$nome" >/dev/null || fail "virsh start falhou"

estado=$(virsh_ list --all | awk -v n="$nome" '$2 == n { print $3 }')
echo "virsh list --all: $nome $estado"
[ "$estado" = running ] || fail "domínio $nome não está running (estado: $estado)"

virsh_ destroy "$nome" >/dev/null || fail "virsh destroy falhou"
virsh_ undefine "$nome" >/dev/null || fail "virsh undefine falhou"
[ -z "$(virsh_ list --all --name | grep -x "$nome" || true)" ] || fail "domínio $nome sobrou depois do undefine"
if pgrep -f "guest=$nome" >/dev/null; then fail "processo QEMU de $nome sobrou"; fi

echo "OK: tests/virtualizacao.sh (virt-type $tipo, domínio $nome running e removido)"
