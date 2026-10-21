#!/usr/bin/env bash
# Sincroniza a marcos e as branches pessoais com a main, depois de um "Rebase and merge".
# Uso: scripts/sync-branches.sh   (só o revisor final, com bypass de admin na marcos)
#
# Sempre age no repositório onde o script está, não no diretório atual, e só se o origin for o nexus-os.
set -uo pipefail

pessoais=(renato giulliano gudryan jean sayuri)

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
case $(git remote get-url origin 2>/dev/null) in
    */nexus-os | */nexus-os.git) ;;
    *) echo "FALHA: o origin deste clone não é o nexus-os" >&2; exit 1 ;;
esac

git fetch origin --prune || exit 1
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "FALHA: working tree com alterações, faça commit ou stash antes" >&2
    exit 1
fi

# 1. marcos: só realinha se TODOS os commits dela já estão na main (git cherry mostra '-').
#    Se aparecer '+', há trabalho que a main não tem: não mexe.
if git cherry origin/main origin/marcos | grep -q '^+' \
    || git cherry origin/main marcos | grep -q '^+'; then
    echo "AVISO: a marcos tem commits que a main não tem; pulei a marcos"
elif git push --force-with-lease="marcos:$(git rev-parse origin/marcos)" origin origin/main:refs/heads/marcos; then
    if [ "$(git branch --show-current)" = marcos ]; then
        git reset --hard origin/main
    else
        git branch -f marcos origin/main
    fi
    echo "OK: marcos = main"
else
    echo "FALHA: não consegui atualizar a marcos"
fi

# 2. pessoais: avança por fast-forward, sem checkout e sem merge local.
#    O servidor recusa o que não for fast-forward (essas branches não têm bypass).
for b in "${pessoais[@]}"; do
    if git push origin "origin/main:refs/heads/$b"; then
        echo "OK: $b"
    else
        echo "AVISO: $b não é fast-forward (tem commits próprios); sincronizar na mão"
    fi
done
