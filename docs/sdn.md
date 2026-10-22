# SDN: Open vSwitch com regras OpenFlow manuais

Laboratório da F2.5: uma bridge Open vSwitch sem controlador, em modo `secure`, com dois pontos de teste. As regras são escritas à mão e carregadas com `ovs-ofctl`.
Controlador SDN (OpenDaylight): opcional, fora desta fase.

## Resultado (22/10/2026)

| Item | Valor |
| --- | --- |
| Ambiente | VM Debian 13 (trixie), sem KVM, kernel e pacotes do Debian |
| Open vSwitch | 3.5.0 (`ovs-vsctl --version`), pacote `openvswitch-switch` 3.5.0-1+b1 |
| Bridge | `br-nexus`, `fail_mode=secure`, nenhum controlador |
| Pontos de teste | namespaces `h1` (192.0.2.1/24) e `h2` (192.0.2.2/24), ligados por pares veth nas portas OpenFlow 1 e 2 |
| Regras | `sdn/flows/basico.flows`, 4 regras (ARP e ICMP nos dois sentidos) |
| Teste | `sudo tests/sdn.sh`: `OK: tests/sdn.sh (4 regras, ping com regras, sem ping sem regras)`, código 0 |
| Memória do Open vSwitch ativo | `ovsdb-server` 9 MB e `ovs-vswitchd` 7 a 12 MB de RSS; `free -m` com o serviço parado e iniciado: 524 MB e 534 MB usados |

Os endereços 192.0.2.0/24 são o bloco reservado para documentação (RFC 5737), usado só dentro dos namespaces.

## Como funciona

No modo `secure` e sem controlador, a bridge não instala nenhuma regra por conta própria: sem regras, descarta tudo.
Por isso o ping de `h1` para `h2` só funciona por causa das regras de `sdn/flows/basico.flows`.

```text
h1 (eth0) --veth-- h1-br [porta 1] br-nexus [porta 2] h2-br --veth-- (eth0) h2
```

## Passos

Na raiz do repositório, na VM Debian:

```bash
sudo apt install openvswitch-switch iproute2 iputils-ping
sudo sdn/lab-ovs.sh up
```

`up` cria a bridge, os namespaces, os veth e carrega as regras. Para conferir:

```bash
sudo ovs-vsctl get-fail-mode br-nexus
sudo ovs-ofctl dump-flows br-nexus
sudo ip netns exec h1 ping -c 2 192.0.2.2
```

Saída esperada: `secure`, as 4 regras com `n_packets` maior que zero nas regras usadas, e `0% packet loss` no ping.

Para provar que as regras é que encaminham o tráfego:

```bash
sudo ovs-ofctl del-flows br-nexus
sudo ip netns exec h1 ping -c 2 -W 2 192.0.2.2   # falha: 100% packet loss
sudo sdn/lab-ovs.sh flows                        # recarrega as regras
```

Para desmontar tudo:

```bash
sudo sdn/lab-ovs.sh down
```

O teste automatizado faz esse roteiro inteiro (caso positivo, caso negativo, recarga e limpeza):

```bash
sudo tests/sdn.sh
```

## Problemas conhecidos

- O `ovs-vsctl` e o `ovs-ofctl` precisam de root (o socket do `ovsdb-server` não é acessível a usuário comum). Todos os comandos usam `sudo`.
- O `n_packets` do `dump-flows` pode ficar abaixo do número de pacotes enviados, porque parte do tráfego passa pelo cache do datapath. O teste exige apenas `n_packets` maior que zero.
- A medição de memória por `free -m` inclui o ruído dos outros serviços da VM (libvirt e Docker estavam ativos). O RSS dos dois processos é a medida mais direta.
- Sem controlador não há aprendizado de MAC nem regras dinâmicas: cada novo ponto de teste exige regras novas no arquivo `.flows`.
