#!/usr/bin/env bash
# Verificação estática do repositório. Roda no Git Bash do Windows e no Linux.
# Cobre arquivos versionados e arquivos novos ainda não ignorados pelo git.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
export LC_ALL=C

# O CR vai numa variável: o bash do Git Bash descarta o CR escrito dentro de <(...).
cr=$(printf '\r')
erros=0
fail() { echo "FALHA: $*" >&2; erros=$((erros + 1)); }

mapfile -d '' todos < <(git ls-files -z --cached --others --exclude-standard)
arquivos=()
for f in "${todos[@]}"; do
    [ -f "$f" ] && arquivos+=("$f")
done
[ ${#arquivos[@]} -gt 0 ] || { echo "FALHA: nenhum arquivo para verificar" >&2; exit 1; }

# 1. CRLF em arquivos de texto (-I ignora binários)
while IFS= read -r f; do
    fail "CRLF (use LF): $f"
done < <(grep -IlU "$cr" -- "${arquivos[@]}" || true)

# 2. Travessão (U+2014) em .md, .sh e .yml
texto=()
for f in "${arquivos[@]}"; do
    case $f in *.md | *.sh | *.yml | *.yaml) texto+=("$f") ;; esac
done
if [ ${#texto[@]} -gt 0 ]; then
    while IFS= read -r f; do
        fail "travessão (U+2014): $f"
    done < <(grep -l $'\xe2\x80\x94' -- "${texto[@]}" || true)
fi

# 3. ISO, .img, .tar ou .deb rastreados
while IFS= read -r f; do
    fail "imagem ou pacote rastreado pelo git: $f"
done < <(git ls-files | grep -iE '\.(iso|img|tar|deb)$' || true)

# 3b. Arquivo da ISO que o .gitignore esconde (o git não o versionaria). Fora: os dois diretórios
# gerados pelo build; dentro de hooks/live só os nexus-* (o resto é link criado pelo lb config).
while IFS= read -r -d '' f; do
    case $f in
        live-build/config/includes.chroot/usr/share/nexus-os/* | live-build/config/includes.chroot/var/lib/nexus-os/*) ;;
        live-build/config/includes.chroot/*) fail "ignorado pelo .gitignore: $f" ;;
        live-build/config/hooks/live/*nexus-*) fail "ignorado pelo .gitignore: $f" ;;
    esac
done < <(git ls-files --others --ignored --exclude-standard -z -- live-build/config/includes.chroot live-build/config/hooks/live)

# 4. Padrões óbvios de segredo (este arquivo define os padrões, então fica de fora)
padrao='-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|(password|passwd|senha|secret|token|api_?key)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_-]{8,}'
alvo=()
for f in "${arquivos[@]}"; do
    [ "$f" = "tests/lint-repo.sh" ] || alvo+=("$f")
done
while IFS= read -r f; do
    fail "possível segredo: $f"
done < <(grep -IliE -- "$padrao" "${alvo[@]}" || true)

# 5. Sintaxe e shellcheck dos scripts (por extensão .sh ou por shebang)
scripts=()
for f in "${arquivos[@]}"; do
    if [[ $f == *.sh ]] || [ "$(head -c 2 "$f")" = '#!' ]; then
        scripts+=("$f")
    fi
done
for f in "${scripts[@]}"; do
    if head -n 1 "$f" | grep -q '^#!/bin/sh'; then
        sh -n "$f" 2>/dev/null || fail "sintaxe (sh -n): $f"
    else
        bash -n "$f" 2>/dev/null || fail "sintaxe (bash -n): $f"
    fi
done
if command -v shellcheck >/dev/null; then
    if [ ${#scripts[@]} -gt 0 ]; then
        shellcheck -x -- "${scripts[@]}" >&2 || fail "shellcheck apontou problemas"
    fi
else
    echo "AVISO: shellcheck não encontrado, etapa pulada" >&2
fi

if [ "$erros" -gt 0 ]; then
    echo "FALHA: $erros problema(s) encontrado(s)" >&2
    exit 1
fi
echo "OK: lint-repo, ${#arquivos[@]} arquivos, ${#scripts[@]} scripts"
