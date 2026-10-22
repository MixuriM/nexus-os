# Modelo de manual

Template para o manual de cada componente do Nexus OS. Copie o bloco do componente, preencha os campos entre `<` e `>` e apague o que não se aplica.
Todo comando e toda saída esperada precisam vir de uma execução real. Não escreva comando, versão ou saída que ninguém executou.

## Estrutura de um manual

1. **Objetivo**: uma frase com o que o leitor consegue fazer ao final.
2. **Pré-requisitos**: sistema, recursos mínimos, pacotes, acesso (root ou `sudo`), internet.
3. **Passos**: numerados. Cada passo tem o comando em bloco de código e a **saída esperada** logo abaixo.
4. **Solução de problemas**: sintoma, causa e correção, uma linha por problema.
5. **Verificação**: o comando que prova que deu certo (de preferência um script de `tests/`) e o código de saída esperado.
6. **Versões medidas**: versão de cada pacote, com o comando usado e a data.

Regras de escrita: português do Brasil, sem travessão, comandos em bloco de código, um passo por ação, sem dado pessoal, senha, chave nem endereço privado.

## Modelo genérico

````markdown
# <Componente>

## Objetivo

<O que o leitor consegue fazer ao final.>

## Pré-requisitos

- <Sistema e versão>
- <Recursos mínimos>
- <Pacotes ou ferramentas>

## Passos

1. <Ação>

   ```bash
   <comando>
   ```

   Saída esperada: `<trecho da saída>`

2. <Ação>

   ```bash
   <comando>
   ```

   Saída esperada: `<trecho da saída>`

## Solução de problemas

| Sintoma | Causa | Correção |
| --- | --- | --- |
| `<mensagem de erro>` | <causa> | <correção> |

## Verificação

```bash
<comando de teste>
```

Saída esperada: `OK: <script>` e código de saída 0.

## Versões medidas (DD/MM/AAAA)

| Item | Comando | Resultado |
| --- | --- | --- |
| <item> | `<comando>` | <versão> |
````

## Bloco: ISO (live-build)

Referência preenchida: [iso-poc.md](iso-poc.md) e [ambiente-de-build.md](ambiente-de-build.md).

| Campo | Conteúdo |
| --- | --- |
| Objetivo | Gerar a ISO `dist/nexus-os-poc-amd64.iso` e confirmar o boot até `login:` |
| Pré-requisitos | VM Debian 13, usuário com `sudo`, 10 GB livres, internet, `live-build`, `qemu-system-x86` |
| Passos | `sudo scripts/build-iso.sh`, depois `tests/iso.sh dist/nexus-os-poc-amd64.iso` |
| Saída esperada | `dist/nexus-os-poc-amd64.iso` e `.sha256`; `OK:` do `tests/iso.sh` |
| Solução de problemas | Log em `live-build/build.log`; build recusado em `/mnt/*` ou sem root |
| Verificação | SHA256 conferido e `login:` na serial |

## Bloco: Open vSwitch (SDN)

Referência preenchida: [sdn.md](sdn.md).

| Campo | Conteúdo |
| --- | --- |
| Objetivo | Encaminhar tráfego entre dois pontos com regras OpenFlow escritas à mão |
| Pré-requisitos | VM Debian 13, `openvswitch-switch`, root |
| Passos | `sudo sdn/lab-ovs.sh up`, depois `sudo ovs-ofctl dump-flows br-nexus` e, ao final, `sudo sdn/lab-ovs.sh down` |
| Saída esperada | `ovs-ofctl dump-flows` lista as regras; o ping entre `h1` e `h2` funciona |
| Solução de problemas | Sem as regras o ping falha (comportamento esperado em modo `secure`) |
| Verificação | `sudo tests/sdn.sh` com saída 0 |

## Bloco: libvirt (virtualização)

Referência preenchida: [virtualizacao.md](virtualizacao.md).

| Campo | Conteúdo |
| --- | --- |
| Objetivo | Definir e iniciar uma VM de teste com `virsh` |
| Pré-requisitos | VM Debian 13, libvirt e QEMU, root; `/dev/kvm` para KVM real |
| Passos | `sudo virsh -c qemu:///system define nfv/libvirt/vm-teste.xml`, depois `start nexus-vm-teste` e `list --all` |
| Saída esperada | `virsh list --all` mostra a VM em `running` |
| Solução de problemas | Sem `/dev/kvm` o teste usa emulação por software, mais lenta |
| Verificação | `sudo tests/virtualizacao.sh` com saída 0 |

## Bloco: Containerlab (FRRouting)

Referência preenchida: [nfv.md](nfv.md).

| Campo | Conteúdo |
| --- | --- |
| Objetivo | Dois nós FRR trocarem rotas por OSPF numa topologia Containerlab |
| Pré-requisitos | VM Debian 13, Docker, Containerlab, root, internet para baixar a imagem FRR |
| Passos | Implantar `labs/containerlab/frr-duo.clab.yml` com `containerlab deploy` |
| Saída esperada | `show ip route ospf` em cada nó mostra o loopback do outro (`O>*`) |
| Solução de problemas | O aviso sobre `vtysh.conf` é inofensivo; OSPF leva alguns segundos para convergir |
| Verificação | `sudo tests/nfv.sh` com saída 0 |
