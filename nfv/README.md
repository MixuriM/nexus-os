# NFV

KVM/QEMU + libvirt como VIM, FRRouting como VNF de exemplo.
Orquestração NFVO/VNFM representada de forma simplificada.

- `libvirt/vm-teste.xml`: domínio de teste do `virsh` (sem disco, 128 MiB).
- `frr/exemplo/`: `daemons` e `frr.conf` de exemplo do FRR do pacote (roteador `ex1`, loopback 198.51.100.10/32 em OSPF área 0), aplicados pelo smoke `frr`.

Status: libvirt validado em VM Debian 13, em emulação por software (F2.6). Passos em [docs/virtualizacao.md](../docs/virtualizacao.md). Teste: `sudo tests/virtualizacao.sh`.
O FRRouting com Containerlab foi validado em [labs/containerlab/](../labs/containerlab/README.md) (F2.7). Passos em [docs/nfv.md](../docs/nfv.md). Teste: `sudo tests/nfv.sh`.
Na ISO (F3.5 e F3.7): pacote `frr` e Containerlab 0.81.1 incluídos, smokes `frr` e `nfv` passam com KVM e sem rede (seção "Na ISO" de [docs/nfv.md](../docs/nfv.md)). Topologia na ISO: `sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml`. Reprodução por segunda pessoa pendente.

## Orquestração (F3.6)

`nexus-vnf.sh` é o NFVO/VNFM simplificado do Nexus OS: um script único que instancia, consulta e remove a VNF FRR. Sem Ansible.

Infraestrutura usada: **Containerlab com contêiner FRR** (Docker, imagem `quay.io/frrouting/frr:10.7.1`). O libvirt não participa da orquestração nesta fase: ele segue como VIM de máquinas virtuais pelo `nexus-vm` (F3.3).

- Script no repositório: `nfv/nexus-vnf.sh`. Na ISO: `sudo nexus-vnf up|status|down` (link criado pelo hook para `/usr/share/nexus-os/nfv/nexus-vnf.sh`).
- Topologia: `labs/containerlab/vnf-frr.clab.yml`, um nó `vnf1` (contêiner `clab-vnf-frr-vnf1`) com a configuração de `labs/containerlab/configs/vnf1/`: loopback 198.51.100.11/32 em OSPF área 0.

| Comando | Efeito | Saída |
| --- | --- | --- |
| `up` | implanta a topologia e espera o FRR responder (até 60 s); se a VNF já está rodando, avisa e não recria | 0 em sucesso, 1 em falha |
| `status` | imprime o estado do contêiner, a primeira linha de `show version` e o loopback configurado | 0 se a VNF está rodando, 1 se não está |
| `down` | destrói a topologia com `--cleanup` e confere que nenhum contêiner nem a rede `clab` sobrou; pode repetir | 0 em sucesso, 1 em falha |
| outro argumento | imprime a ajuda | 2 |

Todos exigem root. Mensagens começam com `OK:` ou `FALHA:`. Teste: `sudo tests/orquestracao.sh` (na VM de laboratório) ou o smoke `orquestracao` na ISO. Detalhes em [docs/nfv.md](../docs/nfv.md).
