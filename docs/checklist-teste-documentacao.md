# Checklist de teste da documentação (F2.8 e F3.12)

Roteiro para quem nunca viu o projeto. O objetivo é descobrir se o `README.md` e os documentos de `docs/` bastam para gerar e testar a ISO do zero, **sem ajuda e sem conhecimento prévio**.

Regra principal: siga **somente** o que está escrito no repositório. Se precisar de algo que não está escrito (um pacote, um comando, uma explicação), isso é uma falha da documentação: anote e abra uma issue. Não conserte em silêncio.

Tempo estimado: 1 h de preparo e cerca de 30 min de build, mais 15 min de testes. Reserve uma tarde.

## Parte A: ficha do teste

Preencha ao longo do teste (copie esta ficha para um arquivo seu; não commite o arquivo com dados pessoais).

| Campo | Valor |
| --- | --- |
| Data do teste (DD/MM/AAAA) | |
| Branch e commit testados (`git rev-parse --short HEAD`) | |
| Máquina física (sistema, RAM, CPU) | |
| Programa de VM e versão | |
| Recursos da VM (vCPU, RAM, disco) | |
| Debian da VM (`cat /etc/debian_version`) | |
| Hora de início e de fim do `scripts/build-iso.sh` | |
| Saída do `scripts/build-iso.sh` (código de saída) | |
| SHA256 obtido (`cat dist/nexus-os-poc-amd64.iso.sha256`) | |
| Tamanho da ISO em bytes (`stat -c %s dist/nexus-os-poc-amd64.iso`) | |
| Resultado de `tests/iso.sh` (última linha impressa) | |
| Tempo até `login:` informado pelo teste | |
| Resultado de `tests/lint-repo.sh` (última linha) | |
| Resultado final (passou, passou com ressalvas, falhou) | |

## Parte B: preparar uma VM Debian 13 limpa

"Limpa" quer dizer recém-instalada, sem nada do projeto. Use o que o repositório pede em [ambiente-de-build.md](ambiente-de-build.md).

| # | O que fazer | Onde | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| B1 | Instalar um programa de VM (VirtualBox) na sua máquina | Sua máquina | | |
| B2 | Baixar a ISO netinst do Debian 13 em https://www.debian.org/releases/stable/ e conferir o SHA256 com o arquivo `SHA256SUMS` do site | Navegador e terminal | | |
| B3 | Criar a VM com 4 vCPU, 8 GB de RAM e disco de 80 GB (mínimo 40 GB), rede NAT | Programa de VM | | |
| B4 | Instalar o Debian: disco inteiro, **sem** ambiente gráfico, marcando só "SSH server" e "standard system utilities". Se pedir senha de root, deixe vazia para criar o `sudo` ao usuário comum | Janela da VM | | |
| B5 | Entrar na VM com o usuário comum e confirmar a versão: `cat /etc/debian_version` (deve começar com 13) | Terminal da VM | | |
| B6 | Instalar os pacotes da seção "Preparar a VM para o build" de `docs/ambiente-de-build.md`. Se `sudo` pedir senha e você não souber a regra, anote como falha de documentação | Terminal da VM | | |

Como saber se o B6 deu certo: `lb --version` imprime uma versão e `git --version` também. Se aparecer `command not found`, o pacote não foi instalado.

## Parte C: clonar e seguir só o README

