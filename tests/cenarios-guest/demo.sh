#!/usr/bin/env bash
# Teste da demonstração (RC3) dentro da ISO. Confere: na entrada padrão do menu não há nexus.demo=1 nem terminal da
# demonstração; "nexus-demo tudo --auto" termina com 0 e imprime os 4 marcadores NEXUS-DEMO-ATO <ato> OK <s>; depois
# não sobra ponte, namespace, contêiner, rede clab nem domínio do libvirt; "nexus-demo limpar" roda 2 vezes seguidas
# com 0; e "nexus-demo" fora da ISO (sem boot=live no NEXUS_CMDLINE) sai com 2 sem mexer em nada.
# Só para a ISO: roda por "iso-smoke --extra" como o teste "demo" (veja tests/demo.sh).
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"
for cmd in nexus-demo docker ovs-vsctl virsh ip; do
    command -v "$cmd" >/dev/null || fail "$cmd não encontrado"
done

# Entrada padrão: nenhum parâmetro de demonstração e nenhum terminal da demonstração.
! grep -qw 'nexus.demo=1' /proc/cmdline || fail "/proc/cmdline tem nexus.demo=1 na entrada padrão"
! pgrep -af 'xfce4-terminal.*nexus-demo' >/dev/null || fail "há um terminal da demonstração rodando na entrada padrão"

sobras() {
    local s=
    [ -z "$(ovs-vsctl list-br)" ] || s="$s ponte($(ovs-vsctl list-br | paste -sd, -))"
    [ -z "$(ip netns list)" ] || s="$s netns($(ip netns list | paste -sd, -))"
    [ -z "$(docker ps -aq)" ] || s="$s contêiner($(docker ps -a --format '{{.Names}}' | paste -sd, -))"
    ! docker network inspect clab >/dev/null 2>&1 || s="$s rede-clab"
    [ -z "$(virsh -c qemu:///system list --all --name | tr -d '[:space:]')" ] || s="$s domínio-libvirt"
    echo "$s"
}
[ -z "$(sobras)" ] || fail "já havia sobras antes da demonstração:$(sobras)"

# Fora da ISO: sai com 2 e não cria nada.
semlive=$(mktemp)
saida=$(mktemp)
trap 'rm -f "$semlive" "$saida"' EXIT
echo 'quiet splash' >"$semlive"
rc=0
NEXUS_CMDLINE=$semlive nexus-demo tudo --auto >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "nexus-demo fora da ISO saiu com $rc, esperado 2"
[ -z "$(sobras)" ] || fail "nexus-demo fora da ISO deixou sobras:$(sobras)"

# Uso inválido: sai com 2.
rc=0
nexus-demo ato-que-nao-existe >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "nexus-demo com ato inválido saiu com $rc, esperado 2"

# A demonstração completa.
inicio=$SECONDS
rc=0
nexus-demo tudo --auto >"$saida" 2>&1 || rc=$?
cat "$saida"
[ "$rc" -eq 0 ] || fail "nexus-demo tudo --auto saiu com $rc"
for ato in sdn vnf rede vm; do
    grep -qE "^NEXUS-DEMO-ATO $ato OK [0-9]+$" "$saida" || fail "sem a linha 'NEXUS-DEMO-ATO $ato OK <s>'"
done
[ "$(grep -c '^NEXUS-DEMO-ATO ' "$saida")" -eq 4 ] || fail "esperava exatamente 4 linhas NEXUS-DEMO-ATO"
echo "NEXUS-DEMO-TOTAL tudo $((SECONDS - inicio))"
[ -z "$(sobras)" ] || fail "sobrou depois da demonstração:$(sobras)"

# limpar: duas vezes seguidas, com 0, também sem nada para limpar.
nexus-demo limpar >/dev/null || fail "nexus-demo limpar (1ª vez) falhou"
nexus-demo limpar >/dev/null || fail "nexus-demo limpar (2ª vez) falhou"
[ -z "$(sobras)" ] || fail "sobrou depois do limpar:$(sobras)"

echo "NEXUS-CENARIO-OK demo"
