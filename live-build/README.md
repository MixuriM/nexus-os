# live-build

Configuração da ISO do Nexus OS com live-build.

- `auto/config`, `auto/build` e `auto/clean`: scripts que o `lb` chama. Os parâmetros da ISO ficam em `auto/config`.
- `config/package-lists/nexus-base.list.chroot`: pacotes extras da base.
- O restante de `config/` é gerado pelo `lb config` a cada build e está no `.gitignore`.

Não rode o `lb` direto: use `sudo scripts/build-iso.sh` na raiz do repositório, em Linux.
Detalhes, medições e limitações: [docs/iso-poc.md](../docs/iso-poc.md).
