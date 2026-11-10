# SDN: Open vSwitch com regras OpenFlow manuais

Laboratório da F2.5: uma bridge Open vSwitch sem controlador, em modo `secure`, com dois pontos de teste. As regras são escritas à mão e carregadas com `ovs-ofctl`. Controlador SDN (OpenDaylight): opcional, fora desta fase.

Este documento foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**. **O que é:** o Open vSwitch é um switch virtual; **SDN** (redes definidas por software) separa a decisão de encaminhar da caixa que encaminha; **OpenFlow** é o protocolo das regras (por exemplo "pacote ARP que entra na porta 1 sai na porta 2"). Aqui as regras são escritas à mão, sem controlador.

## Sumário

1. [Resultado](#resultado-22102026)
2. [Como funciona](#como-funciona)
3. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
4. [O que você precisa ter antes](#o-que-você-precisa-ter-antes)
5. [Passos](#passos)
6. [Na ISO (F3.2)](#na-iso-f32)
7. [Problemas conhecidos](#problemas-conhecidos)
8. [Como relatar uma falha](#como-relatar-uma-falha)

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

## Regras que valem o tempo todo

1. **Faça só o que está escrito aqui** e confira o "Deve aparecer" de cada passo antes de seguir.
2. **Todos os comandos do Open vSwitch usam `sudo`:** o socket do `ovsdb-server` não é acessível a usuário comum.
3. **Limpe no fim** (`sudo sdn/lab-ovs.sh down`): sobras de uma tentativa causam falhas na seguinte.
4. **O repositório é público:** nunca cole em issue senha, chave, token ou dado pessoal.

## O que você precisa ter antes

| # | Item | Por quê | Como conseguir |
| --- | --- | --- | --- |
| 1 | Uma VM ou máquina **Debian 13** com `sudo` | O laboratório usa namespaces de rede e o Open vSwitch | Veja [ambiente-de-build.md](ambiente-de-build.md) |
| 2 | O repositório clonado | Os scripts `sdn/lab-ovs.sh` e `sdn/flows/basico.flows` estão nele | `git clone https://github.com/MixuriM/nexus-os.git` e `cd nexus-os` |
| 3 | Os pacotes `openvswitch-switch`, `iproute2` e `iputils-ping` | São o switch, o comando `ip netns` e o `ping` | Passo 1 |

## Passos

**Onde:** na raiz do repositório, na VM Debian, num terminal.

### Passo 1: instalar os pacotes e criar o laboratório

**O que fazer:**

```bash
sudo apt install openvswitch-switch iproute2 iputils-ping
sudo sdn/lab-ovs.sh up
```

**Por quê:** a primeira linha instala o Open vSwitch e as ferramentas de rede. O `up` cria a bridge `br-nexus`, os namespaces `h1` e `h2` (dois "computadores" isolados), os pares veth que os ligam à bridge e carrega as regras de `sdn/flows/basico.flows`.

**Deve aparecer:** o `apt` termina sem erro e o `up` termina sem mensagem de falha.

**Se não aparecer:** `E: Unable to locate package` indica que faltou `sudo apt update`. Sobra de uma tentativa anterior (`File exists`): rode `sudo sdn/lab-ovs.sh down` e repita o `up`.

### Passo 2: conferir o laboratório

**O que fazer:**

```bash
sudo ovs-vsctl get-fail-mode br-nexus
sudo ovs-ofctl dump-flows br-nexus
sudo ip netns exec h1 ping -c 2 192.0.2.2
```

**Por quê:** o primeiro comando mostra o modo da bridge; o segundo lista as regras com os contadores; o terceiro faz `h1` dar `ping` em `h2` (192.0.2.2).

**Deve aparecer:** `secure`, as 4 regras com `n_packets` maior que zero nas regras usadas, e `0% packet loss` no ping.

**Se não aparecer:** `100% packet loss` indica que as regras não foram carregadas: `sudo sdn/lab-ovs.sh flows`.

### Passo 3: provar que as regras é que encaminham o tráfego

**O que fazer:**

```bash
sudo ovs-ofctl del-flows br-nexus
sudo ip netns exec h1 ping -c 2 -W 2 192.0.2.2   # falha: 100% packet loss
sudo sdn/lab-ovs.sh flows                        # recarrega as regras
```

**Por quê:** `del-flows` apaga todas as regras; sem regra, no modo `secure`, a bridge descarta tudo e o ping **tem** de falhar; `lab-ovs.sh flows` as recarrega. **Deve aparecer:** `100% packet loss` no segundo comando. **Se não aparecer:** se o ping passar sem regras, a bridge não está em `secure`: relate.

### Passo 4: desmontar tudo

**O que fazer:**

```bash
sudo sdn/lab-ovs.sh down
```

**Por quê:** remove a bridge, os namespaces e os veth. **Deve aparecer:** nenhuma mensagem de falha.

### Passo 5: rodar o teste automatizado

O teste faz esse roteiro inteiro (caso positivo, caso negativo, recarga e limpeza):

```bash
sudo tests/sdn.sh
```

**Deve aparecer:** `OK: tests/sdn.sh (4 regras, ping com regras, sem ping sem regras)`, código 0. **Se não aparecer:** a mensagem `FALHA:` diz qual etapa falhou; relate com ela.

## Na ISO (F3.2)

**O que é:** a ISO traz o pacote `openvswitch-switch` e o serviço do Open vSwitch habilitado no boot. O repositório vai para `/usr/share/nexus-os/` e o comando `nexus-sdn` aponta para `sdn/lab-ovs.sh`.

**Onde:** num terminal da ISO, logado como `user` (senha `live`, a credencial pública do Debian Live).

**O que fazer:**

```bash
sudo nexus-sdn up
sudo ip netns exec h1 ping -c 2 192.0.2.2
sudo nexus-sdn down
```

**Por quê:** é o mesmo roteiro da VM de build, com o comando da ISO. **Deve aparecer:** `0% packet loss` no ping, como na VM de build. **Se não aparecer:** `sudo nexus-sdn down` e repita; relate com a saída.

O mesmo teste roda dentro da ISO, sem rede e sem interface, pelo smoke test (veja [integracao-iso.md](integracao-iso.md)), na VM de build:

```bash
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn
```

**Deve aparecer:** `OK: 1 teste(s) sem falha em <segundos> s`.

| Item | Valor (23/10/2026, sem KVM) |
| --- | --- |
| Resultado | `OK: 1 teste(s) sem falha em 119 s`, código 0 |
| Tempo do `tests/sdn.sh` dentro da ISO | 10 s (`sdn=10s`) |
| ISO | 386924544 bytes, SHA256 `8761d1bce93c4ee1de569ef59304146d40e90d978e7745aee5a4f29040cbd66e` |

Reprodução por segunda pessoa: pendente.

## Problemas conhecidos

- O `ovs-vsctl` e o `ovs-ofctl` precisam de root (o socket do `ovsdb-server` não é acessível a usuário comum). Todos os comandos usam `sudo`.
- O `n_packets` do `dump-flows` pode ficar abaixo do número de pacotes enviados, porque parte do tráfego passa pelo cache do datapath. O teste exige apenas `n_packets` maior que zero.
- A medição de memória por `free -m` inclui o ruído dos outros serviços da VM (libvirt e Docker estavam ativos). O RSS dos dois processos é a medida mais direta.
- Sem controlador não há aprendizado de MAC nem regras dinâmicas: cada novo ponto de teste exige regras novas no arquivo `.flows`.

## Como relatar uma falha

**Quando:** para cada falha que se repete, para qualquer erro de comando deste documento e para tudo que ele não explicou. **Onde:** uma **issue** no repositório no GitHub. **Título:** `<tarefa>: <passo>: <resumo curto>`. **Corpo:** **Passos** (comandos exatos), **Saída** (texto exato copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (Debian, versão do Open vSwitch, com ou sem KVM, commit). Uma issue por falha, sem dado pessoal.
