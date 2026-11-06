#!/usr/bin/env bash
# Cenário T4 no convidado (F4.2d): nexus-vm criar, listar e remover em 3 ciclos seguidos. A VM chega a running,
# o XML do domínio tem type='kvm' com /dev/kvm no convidado (senão 'qemu'), libvirtd está ativo, o usuário
# "user" vê o domínio sem sudo (uri_default do libvirt.conf da ISO) e depois do remover não sobra domínio,
# processo, XML nem arquivo temporário. Só para a ISO: o tests/cenario-t4.sh o roda por "iso-smoke --extra"
# como o teste "t4".
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }
metrica() { echo "NEXUS-CENARIO-METRICA $1: $2"; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in virsh nexus-vm runuser; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done

uri=qemu:///system
nome=cen-t4
# LC_ALL=C: o teste lê o estado do virsh, que muda com o idioma (por exemplo "executando" em pt_BR).
virsh_() { LC_ALL=C virsh -c "$uri" "$@"; }
# shellcheck disable=SC2317  # chamada indiretamente pelo trap
cleanup() {
    virsh_ destroy "$nome" >/dev/null 2>&1 || true
    virsh_ undefine "$nome" >/dev/null 2>&1 || true
    rm -f /run/cen-t4.antes
}
trap cleanup EXIT

if [ -e /dev/kvm ]; then
    esperado=kvm
    metrica kvm_no_convidado sim
else
    esperado=qemu
    metrica kvm_no_convidado nao
fi
echo "tipo esperado do domínio: $esperado"

find /tmp -mindepth 1 -maxdepth 1 | sort >/run/cen-t4.antes
for i in 1 2 3; do
    echo "--- ciclo $i"
    # T4: antes de criar
    systemctl is-active --quiet libvirtd || fail "libvirtd inativo antes do criar (ciclo $i)"
    inicio=$(date +%s.%N)
    nexus-vm criar "$nome" || fail "nexus-vm criar falhou (ciclo $i)"
    estado=
    for _ in $(seq 1 30); do
        estado=$(virsh_ domstate "$nome" 2>/dev/null || true)
        [ "$estado" = running ] && break
        sleep 1
    done
    fim=$(date +%s.%N)
    [ "$estado" = running ] || fail "domínio $nome não chegou a running (estado: ${estado:-ausente}, ciclo $i)"
    metrica "criar_ate_running_s_ciclo$i" "$(awk -v a="$inicio" -v b="$fim" 'BEGIN { printf "%.2f", b - a }')"

    virsh_ dumpxml "$nome" | grep -q "<domain type='$esperado'" || fail "XML do domínio sem type='$esperado' (ciclo $i)"
    listagem=$(nexus-vm listar)
    grep -qE "[[:space:]]${nome}[[:space:]]+running" <<<"$listagem" || fail "nexus-vm listar não mostra $nome running (ciclo $i)"

    # O user vê o domínio do sistema sem sudo: só o uri_default do /etc/libvirt/libvirt.conf leva ao qemu:///system.
    visto=$(runuser -u user -- env -i HOME=/home/user PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C virsh uri) ||
        fail "virsh uri falhou para o user (ciclo $i)"
    [ "$visto" = "$uri" ] || fail "o user usa a URI '$visto', esperado $uri (ciclo $i)"
    runuser -u user -- env -i HOME=/home/user PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C virsh list --all | grep -q "$nome" ||
        fail "o user não vê o domínio $nome com virsh list --all sem sudo (ciclo $i)"

    nexus-vm remover "$nome" || fail "nexus-vm remover falhou (ciclo $i)"
    if virsh_ list --all --name | grep -qx "$nome"; then fail "domínio $nome sobrou depois do remover (ciclo $i)"; fi
    if pgrep -f "guest=$nome" >/dev/null; then fail "processo QEMU de $nome sobrou (ciclo $i)"; fi
    [ ! -e "/etc/libvirt/qemu/$nome.xml" ] || fail "XML persistente de $nome sobrou (ciclo $i)"
    echo "ciclo $i: criar, listar e remover ok"
done

find /tmp -mindepth 1 -maxdepth 1 | sort | diff -q /run/cen-t4.antes - >/dev/null || fail "sobrou arquivo temporário em /tmp depois dos ciclos"
metrica ciclos_ok 3

echo "NEXUS-CENARIO-OK t4"
