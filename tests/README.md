# Testes

Testes e validações do Nexus OS. Cada script imprime `OK:` ou `FALHA:` e sai com código diferente de zero em falha.

- `lint-repo.sh`: verificação estática (CRLF, travessão, ISO ou `.img` versionados, padrões de segredo, sintaxe e `shellcheck`). Roda no Git Bash do Windows e em Linux.
- `iso.sh <iso>`: confere o SHA256 da ISO e inicia a ISO no QEMU até aparecer `login:`. Precisa de Linux com `qemu-system-x86`.
- `sdn.sh`: laboratório Open vSwitch (bridge `br-nexus` em modo `secure`, namespaces `h1` e `h2`): ping com as regras de `sdn/flows/basico.flows` e sem ping sem elas. Roda com `sudo` na VM Debian.
- `virtualizacao.sh`: registra `vmx/svm` e `/dev/kvm`, define e inicia a VM de `nfv/libvirt/vm-teste.xml` via `virsh` e confirma `running`. Usa emulação por software sem `/dev/kvm`. Roda com `sudo` na VM Debian.
- `nfv.sh`: implanta `labs/containerlab/frr-duo.clab.yml` (dois nós FRR, OSPF área 0), espera até 90 s pela convergência e confere a rota OSPF nos dois nós. Precisa de Docker e Containerlab. Roda com `sudo` na VM Debian.
- `run-fase2.sh [iso]`: roda em ordem `lint-repo`, `iso`, `sdn`, `virtualizacao` e `nfv`, para no primeiro erro com `FALHA:` e imprime um resumo `OK:`/`FALHA:` por teste. A ISO é o argumento ou `dist/nexus-os-poc-amd64.iso`. Usa `sudo` nos três últimos.
