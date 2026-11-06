#!/usr/bin/env bash
# Biblioteca de evidência dos testes funcionais (Fase 4). Para usar com "source" nos tests/cenario-tN.sh.
# Funções: evidencia_sanitizar e evidencia_registrar (formato em evidencias/MODELO.md).
# Variáveis opcionais: EVID_DIR (padrão evidencias/ do repo), EVID_SHA (SHA256 da ISO, evita recalcular),
# EVID_HOSTNAMES (nomes de máquina extras a mascarar), EVID_AMBIENTE (texto do ambiente).

_evid_raiz=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EVID_MAX_LINHAS=300

# Lê a saída bruta da entrada padrão e imprime a versão sanitizada: sem CR, sem sequências ANSI, sem IP
# privado (10.x, 172.16 a 172.31, 192.168.x), e-mail, caminho de usuário do Windows, /home/<nome> (exceto
# /home/user, a conta pública da live) nem nome de máquina; no máximo EVID_MAX_LINHAS linhas (início e fim).
evidencia_sanitizar() {
    local h hosts=${EVID_HOSTNAMES:-} expr=()
    h=$(hostname 2>/dev/null || true)
    case $h in nexus-os | localhost | debian | "") ;; *) hosts="$hosts $h" ;; esac
    for h in $hosts; do
        expr+=(-e "s#$(printf '%s' "$h" | sed 's/[][\.*^$#]/\\&/g')#<maquina>#g")
    done
    tr -d '\r' |
        sed -E \
            -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
            -e 's/(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)/\1<ip-privado>\4/g' \
            -e 's/(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)/\1<ip-privado>\4/g' \
            -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/<email>/g' \
            -e 's#[A-Za-z]:\\Users\\[^\\]*#<usuario-windows>#g' \
            -e 's#([A-Za-z]:|/[a-z])/Users/[^/ ]*#<usuario-windows>#g' \
            -e 's#/home/user([^[:alnum:]_.-]|$)#/home/@U@\1#g' \
            -e 's#/home/[^/ @]+#/home/<usuario>#g' \
            -e 's#/home/@U@#/home/user#g' \
            -e 's/[A-Za-z0-9-]+\.mshome\.net/<maquina>/g' \
            "${expr[@]}" |
        cut -c1-1000 |
        awk -v max="$EVID_MAX_LINHAS" '
            { l[NR] = $0 }
            END {
                if (NR <= max) { for (i = 1; i <= NR; i++) print l[i]; exit }
                ini = int((max - 1) / 2); fim = max - 1 - ini
                for (i = 1; i <= ini; i++) print l[i]
                printf "[... %d linhas omitidas ...]\n", NR - ini - fim
                for (i = NR - fim + 1; i <= NR; i++) print l[i]
            }'
}

# evidencia_registrar <cenário Tn> <modo kvm|emul> <comando> <arquivo com a saída bruta> <OK|FALHA> <iso> [chave: valor]...
# Grava evidencias/<Tn>/AAAA-MM-DD-<modo>.md e .txt (sufixo -2, -3... se já existirem).
evidencia_registrar() {
    [ $# -ge 6 ] || { echo "FALHA: evidencia_registrar: use 6 argumentos ou mais (iso pode ser vazia)" >&2; return 2; }
    local cen=$1 modo=$2 cmd=$3 bruto=$4 res=$5 iso=$6
    shift 6
    local dir=${EVID_DIR:-$_evid_raiz/evidencias} sha amb data base n=1 m
    [[ $cen =~ ^T[1-7]$ ]] || { echo "FALHA: evidencia_registrar: cenário inválido '$cen'" >&2; return 2; }
    case $modo in kvm | emul) ;; *) echo "FALHA: evidencia_registrar: modo inválido '$modo'" >&2; return 2 ;; esac
    case $res in OK | FALHA) ;; *) echo "FALHA: evidencia_registrar: resultado inválido '$res'" >&2; return 2 ;; esac
    [ -f "$bruto" ] || { echo "FALHA: evidencia_registrar: saída bruta ausente: $bruto" >&2; return 2; }
    sha=${EVID_SHA:-}
    if [ -z "$sha" ]; then
        [ -f "$iso" ] || { echo "FALHA: evidencia_registrar: ISO ausente: $iso" >&2; return 2; }
        sha=$(sha256sum "$iso" | cut -d' ' -f1)
    fi
    if [ "$modo" = kvm ]; then
        amb=${EVID_AMBIENTE:-VM Debian 13 no Hyper-V (QEMU com KVM dentro dela)}
    else
        amb=${EVID_AMBIENTE:-VM Debian 13 no Hyper-V (QEMU dentro dela, sem KVM)}
    fi
    data=$(date +%F)
    mkdir -p "$dir/$cen"
    base="$data-$modo"
    while [ -e "$dir/$cen/$base.md" ] || [ -e "$dir/$cen/$base.txt" ]; do
        n=$((n + 1))
        base="$data-$modo-$n"
    done
    evidencia_sanitizar <"$bruto" >"$dir/$cen/$base.txt"
    {
        echo "# Evidência $cen ($modo)"
        echo
        echo "- Data: $data"
        echo "- ISO (SHA256, 12 primeiros): ${sha:0:12}"
        echo "- Modo: $modo"
        echo "- Ambiente: $amb"
        echo "- Comando: \`$(printf '%s' "$cmd" | evidencia_sanitizar)\`"
        echo "- Resultado: $res"
        echo "- Saída sanitizada: [$base.txt]($base.txt)"
        echo
        echo "## Métricas"
        echo
        if [ $# -eq 0 ]; then echo "- (nenhuma)"; fi
        for m in "$@"; do printf '%s\n' "$m" | evidencia_sanitizar | sed 's/^/- /'; done
    } >"$dir/$cen/$base.md"
    echo "evidência: $dir/$cen/$base.md"
}
