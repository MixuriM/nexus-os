# Testes

Testes e validações do Nexus OS. Cada script imprime `OK:` ou `FALHA:` e sai com código diferente de zero em falha.

- `lint-repo.sh`: verificação estática (CRLF, travessão, ISO ou `.img` versionados, padrões de segredo, sintaxe e `shellcheck`). Roda no Git Bash do Windows e em Linux.
- `iso.sh <iso>`: confere o SHA256 da ISO e inicia a ISO no QEMU até aparecer `login:`. Precisa de Linux com `qemu-system-x86`.
