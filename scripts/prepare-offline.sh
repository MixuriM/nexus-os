#!/usr/bin/env bash
# Prepara o que entra na ISO sem rede: as imagens de contêiner (F3.4) e o .deb do Containerlab (F3.7).
# Lê live-build/offline/imagens.txt, baixa a imagem se faltar ou se o digest local divergir, confere o
# digest travado e salva um .tar em live-build/config/includes.chroot/var/lib/nexus-os/images/ (pasta
# gerada, ignorada pelo git). Baixa o .deb para live-build/config/packages.chroot/ (ignorado) e confere
# o SHA256 de live-build/offline/containerlab.sha256.
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

# Pacotes .deb locais (F3.7): o live-build instala o que estiver em config/packages.chroot/. O SHA256
# travado vem de live-build/offline/containerlab.sha256 (formato do sha256sum); divergência é falha.
debs=$raiz/live-build/config/packages.chroot
sums=${NEXUS_DEBS:-$raiz/live-build/offline/containerlab.sha256}
url_base=https://github.com/srl-labs/containerlab/releases/download
[ -f "$sums" ] || die "lista ausente: ${sums#"$raiz"/}"
command -v curl >/dev/null || die "curl não instalado"
mkdir -p "$debs"
ndebs=0
while read -r hash nome resto; do
    case $hash in ''|'#'*) continue ;; esac
    [ -z "${resto:-}" ] || die "linha inválida em ${sums##*/}: $hash $nome $resto"
    [[ $hash =~ ^[0-9a-f]{64}$ ]] || die "SHA256 inválido para $nome: $hash"
    [[ $nome =~ ^containerlab_([0-9.]+)_linux_amd64\.deb$ ]] || die "nome de pacote inválido: $nome"
    if ! { [ -f "$debs/$nome" ] && echo "$hash  $debs/$nome" | sha256sum -c --status; }; then
        echo "baixando $nome"
        curl -fsSL -o "$debs/$nome" "$url_base/v${BASH_REMATCH[1]}/$nome" || die "download de $nome falhou"
    fi
    echo "$hash  $debs/$nome" | sha256sum -c --status \
        || die "SHA256 de $nome diverge: travado $hash, obtido $(sha256sum "$debs/$nome" | cut -d' ' -f1)"
    echo "OK: $nome $hash -> ${debs#"$raiz"/} ($(stat -c %s "$debs/$nome") bytes)"
    ndebs=$((ndebs + 1))
done <"$sums"
[ "$ndebs" -gt 0 ] || die "nenhum pacote em ${sums##*/}"

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
echo "OK: prepare-offline, $total imagem(ns), $ndebs pacote(s) .deb"
