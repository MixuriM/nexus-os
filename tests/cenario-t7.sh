#!/usr/bin/env bash
# Cenário T7 (F4.2f): sessão gráfica da RC2 em QEMU com vídeo (-vga std) e sem rede. O script do convidado
# (tests/cenarios-guest/t7.sh) espera o desktop com login automático, cria uma VM pelo nexus-vm, abre o virt-manager,
# sobe a VNF FRR e a topologia Containerlab pelos atalhos e abre a documentação local. Em cada momento ele imprime
# "NEXUS-SMOKE-PONTO <nome>"; o tests/iso-smoke.sh (NEXUS_SMOKE_CAPTURAS) tira uma captura da tela por ponto.
# Pontos: desktop-pronto, virt-manager-com-vm, vnf-acima, clab-acima, docs-abertos.
# Critério das capturas (tests/png-info.py): PNG válido, largura e altura maiores que zero, pelo menos
# T7_CORES cores distintas (padrão 2000: o desktop pintado tem de 4000 a 20000; só a barra sobre fundo preto tem
# cerca de 570, uma tela preta ou de uma cor só tem 1) e até 1 MiB por arquivo.
# Variáveis: T7_CORES e NEXUS_SMOKE_MEM (RAM do convidado, padrão 2560 MiB). As capturas vão para
# evidencias/T7/<data>-<modo>-<ponto>.png, ao lado do .md e do .txt da evidência.
# Uso: tests/cenario-t7.sh <iso>   (na VM de build; precisa de qemu-system-x86, xorriso e python3)
set -uo pipefail

raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$raiz/tests/lib-cenario.sh"

# RAM do convidado: a recomendada com o desktop em docs/requisitos.md (NEXUS_SMOKE_MEM troca).
export NEXUS_SMOKE_MEM=${NEXUS_SMOKE_MEM:-2560}
cen_init T7 "${1:-}"
CEN_METRICAS+=("ram_convidado_mib: $NEXUS_SMOKE_MEM")
cores_min=${T7_CORES:-2000}
[[ $cores_min =~ ^[1-9][0-9]*$ ]] || cen_fim FALHA "T7_CORES inválido: $cores_min"
pontos=(desktop-pronto virt-manager-com-vm vnf-acima clab-acima docs-abertos)
max_bytes=1048576

# fim <OK|FALHA> <mensagem>: registra a evidência e copia as capturas para o lado dela.
fim() {
    local res=$1 msg=$2 saida base p
    echo "$res: $msg" >>"$CEN_LOG"
    saida=$(evidencia_registrar "$CEN" "$MODO" "$CEN_CMD" "$CEN_LOG" "$res" "$CEN_ISO" "${CEN_METRICAS[@]}") || exit 1
    echo "$saida"
    base=$(basename "${saida##*evidência: }" .md)
    for p in "${pontos[@]}"; do
        [ ! -f "$cap/captura-$p.png" ] || cp "$cap/captura-$p.png" "$(dirname "${saida##*evidência: }")/$base-$p.png"
    done
    if [ "$res" = OK ]; then
        echo "OK: cenário $CEN ($msg, $MODO)"
        exit 0
    fi
    echo "FALHA: cenário $CEN: $msg" >&2
    exit 1
}

cap=$CEN_TMP/cap
mkdir "$cap"
export NEXUS_SMOKE_CAPTURAS=$cap/captura
cen_convidado "$CEN_GUEST" t7 || fim FALHA "o script do convidado falhou ou não imprimiu NEXUS-CENARIO-OK t7"

for p in "${pontos[@]}"; do
    f=$cap/captura-$p.png
    [ -s "$f" ] || fim FALHA "captura ausente: $p"
    tam=$(stat -c %s "$f")
    [ "$tam" -le "$max_bytes" ] || fim FALHA "captura grande demais: $p tem $tam bytes (máximo $max_bytes)"
    if ! info=$(python3 -I "$raiz/tests/png-info.py" "$f" "$cores_min" 2>&1); then
        fim FALHA "captura inválida: $p: $info"
    fi
    read -r larg alt cores <<<"$info"
    { [ "$larg" -gt 0 ] && [ "$alt" -gt 0 ]; } || fim FALHA "captura vazia: $p (${larg}x${alt})"
    [ "$cores" -ge "$cores_min" ] || fim FALHA "captura vazia: $p tem só $cores cor(es) distinta(s) (mínimo $cores_min)"
    CEN_METRICAS+=("captura_$p: ${larg}x${alt}, $tam bytes, pelo menos $cores_min cores distintas")
done
for p in "${pontos[@]}"; do
    grep -aq "NEXUS-SMOKE-PONTO $p" "$CEN_LOG" || fim FALHA "ponto sem marcador na serial: $p"
done

fim OK "${#pontos[@]} pontos com captura válida"
