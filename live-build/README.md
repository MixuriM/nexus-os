# live-build

Configuração da ISO do Nexus OS com live-build.

- `auto/config`, `auto/build` e `auto/clean`: scripts que o `lb` chama. Os parâmetros da ISO ficam em `auto/config`.
- `config/package-lists/nexus-<componente>.list.chroot`: pacotes da base e de cada componente (um arquivo por componente).
- `config/includes.chroot/`: arquivos copiados para a ISO (`nexus-smoke`, `nexus-smoke.service`). A subpasta `usr/share/nexus-os/` é gerada por `scripts/stage-iso-files.sh` e está no `.gitignore`.
- `config/hooks/live/0500-nexus-servicos.hook.chroot`: habilita os serviços e cria os links dos comandos.
- O restante de `config/` é gerado pelo `lb config` a cada build e está no `.gitignore`.

Contrato de integração: [docs/integracao-iso.md](../docs/integracao-iso.md).

Não rode o `lb` direto: use `sudo scripts/build-iso.sh` na raiz do repositório, em Linux.
Detalhes, medições e limitações: [docs/iso-poc.md](../docs/iso-poc.md).
