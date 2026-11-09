#!/usr/bin/env bash
# Verificação estática da base dos testes funcionais (F4.1): plano de testes, modelo e índice de evidências,
# sanitização e registro da tests/lib-evidencia.sh, runner da Fase 4 e varredura de dado pessoal em evidencias/.
# Estático: roda no Git Bash e no Linux. Uso: tests/evidencias.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
export LC_ALL=C

erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

plano=docs/plano-de-testes.md
modelo=evidencias/MODELO.md
indice=evidencias/README.md
lib=tests/lib-evidencia.sh
runner=tests/run-fase4.sh

# Varredura de dado pessoal independente da biblioteca: imprime as linhas suspeitas dos arquivos dados.
# HOSTS_EXTRA acrescenta nomes de máquina à lista (usado no teste da sanitização).
varrer() {
    local ip='(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'
    local mail='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
    local win='[A-Za-z]:\\Users\\|[A-Za-z]:/Users/|/[a-z]/Users/'
    local h hosts=${HOSTS_EXTRA:-}
    h=$(hostname 2>/dev/null || true)
    case $h in nexus-os | localhost | debian | "") ;; *) [ ${#h} -ge 4 ] && hosts="$hosts $h" ;; esac
    grep -IEn -- "$ip" "$@" 2>/dev/null
    grep -IEn -- "$mail" "$@" 2>/dev/null
    grep -IEn -- "$win" "$@" 2>/dev/null
    grep -IEn -- 'mshome\.net' "$@" 2>/dev/null
    grep -IEn -- '/home/' "$@" 2>/dev/null | grep -vE '/home/(user|<usuario>)([^[:alnum:]_.-]|$)'
    for h in $hosts; do grep -IFn -- "$h" "$@" 2>/dev/null; done
    return 0
}

# (a) plano de testes: quatro seções fixas e os rótulos da D9 para T1 a T7
rotulos=("Objetivo" "Pré-condições" "Executor" "Comando" "Critério de sucesso" "Métricas" "Evidência esperada")
if [ ! -f "$plano" ]; then
    fail "$plano ausente"
else
    for s in "Ambiente e ISO sob teste" "Regras de evidência" "Cenários" "Fora do escopo"; do
        grep -qx "## $s" "$plano" || fail "$plano: seção '## $s' ausente"
    done
    grep -q 'RC2' "$plano" || fail "$plano: não registra a ISO RC2 sob teste"
    for n in 1 2 3 4 5 6 7; do
        bloco=$(awk -v t="### T$n" 'index($0, t) == 1 { f = 1; next } /^##/ { f = 0 } f' "$plano")
        if [ -z "$bloco" ]; then
            fail "$plano: subseção '### T$n' ausente"
            continue
        fi
        for r in "${rotulos[@]}"; do
            grep -q "^- \*\*$r:\*\*" <<<"$bloco" || fail "$plano: T$n sem o rótulo '$r'"
        done
        grep -q "tests/cenario-t$n.sh" <<<"$bloco" || fail "$plano: T$n não cita tests/cenario-t$n.sh"
    done
fi

# (b) modelo e índice de evidências
[ -f "$modelo" ] || fail "$modelo ausente"
if [ -f "$indice" ]; then
    for n in 1 2 3 4 5 6 7; do
        grep -q "^| T$n |" "$indice" || fail "$indice: linha da tabela de T$n ausente"
    done
else
    fail "$indice ausente"
fi

# (c) biblioteca: sanitização e registro
if [ ! -f "$lib" ]; then
    fail "$lib ausente"
else
    # shellcheck source=/dev/null
    . "$lib"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    host_falso=vm-lab-xyzzy01
    printf '%s\n' \
        'ip 10.1.2.3 e 172.20.5.6 e 192.168.1.9' \
        'mail fulano@exemplo.com.br' \
        'caminho C:\Users\Marcos Castelli\Documents\x' \
        'casa /home/fulano/x' \
        "host $host_falso fim" \
        'publico 8.8.8.8 e 172.32.0.1 e /home/user/ok' >"$tmp/bruto"
    printf 'com cr\r\n' >>"$tmp/bruto"
    EVID_HOSTNAMES=$host_falso evidencia_sanitizar <"$tmp/bruto" >"$tmp/san"
    for t in 10.1.2.3 172.20.5.6 192.168.1.9 fulano 'C:\Users' 'Marcos Castelli' "$host_falso"; do
        ! grep -qF -- "$t" "$tmp/san" || fail "sanitização deixou '$t'"
    done
    for t in 8.8.8.8 172.32.0.1 /home/user/ok; do
        grep -qF -- "$t" "$tmp/san" || fail "sanitização apagou '$t', que é público"
    done
    ! grep -q "$(printf '\r')" "$tmp/san" || fail "sanitização deixou CR"
    HOSTS_EXTRA=$host_falso varrer "$tmp/san" | grep -q . && fail "varredura achou dado pessoal na saída sanitizada"
    seq 1 1000 | evidencia_sanitizar >"$tmp/longo"
    [ "$(wc -l <"$tmp/longo")" -le 300 ] || fail "saída sanitizada passa de 300 linhas"
    grep -q 'omitidas' "$tmp/longo" || fail "corte de linhas não indicado"
    if ! { grep -qx 1 "$tmp/longo" && grep -qx 1000 "$tmp/longo"; }; then fail "corte não preserva início e fim"; fi

    sha=$(printf 'ab%.0s' {1..32})
    ev="$tmp/ev"
    hoje=$(date +%F)
    EVID_DIR=$ev EVID_SHA=$sha evidencia_registrar T1 kvm "tests/cenario-t1.sh iso" "$tmp/bruto" OK "" "tempo_login_s: 27" >/dev/null ||
        fail "evidencia_registrar T1 kvm terminou com erro"
    EVID_DIR=$ev EVID_SHA=$sha evidencia_registrar T1 kvm "tests/cenario-t1.sh iso" "$tmp/bruto" FALHA "" >/dev/null ||
        fail "evidencia_registrar T1 kvm (segunda) terminou com erro"
    for f in "$ev/T1/$hoje-kvm.md" "$ev/T1/$hoje-kvm.txt" "$ev/T1/$hoje-kvm-2.md" "$ev/T1/$hoje-kvm-2.txt"; do
        [ -f "$f" ] || fail "evidencia_registrar não gravou $f"
    done
    grep -q '^- ISO (SHA256, 12 primeiros): abababababab$' "$ev/T1/$hoje-kvm.md" 2>/dev/null ||
        fail "evidência sem os 12 primeiros caracteres do SHA256"
    grep -q '^- tempo_login_s: 27$' "$ev/T1/$hoje-kvm.md" 2>/dev/null || fail "evidência sem a métrica"
    EVID_DIR=$ev EVID_SHA=$sha evidencia_registrar T9 kvm c "$tmp/bruto" OK "" 2>/dev/null &&
        fail "evidencia_registrar aceitou cenário inválido"
    EVID_DIR=$ev EVID_SHA=$sha evidencia_registrar T1 xyz c "$tmp/bruto" OK "" 2>/dev/null &&
        fail "evidencia_registrar aceitou modo inválido"
    EVID_DIR=$ev EVID_SHA=$sha evidencia_registrar T1 kvm c "$tmp/bruto" TALVEZ "" 2>/dev/null &&
        fail "evidencia_registrar aceitou resultado inválido"
fi

# (d) runner da Fase 4
if [ -f "$runner" ]; then
    for n in 1 2 3 4 5 6 7; do
        grep -q "cenario-t$n.sh" "$runner" || fail "$runner não cita cenario-t$n.sh"
    done
else
    fail "$runner ausente"
fi

# D11: evidencias/ com .md, .txt e .png não é ignorada pelo .gitignore
for ext in md txt png; do
    ! git check-ignore -q "evidencias/T1/amostra.$ext" || fail ".gitignore ignora evidencias/T1/amostra.$ext"
done

# (e) arquivos de evidência: até 1 MiB, campos da D10 nos .md e nenhum dado pessoal
campos=(
    '^- Data: [0-9]{4}-[0-9]{2}-[0-9]{2}$'
    '^- ISO \(SHA256, 12 primeiros\): [0-9a-f]{12}$'
    '^- Modo: (kvm|emul)$'
    '^- Ambiente: .+'
    '^- Comando: .+'
    '^- Resultado: (OK|FALHA)$'
    '^- Saída sanitizada: \[.+\]\(.+\)$'
    '^## Métricas$'
)
# Rodada humana (humano-AAAA-MM-DD.md): campos próprios, sem comando nem saída sanitizada.
campos_humano=(
    '^- Data: [0-9]{4}-[0-9]{2}-[0-9]{2}$'
    '^- ISO \(SHA256, 12 primeiros\): [0-9a-f]{12}( .*)?$'
    '^- Ambiente: .+'
    '^- Executor: .+'
    '^- Resultado: (OK|FALHA|parcial)( .*)?$'
)
if [ -d evidencias ]; then
    while IFS= read -r -d '' f; do
        [ "$(wc -c <"$f")" -le 1048576 ] || fail "$f passa de 1 MiB"
        if [[ $f == evidencias/T[1-7]/humano-*.md ]]; then
            for c in "${campos_humano[@]}"; do
                grep -qE -- "$c" "$f" || fail "$f sem o campo /$c/"
            done
        elif [[ $f == evidencias/T[1-7]/*.md && $f != */lacunas.md ]]; then
            for c in "${campos[@]}"; do
                grep -qE -- "$c" "$f" || fail "$f sem o campo /$c/"
            done
            ref=$(sed -n 's/^- Saída sanitizada: \[.*\](\(.*\))$/\1/p' "$f")
            [ -z "$ref" ] || [ -f "$(dirname "$f")/$ref" ] || fail "$f referencia $ref, que não existe"
        fi
    done < <(find evidencias -type f -print0)
    mapfile -t textos < <(find evidencias -type f ! -name '*.png')
    if [ ${#textos[@]} -gt 0 ]; then
        achados=$(varrer "${textos[@]}")
        [ -z "$achados" ] || fail "dado pessoal em evidencias/: $achados"
    fi
fi

if [ "$erros" -gt 0 ]; then
    echo "FALHA: $erros problema(s) em tests/evidencias.sh" >&2
    exit 1
fi
echo "OK: tests/evidencias.sh (plano T1 a T7, modelo, índice, sanitização, registro, runner e varredura)"
