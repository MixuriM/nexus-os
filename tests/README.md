# Testes

Testes e validações do Nexus OS. Cada script imprime `OK:` ou `FALHA:` e sai com código diferente de zero em falha.

- `lint-repo.sh`: verificação estática (CRLF, travessão, ISO ou `.img` versionados, padrões de segredo, sintaxe e `shellcheck`). Roda no Git Bash do Windows e em Linux.
- `iso.sh <iso>`: confere o SHA256 da ISO e inicia a ISO no QEMU até aparecer `login:`. Precisa de Linux com `qemu-system-x86`.
- `sdn.sh`: laboratório Open vSwitch (bridge `br-nexus` em modo `secure`, namespaces `h1` e `h2`): ping com as regras de `sdn/flows/basico.flows` e sem ping sem elas. Roda com `sudo` na VM Debian.
- `virtualizacao.sh`: registra `vmx/svm` e `/dev/kvm`, define e inicia a VM de `nfv/libvirt/vm-teste.xml` via `virsh` e confirma `running`. Usa emulação por software sem `/dev/kvm`. Roda com `sudo` na VM Debian.
- `nfv.sh`: implanta `labs/containerlab/frr-duo.clab.yml` (dois nós FRR, OSPF área 0), espera até 90 s pela convergência e confere a rota OSPF nos dois nós. Precisa de Docker e Containerlab. Roda com `sudo` na VM Debian.
- `iso-smoke.sh [--extra arq.sh]... <iso> <nome[,nome]...|all>`: inicia a ISO no QEMU sem rede com um CD `NEXUS_SMOKE` que pede ao `nexus-smoke` da ISO para rodar os testes de `smoke.list` (`sdn`, `virtualizacao` e `libvirt`) e confere os marcadores `NEXUS-SMOKE-*` na serial. Precisa de `qemu-system-x86` e `xorriso`; limite `NEXUS_SMOKE_LIMIT` (900 s com KVM, 2400 s sem). Veja [docs/integracao-iso.md](../docs/integracao-iso.md).
- `libvirt.sh`: só dentro da ISO (`nexus-smoke libvirt`): confere a rede `default` ativa e com autostart, o usuário `user` no grupo `libvirt` e o ciclo `nexus-vm criar`, `running`, `nexus-vm remover`.
- `smoke.list`: nomes dos testes que o `nexus-smoke all` roda dentro da ISO, um por linha, em ordem.
- `run-fase2.sh [iso]`: roda em ordem `lint-repo`, `iso`, `sdn`, `virtualizacao` e `nfv`, para no primeiro erro com `FALHA:` e imprime um resumo `OK:`/`FALHA:` por teste. A ISO é o argumento ou `dist/nexus-os-poc-amd64.iso`. Usa `sudo` nos três últimos.