Abra o `README.md` do repositório (no navegador, em https://github.com/MixuriM/nexus-os) e siga a seção **"Como gerar a ISO"** passo a passo. Não use o que você já sabe de outros projetos.

| # | Passo do README | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- |
| C1 | Passo 1: `git clone` e `cd nexus-os`. Anote o commit com `git rev-parse --short HEAD` | | |
| C2 | Passo 2: `sudo scripts/build-iso.sh`. Anote a hora de início. O comando fica 20 a 30 minutos sem imprimir muito: espere. Anote a hora de fim e o código de saída (`echo $?` logo depois) | | |
| C3 | Conferir os arquivos: `ls -l dist/` deve listar `nexus-os-poc-amd64.iso` e `nexus-os-poc-amd64.iso.sha256` | | |
| C4 | Anotar o SHA256 (`cat dist/nexus-os-poc-amd64.iso.sha256`) e o tamanho (`stat -c %s dist/nexus-os-poc-amd64.iso`) na ficha | | |
| C5 | Passo 3: `tests/iso.sh dist/nexus-os-poc-amd64.iso`. Sem `/dev/kvm` o teste leva de 2 a 15 minutos. A última linha deve começar com `OK:` | | |
| C6 | Passo 4: `tests/lint-repo.sh`. A última linha deve começar com `OK:` | | |
| C7 | Conferir se `docs/iso-poc.md` descreve o que você viu (tamanho, tempo, limitações). Anote diferenças | | |

Comparação com o autor: o hash da ISO **pode ser diferente** do registrado em `docs/iso-poc.md`, porque cada build gera o seu. Diferença de hash não é falha. Falha é o `tests/iso.sh` não passar.

## Parte D: componentes (opcional, só se o Marcos pedir)

Os guias estão em [sdn.md](sdn.md), [virtualizacao.md](virtualizacao.md) e [nfv.md](nfv.md). Para rodar tudo em sequência: `tests/run-fase2.sh dist/nexus-os-poc-amd64.iso`. O teste de NFV precisa de Docker e Containerlab, que os documentos explicam como instalar. Registre cada falha do mesmo modo.

| # | Teste | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- |
| D1 | `sudo tests/sdn.sh` | | |
| D2 | `sudo tests/virtualizacao.sh` | | |
| D3 | `sudo tests/nfv.sh` | | |

## Parte E: como registrar uma falha

Cada falha vira **uma issue**. O que conta como falha:

- um comando do repositório termina com erro;
- a saída é diferente da descrita na documentação;
- você precisou de algo que a documentação não diz;
- um passo é ambíguo e você teve que adivinhar.

Para abrir: página do repositório no GitHub, aba **Issues**, botão **New issue**.

- **Título:** `F2.8: <resumo curto da falha>` (por exemplo, `F2.8: build-iso.sh falha por falta de pacote`). Use `F2.3` se a falha for do build e `F2.4` se for do boot da ISO.
- **Corpo**, com estes quatro blocos:

  ```
  Passos: o que você fez, em ordem, com os comandos digitados.
  Saída: as últimas linhas da saída (copie e cole, sem editar).
  Esperado: o que a documentação dizia que aconteceria.
  Ambiente: sistema, versão do Debian, RAM, commit testado.
  ```

- Antes de colar a saída, **apague** qualquer senha, chave, token, nome de usuário pessoal ou endereço de e-mail. O repositório é público.
- Se não houver nenhuma falha, não abra issue: marque "passou" na ficha.

## Parte F: o que devolver ao Marcos

1. A ficha da Parte A preenchida.
2. As tabelas B, C e (se feita) D com passou ou falhou.
3. Os números das issues abertas.
4. O resultado final: **passou**, **passou com ressalvas** ou **falhou**.

Com isso o Marcos registra a reprodução por segunda pessoa de F2.3 e F2.4 e fecha F2.8.

## Parte G: Manual v1 por componente (F3.12)

Roteiro para executar o [manual v1](manual.md) do zero, numa ISO limpa, **sem conhecimento prévio do projeto**. Cada seção do manual (uma por componente) tem aqui os passos, o que deve aparecer e um campo "passou ou falhou". O objetivo é descobrir se o manual basta para usar cada componente da ISO sem ajuda.

Regra principal: digite somente o que está escrito aqui e no manual. Se precisar de algo que não está escrito (um pacote, um comando, uma explicação), isso é uma falha da documentação: anote e abra uma issue. Não conserte em silêncio.

Tempo estimado: 30 min para preparar a máquina e 1 h 30 min para as seções. Reserve uma tarde.

### G0: o que você precisa ter antes

| # | Item | Como conseguir |
| --- | --- | --- |
| G0.1 | A ISO `nexus-os-rc1-amd64.iso` e o SHA256 dela | Peça ao Marcos o arquivo. O SHA256 correto está em `docs/rc1.md`, tabela "Identificação", linha "SHA256". Se preferir gerar a ISO, siga as partes B e C (o arquivo sai com o nome `nexus-os-poc-amd64.iso`) |
| G0.2 | Uma máquina que rode a ISO com **2048 MiB de RAM** livres para a VM | Veja a escolha abaixo |
| G0.3 | Este repositório aberto no navegador: https://github.com/MixuriM/nexus-os, arquivo `docs/manual.md` | Navegador |

Escolha **um** destes ambientes e anote qual na ficha G6:

- **Hyper-V no Windows 11 Pro** (sem KVM, mais lento, mas é o caminho validado para Windows): siga G1-A.
- **Linux com QEMU e `/dev/kvm`** (mais rápido): siga G1-B.
- **VirtualBox**: só funciona sem KVM, então é o mais lento. Crie uma VM Linux de 64 bits com 2048 MiB, sem disco, a ISO no leitor óptico, e siga G2 em diante.

### G1-A: Hyper-V no Windows (PowerShell como administrador)

1. Copie a ISO para `C:\HyperV` (crie a pasta se não existir). Onde: Explorador de Arquivos.
2. Confira o SHA256 da ISO. Onde: PowerShell. Comando:

   ```powershell
   Get-FileHash C:\HyperV\nexus-os-rc1-amd64.iso -Algorithm SHA256
   ```

   O valor `Hash` deve ser igual ao SHA256 de `docs/rc1.md` (a comparação ignora maiúsculas e minúsculas). Se for diferente, pare: a ISO está corrompida ou é outra. Anote como falha de G0.1.
3. Crie e inicie a VM. Onde: PowerShell como administrador, um comando por vez (o mesmo bloco de `docs/manual.md`, seção "Iniciar a ISO"):

   ```powershell
   $vm = "nexus-rc1-lab"
   New-VM -Name $vm -Generation 1 -MemoryStartupBytes 4096MB -BootDevice CD -NoVHD
   Set-VMProcessor -VMName $vm -Count 2
   Set-VMMemory -VMName $vm -DynamicMemoryEnabled $false -StartupBytes 4096MB
   Add-VMDvdDrive -VMName $vm -Path "C:\HyperV\nexus-os-rc1-amd64.iso"
   Start-VM -Name $vm
   vmconnect.exe localhost $vm
   ```

   Deve abrir uma janela com a tela do isolinux. Se algum comando der erro, copie a mensagem e abra uma issue (G5).
4. Ao terminar tudo, apague a VM (PowerShell): `Stop-VM -Name nexus-rc1-lab -TurnOff` e depois `Remove-VM -Name nexus-rc1-lab -Force`.

### G1-B: Linux com QEMU

1. Confira o SHA256 (terminal), na pasta onde está a ISO: `sha256sum nexus-os-rc1-amd64.iso`. Compare com `docs/rc1.md`.
2. Confira o KVM: `ls -l /dev/kvm`. Se existir, use o comando com KVM; se não, tire `-enable-kvm -cpu host` e anote "sem KVM".
3. Inicie a ISO (terminal):

   ```bash
   qemu-system-x86_64 -enable-kvm -cpu host -m 2048 -smp 2 -cdrom nexus-os-rc1-amd64.iso -boot d
   ```

   Deve abrir uma janela com a tela do isolinux.

### G2: entrar na ISO

| # | O que fazer | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G2.1 | Na tela do isolinux (fundo escuro com um menu), aperte **Enter** | Mensagens de boot rolando e, em até 5 min sem KVM (cerca de 30 s com KVM), um prompt de texto | | |
| G2.2 | Se o prompt for `login:`, digite `user`, Enter, e depois `live`, Enter. A senha não aparece enquanto você digita. Se já aparecer um prompt terminando em `$`, não digite nada | Um prompt terminando em `$` | | |
| G2.3 | Digite `cat /etc/debian_version` e Enter | Um número começando com `13` | | |
| G2.4 | Digite `grep -o boot=live /proc/cmdline` e Enter | `boot=live` | | |

Dica: digite os comandos; copiar e colar no console pode não funcionar. Confira cada comando antes de apertar Enter.

### G3: seções do manual, uma por componente

Para cada linha: digite o comando na ISO, compare com "O que deve aparecer" e marque. Se a saída for diferente, é falha de documentação ou do componente: anote o texto exato. **Faça as seções na ordem**, e termine cada uma antes de começar a próxima. O comando `echo $?` imprime o código de saída do comando anterior (0 é sucesso).

**Seção "Open vSwitch (nexus-sdn)"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.1 | `sudo nexus-sdn up` e depois `echo $?` | Sem mensagem de erro; o `echo` imprime `0` | | |
| G3.2 | `sudo ovs-vsctl get-fail-mode br-nexus` | `secure` | | |
| G3.3 | `sudo ovs-ofctl dump-flows br-nexus` | Quatro linhas de regras (ARP e ICMP nos dois sentidos) | | |
| G3.4 | `sudo ip netns exec h1 ping -c 2 192.0.2.2` | `0% packet loss` | | |
| G3.5 | `sudo ovs-ofctl del-flows br-nexus` e depois `sudo ip netns exec h1 ping -c 2 -W 2 192.0.2.2` | `100% packet loss` (sem regras a bridge descarta tudo) | | |
| G3.6 | `sudo nexus-sdn flows` e depois o ping do G3.4 de novo | `0% packet loss` | | |
| G3.7 | `sudo nexus-sdn down`, depois `sudo ovs-vsctl list-br` e `sudo ip netns list` | Os dois últimos comandos não imprimem nada | | |

**Seção "libvirt (nexus-vm)"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.8 | `nexus-vm criar manual1` (sem `sudo`) | `OK: VM manual1 criada e iniciada (virt-type kvm)`, ou `virt-type qemu` se a ISO está sem KVM | | |
| G3.9 | `nexus-vm listar` | Uma linha com `manual1` e o estado `running` (ou `executando`, se o sistema estiver em português) | | |
| G3.10 | `LC_ALL=C virsh -c qemu:///system domstate manual1` | `running` | | |
| G3.11 | `nexus-vm remover manual1` e depois `nexus-vm listar` | `OK: VM manual1 removida`; a lista fica sem `manual1` | | |

**Seção "Contêineres e imagens offline"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.12 | `sudo systemctl is-active nexus-images.service` | `active` | | |
| G3.13 | `sudo docker info --format '{{.Driver}}'` | `overlay2` | | |
| G3.14 | `sudo docker image ls` | Uma linha com `quay.io/frrouting/frr` e a tag `10.7.1` | | |
| G3.15 | `sudo docker run --rm --network none --entrypoint /usr/lib/frr/zebra quay.io/frrouting/frr:10.7.1 --version` | `zebra version 10.7.1_git` | | |

**Seção "FRRouting"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.16 | `sudo systemctl is-active frr` | `active` | | |
| G3.17 | `sudo vtysh -c 'show version'` | Primeira linha começando com `FRRouting 10.3` | | |
| G3.18 | `mkdir -p /tmp/frr-orig && sudo cp -a /etc/frr/daemons /etc/frr/frr.conf /tmp/frr-orig/` | Sem mensagem | | |
| G3.19 | `sudo install -m 0640 -o frr -g frr /usr/share/nexus-os/nfv/frr/exemplo/daemons /etc/frr/daemons`, depois o mesmo para `frr.conf`, e `sudo systemctl restart frr` | Sem mensagem de erro | | |
| G3.20 | Espere 20 s e rode `sudo vtysh -c 'show running-config'` | A saída contém `ip address 198.51.100.10/32` e `router ospf` | | |
| G3.21 | Restaure: `sudo cp -a /tmp/frr-orig/daemons /tmp/frr-orig/frr.conf /etc/frr/` e `sudo systemctl restart frr` | Sem mensagem de erro | | |

**Seção "Containerlab"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.22 | `sudo containerlab deploy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml` | Uma tabela com os contêineres `clab-frr-duo-r1` e `clab-frr-duo-r2` em `running`. Sem rede aparece `Failed fetching latest version information`: é esperado | | |
| G3.23 | Espere 30 s. `sudo docker exec clab-frr-duo-r1 vtysh -c 'show ip route ospf'` | Uma linha `O>* 198.51.100.2/32`. O aviso sobre `vtysh.conf` é inofensivo. Se a rota não aparecer, espere mais 30 s e repita | | |
| G3.24 | `sudo docker exec clab-frr-duo-r2 vtysh -c 'show ip route ospf'` | Uma linha `O>* 198.51.100.1/32` | | |
| G3.25 | `sudo containerlab destroy -t /usr/share/nexus-os/labs/containerlab/frr-duo.clab.yml --cleanup` e depois `sudo docker ps -a` | A lista de contêineres fica vazia | | |

**Seção "Orquestração (nexus-vnf)"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.26 | `sudo nexus-vnf up` e depois `echo $?` | Uma linha começando com `OK:`; o `echo` imprime `0` | | |
| G3.27 | `sudo nexus-vnf status` e depois `echo $?` | `contêiner: clab-vnf-frr-vnf1 (running)`, `loopback: 198.51.100.11/32` e `OK: VNF vnf1 rodando`; o `echo` imprime `0` | | |
| G3.28 | `sudo nexus-vnf down`, depois `sudo nexus-vnf status; echo $?` | `OK:` no `down`; o último `echo` imprime `1` | | |

**Seção "Testes (nexus-smoke)"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.29 | `sudo nexus-smoke all > /tmp/smoke.txt 2>&1; echo $?` (leva cerca de 70 s com KVM e vários minutos sem) | O `echo` imprime `0` | | |
| G3.30 | `grep -a -e NEXUS-SMOKE-END -e NEXUS-SMOKE-DONE /tmp/smoke.txt` | Sete linhas `NEXUS-SMOKE-END <nome> 0` e `NEXUS-SMOKE-DONE 7 0` | | |

**Seção "Requisitos"**

| # | Comando | O que deve aparecer | Passou ou falhou | O que aconteceu e saída |
| --- | --- | --- | --- | --- |
| G3.31 | `free -m` | A coluna `used` (ou `usado`) na ordem de grandeza de `docs/requisitos.md`; a RAM em repouso varia entre execuções. Anote o valor | | |
| G3.32 | Leia a seção "Solução de problemas" do manual e diga se o texto bastaria para resolver o problema mais provável que você viu hoje | Uma frase sua | | |

### G4: seções que não são comandos

| # | O que ler | A pergunta | Passou ou falhou | Observação |
| --- | --- | --- | --- | --- |
| G4.1 | Seção "Visão geral" | Você entende o que o Nexus OS é e o que a ISO traz, sem outro documento? | | |
| G4.2 | Seção "Gerar a ISO" | Os links levam ao que a seção promete? | | |
| G4.3 | Seção "Iniciar a ISO" | O texto bastou para iniciar a ISO (G1)? Faltou algum passo? | | |
| G4.4 | Seção "Login de laboratório" | O usuário e a senha funcionaram? | | |

### G5: como abrir uma issue de falha

Valem as regras da Parte E. Diferenças para o manual v1:

- **Título:** `F3.12: <seção do manual>: <resumo curto>`, por exemplo `F3.12: Containerlab: rota OSPF não apareceu em 60 s`.
- **Corpo:** os mesmos quatro blocos (Passos, Saída, Esperado, Ambiente). Em "Ambiente" informe: o ambiente escolhido em G0 (Hyper-V, QEMU ou VirtualBox), se tinha KVM, a RAM da VM, o SHA256 da ISO e o commit de `docs/manual.md`.
- Uma issue por falha. Falha intermitente (passou na segunda vez) também vira issue, com o número de tentativas.
- Antes de colar a saída, apague qualquer senha pessoal, chave, token, nome de usuário pessoal ou e-mail. O repositório é público.

### G6: ficha do teste do manual

| Campo | Valor |
| --- | --- |
| Data do teste (DD/MM/AAAA) | |
| Ambiente (Hyper-V, QEMU ou VirtualBox) e versão | |
| Com KVM ou sem KVM (`ls -l /dev/kvm` no host) | |
| RAM e vCPU da VM | |
| SHA256 da ISO conferido (sim ou não) | |
| Commit de `docs/manual.md` (campo "Commit" da página no GitHub) | |
| Resultado por seção (passou, passou com ressalvas ou falhou) | |
| Resultado final | |

### G7: o que devolver ao Marcos

1. A ficha G6 preenchida.
2. As tabelas G2, G3 e G4 com passou ou falhou e o que apareceu.
3. Os números das issues abertas.
4. O resultado final: **passou**, **passou com ressalvas** ou **falhou**.

Com isso o Marcos registra a execução do manual v1 por uma segunda pessoa (F3.12).
