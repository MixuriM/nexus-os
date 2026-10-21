#!/usr/bin/env bash
# Gera a ISO da prova de conceito em dist/nexus-os-poc-amd64.iso.
# Uso (em Linux, com o repositório no disco do Linux): sudo scripts/build-iso.sh
set -euo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "o build só roda em Linux"
raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
case $raiz in
    /mnt/*) die "o build não roda em /mnt/*: clone o repositório no disco do Linux" ;;
esac
[ "$(id -u)" -eq 0 ] || die "precisa de root: sudo scripts/build-iso.sh"
command -v lb >/dev/null || die "live-build não instalado (veja docs/ambiente-de-build.md)"

cd "$raiz/live-build"
inicio=$SECONDS
{ lb clean && lb config && lb build; } 2>&1 | tee build.log \
    || die "o build falhou, veja live-build/build.log"

shopt -s nullglob
isos=(nexus-os-*.iso)
[ ${#isos[@]} -eq 1 ] || die "esperava uma ISO nexus-os-*.iso em live-build/, achei ${#isos[@]}"

mkdir -p "$raiz/dist"
mv -f "${isos[0]}" "$raiz/dist/nexus-os-poc-amd64.iso"
(cd "$raiz/dist" && sha256sum nexus-os-poc-amd64.iso >nexus-os-poc-amd64.iso.sha256)
# Com sudo, devolve os arquivos ao usuário que chamou.
chown -R "${SUDO_UID:-0}:${SUDO_GID:-0}" "$raiz/dist"

tamanho=$(stat -c %s "$raiz/dist/nexus-os-poc-amd64.iso")
echo "OK: dist/nexus-os-poc-amd64.iso, $tamanho bytes, $((SECONDS - inicio)) s"
cat "$raiz/dist/nexus-os-poc-amd64.iso.sha256"
