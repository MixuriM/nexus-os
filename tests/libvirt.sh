#!/usr/bin/env bash
# Teste do libvirt dentro da ISO (F3.3): rede default ativa e com autostart, usuário da live no grupo
# libvirt e ciclo criar, listar, remover de uma VM com o comando nexus-vm.
# Só para a ISO (nexus-smoke). Uso: sudo nexus-smoke libvirt
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
command -v virsh >/dev/null || fail "virsh não instalado (pacote libvirt-clients)"
command -v nexus-vm >/dev/null || fail "nexus-vm não encontrado em /usr/local/bin"

uri=qemu:///system
nome=smoke1
# LC_ALL=C: o teste lê o estado e os campos do virsh, que mudam com o idioma (por exemplo "executando" em pt_BR).
virsh_() { LC_ALL=C virsh -c "$uri" "$@"; }
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    virsh_ destroy "$nome" >/dev/null 2>&1 || true
    virsh_ undefine "$nome" >/dev/null 2>&1 || true
}
trap cleanup EXIT

info=$(virsh_ net-info default) || fail "rede default não existe"
grep -Eq '^Active:[[:space:]]+yes' <<<"$info" || fail "rede default não está ativa"
grep -Eq '^Autostart:[[:space:]]+yes' <<<"$info" || fail "rede default sem autostart"
echo "rede default: ativa e com autostart"

id user | grep -qw libvirt || fail "usuário user fora do grupo libvirt: $(id user)"
echo "usuário user no grupo libvirt"

nexus-vm criar "$nome" || fail "nexus-vm criar falhou"
estado=$(virsh_ list --all | awk -v n="$nome" '$2 == n { print $3 }')
[ "$estado" = running ] || fail "domínio $nome não está running (estado: ${estado:-ausente})"
nexus-vm remover "$nome" || fail "nexus-vm remover falhou"
[ -z "$(virsh_ list --all --name | grep -x "$nome" || true)" ] || fail "domínio $nome sobrou depois do remover"
if pgrep -f "guest=$nome" >/dev/null; then fail "processo QEMU de $nome sobrou"; fi

echo "OK: tests/libvirt.sh (rede default, grupo libvirt e ciclo da VM $nome)"
