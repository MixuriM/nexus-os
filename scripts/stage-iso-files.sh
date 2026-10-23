#!/usr/bin/env bash
# Copia sdn, nfv, labs, tests e docs do repositório para /usr/share/nexus-os da ISO, ou seja, para
# live-build/config/includes.chroot/usr/share/nexus-os/ (pasta gerada, ignorada pelo git).
# Chamado por scripts/build-iso.sh entre "lb config" e "lb build". Não precisa de root.
set -euo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "o build só roda em Linux"
raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
destino=$raiz/live-build/config/includes.chroot/usr/share/nexus-os

rm -rf "$destino"
mkdir -p "$destino"
for pasta in sdn nfv labs tests docs; do
    [ -d "$raiz/$pasta" ] || die "pasta ausente no repositório: $pasta"
done
# Só o que o git versiona ou o que é novo e não ignorado: arquivo ignorado (log, nota local) não vai para a ISO.
(cd "$raiz" && git ls-files -z --cached --others --exclude-standard -- sdn nfv labs tests docs |
    xargs -0 -r cp -a --parents -t "$destino")
echo "OK: stage-iso-files, $(find "$destino" -type f | wc -l) arquivos em ${destino#"$raiz"/}"
