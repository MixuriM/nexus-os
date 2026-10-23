#!/usr/bin/env bash
# Cria, lista e remove VMs de teste do libvirt (F3.3) a partir de nfv/libvirt/vm-teste.xml.
# Na ISO, o link /usr/local/bin/nexus-vm aponta para este script.
# Uso: nexus-vm criar <nome> | listar | remover <nome>   (como root ou membro do grupo libvirt)
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

aqui=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
xml=$aqui/vm-teste.xml
uri=qemu:///system
virsh_() { virsh -c "$uri" "$@"; }

nome_valido() {
    [[ ${1:-} =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "nome inválido '${1:-}': use só a-z, 0-9 e hífen, sem hífen no início"
}

existe() { virsh_ list --all --name | grep -qx -- "$1"; }

[ $# -ge 1 ] || fail "uso: nexus-vm criar <nome> | listar | remover <nome>"
cmd=$1
command -v virsh >/dev/null || fail "virsh não instalado (pacote libvirt-clients)"

case $cmd in
    criar)
        [ $# -eq 2 ] || fail "uso: nexus-vm criar <nome>"
        nome=$2
        nome_valido "$nome"
        [ -f "$xml" ] || fail "XML ausente: $xml"
        existe "$nome" && fail "domínio $nome já existe"
        if [ -e /dev/kvm ]; then tipo=kvm; else tipo=qemu; fi
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        sed -e "s/type='qemu'/type='$tipo'/" -e "s|<name>nexus-vm-teste</name>|<name>$nome</name>|" "$xml" >"$tmp/vm.xml"
        virsh_ define "$tmp/vm.xml" >/dev/null || fail "virsh define falhou com virt-type $tipo"
        virsh_ start "$nome" >/dev/null || { virsh_ undefine "$nome" >/dev/null 2>&1 || true; fail "virsh start falhou"; }
        echo "OK: VM $nome criada e iniciada (virt-type $tipo)"
        ;;
    listar)
        virsh_ list --all
        ;;
    remover)
        [ $# -eq 2 ] || fail "uso: nexus-vm remover <nome>"
        nome=$2
        nome_valido "$nome"
        existe "$nome" || fail "domínio $nome não existe"
        virsh_ destroy "$nome" >/dev/null 2>&1 || true
        virsh_ undefine "$nome" >/dev/null || fail "virsh undefine falhou"
        echo "OK: VM $nome removida"
        ;;
    *)
        fail "comando desconhecido '$cmd': use criar, listar ou remover"
        ;;
esac
