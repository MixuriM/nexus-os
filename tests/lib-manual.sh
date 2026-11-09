#!/usr/bin/env bash
# Extrai os blocos "bash nexus-exec" do docs/manual.md (F3.12 e F4.2e). Para usar com "source".
# manual_extrair <manual> [seção]: imprime o script dos blocos, em ordem, cada um precedido de
# echo "MANUAL-BLOCO n" e o conjunto terminado por echo "MANUAL-FIM n". Com [seção], só os blocos da seção
# "## <seção>" (até o próximo "## "; os "###" fazem parte dela). Códigos: 0 ok, 3 seção inexistente, 4 sem bloco.
manual_extrair() {
    awk -v sec="${2:-}" '
        BEGIN { na_secao = (sec == "") }
        /^```/ {
            if (cerca) { cerca = 0; dentro = 0 }
            else {
                cerca = 1
                if (na_secao && $0 ~ /^```bash nexus-exec[[:space:]]*$/) { dentro = 1; n++; printf "echo \"MANUAL-BLOCO %d\"\n", n }
            }
            next
        }
        !cerca && /^## / { na_secao = (sec == "" || $0 == "## " sec); if (sec != "" && na_secao) achou = 1 }
        dentro { print }
        END {
            printf "echo \"MANUAL-FIM %d\"\n", n
            if (sec != "" && !achou) exit 3
            if (n == 0) exit 4
        }
    ' "$1"
}
