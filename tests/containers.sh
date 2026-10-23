#!/usr/bin/env bash
# Teste de contêineres dentro da ISO (F3.4): sem internet, o Docker responde, a imagem do FRR já foi
# carregada pelo nexus-images.service e um contêiner descartável sem rede imprime a versão do FRR.
# Só para a ISO (nexus-smoke). Uso: sudo nexus-smoke containers
set -euo pipefail

fail() { echo "FALHA: $*" >&2; exit 1; }

grep -qw 'boot=live' /proc/cmdline || fail "este teste roda só dentro da ISO (boot=live ausente em /proc/cmdline)"
[ "$(id -u)" -eq 0 ] || fail "rode como root"

imagem=quay.io/frrouting/frr:10.7.1

# Sem rota padrão não há internet: a imagem tem de vir de dentro da ISO.
[ -z "$(ip route show default)" ] || fail "há rota padrão: o teste precisa rodar sem internet ($(ip route show default))"
echo "sem rota padrão: teste sem internet"

command -v docker >/dev/null || fail "docker não instalado (pacote docker.io)"
docker info >/dev/null 2>&1 || fail "docker info não responde (docker.service ativo?)"
driver=$(docker info --format '{{.Driver}}')
# A raiz da live é overlayfs: sem o tmpfs em /var/lib/docker o Docker cai para vfs (692 MB medidos para a imagem do FRR).
[ "$driver" = overlay2 ] || fail "driver de armazenamento do Docker é $driver, esperado overlay2 (var-lib-docker.mount ativo?)"
echo "driver de armazenamento: $driver"

docker image inspect "$imagem" >/dev/null 2>&1 || fail "imagem $imagem não carregada (nexus-images.service)"
echo "imagem presente: $imagem"

# Sem "| head": o zebra imprime várias linhas e o docker run falha com "broken pipe" se o leitor fechar antes.
versao=$(docker run --rm --network none --entrypoint /usr/lib/frr/zebra "$imagem" --version) \
    || fail "contêiner de $imagem não rodou"
versao=${versao%%$'\n'*}
grep -q '^zebra version 10\.7\.1' <<<"$versao" || fail "versão do FRR inesperada: $versao"
echo "FRR no contêiner: $versao"

[ -z "$(docker ps -aq)" ] || fail "contêiner sobrou: $(docker ps -aq | tr '\n' ' ')"

echo "OK: tests/containers.sh (sem rota padrão, docker ativo, imagem $imagem, $versao)"
