#!/usr/bin/env bash
# Prepara as imagens de contêiner que entram na ISO (F3.4): lê live-build/offline/imagens.txt, baixa
# a imagem se faltar ou se o digest local divergir, confere o digest travado e salva um .tar em
# live-build/config/includes.chroot/var/lib/nexus-os/images/ (pasta gerada, ignorada pelo git).
# Chamado por scripts/build-iso.sh antes do "lb build". Precisa de Docker e de internet na VM de build.
# Uso: sudo scripts/prepare-offline.sh
set -euo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "o build só roda em Linux"
raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
lista=${NEXUS_IMAGENS:-$raiz/live-build/offline/imagens.txt}
destino=$raiz/live-build/config/includes.chroot/var/lib/nexus-os/images

command -v docker >/dev/null || die "docker não instalado (veja docs/ambiente-de-build.md)"
docker info >/dev/null 2>&1 || die "docker não responde (rode como root ou entre no grupo docker)"
[ -f "$lista" ] || die "lista ausente: ${lista#"$raiz"/}"

# Digest local da imagem $1 (repositório:tag), vazio se ela não existe.
digest_local() {
    docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$1" 2>/dev/null |
        awk -F@ -v repo="${1%:*}" '$1 == repo { print $2; exit }'
}

rm -rf "$destino"
mkdir -p "$destino"
total=0
while read -r ref digest resto; do
    case $ref in ''|'#'*) continue ;; esac
    if [ -z "$digest" ] || [ -n "${resto:-}" ]; then die "linha inválida em ${lista##*/}: $ref $digest ${resto:-}"; fi
    [[ $ref =~ ^[a-z0-9._/-]+:[A-Za-z0-9._-]+$ ]] || die "referência inválida (use repositório:tag): $ref"
    [[ $digest =~ ^sha256:[0-9a-f]{64}$ ]] || die "digest inválido para $ref: $digest"

    atual=$(digest_local "$ref")
    if [ "$atual" != "$digest" ]; then
        echo "baixando $ref (digest local: ${atual:-ausente})"
        docker pull "$ref" >/dev/null || die "docker pull $ref falhou"
        atual=$(digest_local "$ref")
    fi
    [ "$atual" = "$digest" ] || die "digest de $ref diverge: travado $digest, obtido ${atual:-nenhum}"

    arquivo=$destino/${ref//[\/:]/_}.tar
    docker save -o "$arquivo" "$ref" || die "docker save $ref falhou"
    echo "OK: $ref $digest -> ${arquivo#"$raiz"/} ($(stat -c %s "$arquivo") bytes)"
    total=$((total + 1))
done <"$lista"

[ "$total" -gt 0 ] || die "nenhuma imagem em ${lista##*/}"
echo "OK: prepare-offline, $total imagem(ns)"
