# Integração dos componentes na ISO

Contrato entre a receita do live-build e os componentes da Fase 3. Cada componente entra na ISO por PR, com um teste em `tests/<nome>.sh` que roda **dentro da ISO** pelo runner `nexus-smoke`.

## Layout dentro da ISO

| Caminho na ISO | Origem | Como chega |
| --- | --- | --- |
| `/usr/share/nexus-os/{sdn,nfv,labs,tests,docs}` | cópia das pastas de mesmo nome do repositório | `scripts/stage-iso-files.sh`, chamado por `scripts/build-iso.sh` entre `lb config` e `lb build` |
| `/usr/local/bin/nexus-smoke` | `live-build/config/includes.chroot/usr/local/bin/nexus-smoke` | `includes.chroot` do live-build |
| `/etc/systemd/system/nexus-smoke.service` | `live-build/config/includes.chroot/etc/systemd/system/nexus-smoke.service` | `includes.chroot` |
| `/usr/local/bin/nexus-sdn` | link para `/usr/share/nexus-os/sdn/lab-ovs.sh` | hook `0500-nexus-servicos.hook.chroot` |
| `/usr/local/bin/nexus-vm` | link para `/usr/share/nexus-os/nfv/libvirt/nexus-vm.sh` | hook `0500-nexus-servicos.hook.chroot` |
| `/usr/local/bin/nexus-vnf` | link para `/usr/share/nexus-os/nfv/nexus-vnf.sh` | hook `0500-nexus-servicos.hook.chroot` |
| `/usr/local/bin/nexus-atalho` e `/usr/local/bin/nexus-atalhos-confiar` | `live-build/config/includes.chroot/usr/local/bin/` | `includes.chroot`; o hook dá `chmod 0755` (F3.16, veja [gui.md](gui.md)) |
| `/usr/share/applications/nexus-*.desktop` e `/etc/skel/Desktop/nexus-*.desktop` | `live-build/config/includes.chroot/` | `includes.chroot` (9 atalhos, menu "Nexus OS" e área de trabalho do `user`) |
| `/etc/live/config.conf.d/nexus.conf` | `live-build/config/includes.chroot/etc/live/config.conf.d/nexus.conf` | `includes.chroot` (grupos do usuário `user`, lidos pelo live-config) |
| `/usr/share/nexus-os/tests/smoke.list` | `tests/smoke.list` | cópia de `tests/` |

A pasta gerada `live-build/config/includes.chroot/usr/share/nexus-os/` e `var/lib/nexus-os/` (os `.tar` das imagens de contêiner, gerados pelo `scripts/prepare-offline.sh`, que o `scripts/build-iso.sh` roda depois do stage e antes do `lb build`) estão no `.gitignore`. O resto de `includes.chroot/` e o hook `live-build/config/hooks/live/*nexus-*` são versionados.
O `tests/lint-repo.sh` falha se um arquivo versionável dessas pastas estiver ignorado pelo git.

No live-build instalado na VM de build (`20250505+deb13u1`), `includes.chroot` é aceito como nome antigo de `includes.chroot_after_packages` (função `select_includes_chroot`), desde que a pasta nova esteja vazia. Os hooks `*.hook.chroot` em `config/hooks/live/` rodam depois dos de `config/hooks/normal/`, e o live-build torna o hook executável se ele não for.

## Runner `nexus-smoke`

```bash
sudo nexus-smoke sdn        # um teste
sudo nexus-smoke sdn nfv    # vários, em ordem
sudo nexus-smoke all        # os nomes de /usr/share/nexus-os/tests/smoke.list, um por linha
```

Cada nome roda `/usr/share/nexus-os/tests/<nome>.sh` com `bash`. Teste ausente conta como falha (código 127). O uso manual não desliga a máquina. Só root.

Marcadores impressos (a saída do teste fica entre `BEGIN` e `END`):

```text
NEXUS-SMOKE-BEGIN <nome>
NEXUS-SMOKE-TIME <nome> <segundos>   (informativo)
NEXUS-SMOKE-END <nome> <código>
NEXUS-SMOKE-DONE <total> <falhas>
```

O código de saída do runner é 0 só se `falhas` for 0.

Medição (F3.9, informativa): antes do primeiro teste e depois de cada um o runner imprime a RAM usada, e antes do `DONE` o pico:

```text
NEXUS-SMOKE-MEM <repouso|nome> <MiB>       (coluna "used" do free -m)
NEXUS-SMOKE-DISK <repouso|fim>:<caminho> <MiB>   (df -m, caminhos / e /var/lib/docker)
NEXUS-SMOKE-MEMPEAK <MiB>                  (maior uso visto, amostrado a cada 5 s)
```

O pico pode escapar de um teste mais curto que 5 s. O `tests/iso-smoke.sh` repassa esses valores no `OK:`. Método e números: `requisitos.md`.

## Serviço `nexus-smoke.service`

Habilitado em `multi-user.target`. A condição `ExecCondition=/usr/sbin/blkid -L NEXUS_SMOKE` faz o systemd pular a unidade (sem marcar falha) quando não existe um CD com esse rótulo: o `blkid` sai com 2 e, pelo `man systemd.service`, códigos de 1 a 254 pulam a unidade. Sem o CD o serviço não faz nada.
Com o CD, `nexus-smoke --cd` monta o CD em leitura, lê `testes.txt` (nomes ou `all`), copia `extra/*.sh` do CD para `/usr/share/nexus-os/tests/` (sobrescreve), roda os testes, imprime `DONE` e executa `systemctl --no-block poweroff`.
A saída vai para a serial: o último `console=` da linha de comando do kernel é `console=ttyS0,115200n8`.

Ordenação: o `After=` lista só os serviços de componente existentes (hoje `openvswitch-switch.service`, `libvirtd.service`, `nexus-images.service` e `frr.service`). Não há `After=multi-user.target`, para não criar ciclo com o `WantedBy=`. O desktop (F3.15) não entra no `After=`: o teste `desktop` espera por laço o `lightdm`, a sessão e os processos (veja [gui.md](gui.md)).

## Como rodar no host (VM de build)

```bash
tests/iso-smoke.sh [--extra arq.sh]... <iso> <nome[,nome]...|all>
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn
```

O script cria um CD com `xorriso` (rótulo `NEXUS_SMOKE`, `testes.txt` e `extra/`) em diretório temporário e inicia o QEMU sem interface e sem rede (`-nic none`), com 4096 MiB (`NEXUS_SMOKE_MEM`), 2 vCPU (`NEXUS_SMOKE_SMP`), a ISO e o CD como dois CD-ROMs e a serial em arquivo. Envia Enter pelo monitor (FIFO, sem porta TCP) nos primeiros 60 s, por causa do menu do isolinux. Usa KVM só se `/dev/kvm` for acessível.
Limite de tempo `NEXUS_SMOKE_LIMIT`: 900 s com KVM, 2400 s sem. `NEXUS_SMOKE_KVM=0` força a emulação mesmo com `/dev/kvm` (usado para o teste sem KVM). O QEMU recebe `-vga std` (F3.15), para a sessão gráfica do XFCE subir.
Sai com 0 só se o `DONE` apareceu com 0 falhas, todos os `END` têm código 0 e cada teste pedido tem `END <nome> 0`. Senão imprime `FALHA:` e as últimas 15 linhas da serial. Em sucesso imprime `OK:` com o tempo total e o tempo de cada teste.
`--extra` leva um script para dentro do CD (útil para provar que uma falha é detectada). `NEXUS_SMOKE_SERIAL=<arquivo>` guarda a serial inteira, para diagnóstico: sem isso o script mostra só as últimas 15 linhas.

## Como adicionar um componente

1. Pacotes: crie `live-build/config/package-lists/nexus-<componente>.list.chroot`. Confira o nome com `apt-cache policy` e o que a base já traz em `live-build/chroot.packages.install` do último build.
2. Arquivos do componente: coloque nas pastas do repositório (`sdn/`, `nfv/`, `labs/`, `docs/`). O stage as copia para `/usr/share/nexus-os/`.
3. Teste: `tests/<nome>.sh`, que sai com 0 em sucesso e roda como root dentro da ISO. Acrescente `<nome>` a `tests/smoke.list`.
4. Hook `live-build/config/hooks/live/0500-nexus-servicos.hook.chroot`: acrescente as linhas que habilitam o serviço (`systemctl enable ...`) e criam os links em `/usr/local/bin`.
5. Serviço do componente: acrescente `After=<serviço>` em `nexus-smoke.service`.
6. Rode `sudo scripts/build-iso.sh`, depois `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso <nome>` e `tests/lint-repo.sh`.
7. Atualize a linha do componente na tabela abaixo.

## Componentes

| Componente | Pacotes na ISO | Teste (`tests/<nome>.sh`) | Status |
| --- | --- | --- | --- |
| F3.2 Open vSwitch | `openvswitch-switch` 3.5.0-1+b1 (`iproute2` e `iputils-ping` já vêm na base) | `sdn` | ✅ `iso-smoke` OK sem KVM (119 s) e com KVM no Hyper-V (24 s, 2 vezes); reprodução por segunda pessoa pendente |
| F3.3 KVM/QEMU e libvirt | `libvirt-daemon-system` e `libvirt-clients` 11.3.0-3+deb13u3, `qemu-system-x86` 1:10.0.13+ds-0+deb13u1 (`dnsmasq-base` e `nftables` vêm por dependência) | `virtualizacao`, `libvirt` | ✅ `iso-smoke` OK sem KVM (156 s) e com KVM no Hyper-V (24 s, `virt-type kvm`); reprodução por segunda pessoa pendente; KVM aninhado não funciona no VirtualBox 7.2.20 em AMD (veja [virtualizacao.md](virtualizacao.md)) |
| F3.4 Docker e imagens offline | `docker.io` 26.1.5+dfsg1-9+deb13u1; imagem `quay.io/frrouting/frr:10.7.1` em `/var/lib/nexus-os/images/*.tar`, listada em `live-build/offline/imagens.txt` e preparada por `scripts/prepare-offline.sh` (veja [containers.md](containers.md)) | `containers` | ✅ `iso-smoke` OK com KVM no Hyper-V (30 s, sem rede, driver `overlay2` sobre tmpfs); reprodução por segunda pessoa pendente |
| F3.5 FRRouting | `frr` 10.3-3+deb13u1 (Debian main; a imagem de contêiner é 10.7.1), configuração de exemplo em `nfv/frr/exemplo/` | `frr` | ✅ `iso-smoke` OK com KVM no Hyper-V (1 s, sem rede); reprodução por segunda pessoa pendente (veja [nfv.md](nfv.md)) |
| F3.7 Containerlab | `containerlab` 0.81.1 (`.deb` oficial em `live-build/config/packages.chroot/`, SHA256 em `live-build/offline/containerlab.sha256`) | `nfv` (o `tests/nfv.sh` da F2.7, sem alteração) | ✅ `iso-smoke` OK com KVM no Hyper-V (18 s, sem rede, OSPF convergiu em 12 s); reprodução por segunda pessoa pendente |
| F3.6 Orquestração NFVO/VNFM | nenhum (usa Docker, Containerlab e a imagem FRR já na ISO), script `nfv/nexus-vnf.sh` e topologia `labs/containerlab/vnf-frr.clab.yml` | `orquestracao` | ✅ `iso-smoke` OK com KVM no Hyper-V (9 s, sem rede); `all` com 7 testes OK em 75 s; reprodução por segunda pessoa pendente (veja [nfv.md](nfv.md)) |
| F3.15 e F3.16 Desktop e atalhos | `xfce4`, `lightdm`, `xorg`, `firefox-esr`, `virt-manager` e os demais de `nexus-desktop.list.chroot` (veja [gui.md](gui.md)); 9 atalhos `nexus-*.desktop`, `nexus-atalho` | `desktop` (por último em `smoke.list`) | ✅ `iso-smoke ... all` (8 testes) OK com KVM em 120 s e `desktop` OK sem KVM (477 s com `ram`); ISO de 1260126208 bytes, build de 457 s; reprodução por segunda pessoa pendente |
| F3.9 a F3.11 RC1 | todos os acima | `all` (os 7 testes) | ✅ build limpo em 516 s, 921698304 bytes; `all` OK com KVM em 69 s (4096 MiB) e 73 s (1536 MiB, RAM recomendada); reprodução por segunda pessoa e boot no Hyper-V pendentes (veja [rc1.md](rc1.md) e [requisitos.md](requisitos.md)) |

## Medições (23/10/2026, VM de build sem KVM)

| Item | Valor |
| --- | --- |
| Build da ISO com F3.2 e o runner | 366 s (de `lb clean` até `Build completed successfully`, pelo `build.log`) |
| Tamanho da ISO | 386924544 bytes (a ISO anterior tinha 363855872: +23068672 bytes) |
| SHA256 | `8761d1bce93c4ee1de569ef59304146d40e90d978e7745aee5a4f29040cbd66e` |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn` | `OK: 1 teste(s) sem falha em 119 s`, `sdn=10s`, sem KVM |
| `tests/iso-smoke.sh --extra <link.sh> ... nexus-link,sdn` (1 vCPU, 2048 MiB) | `OK: 2 teste(s) sem falha em 105 s`, `nexus-link=5s`, `sdn=8s`, sem KVM |
| Mutação M1 (`--extra` com `exit 1`) | `FALHA: smoke com falhas: DONE 2 1, END com erro: NEXUS-SMOKE-END falha 1`, código 1 |
| Mutação M2 (`NEXUS_SMOKE_LIMIT=20`) | `FALHA: NEXUS-SMOKE-DONE não apareceu em 20 s`, código 1 |
| Mutação M3 (arquivo ignorado em `includes.chroot/`) | `tests/lint-repo.sh`: `FALHA: ignorado pelo .gitignore`, código 1 |

O nome `nexus-os-poc-amd64.iso` fica até o congelamento da RC1.

## Medições com KVM (23/10/2026, VM Debian 13 no Hyper-V, 4 vCPU e 8 GB)

| Item | Valor |
| --- | --- |
| `tests/iso.sh dist/ref-parte1.iso` | `OK` em 21 s, com KVM |
| `tests/iso-smoke.sh dist/ref-parte1.iso sdn`, 2 execuções, padrão do runner | `OK` em 24 s e 24 s, `sdn=5s` |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso virtualizacao,libvirt` | `OK: 2 teste(s) sem falha em 24 s`, `virtualizacao=2s`, `libvirt=1s`, `virt-type kvm` dentro da ISO |
| `tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn` | `OK` em 27 s, `sdn=7s` |
| Build da ISO nessa VM, com `shellcheck` 0.10.0 no `tests/lint-repo.sh` | `OK: dist/nexus-os-poc-amd64.iso, 688914432 bytes, 348 s`, SHA256 `93eecdf77e1edb4029faed27fafad25083e1c17a1262f8c584ce68ee10e82bc9` (o conteúdo muda a cada build, então o hash difere do da VM do VirtualBox; o tamanho é o mesmo) |
| Mesma ISO: `virtualizacao,libvirt`, `sdn`, `tests/iso.sh` | `OK` em 24 s (`virtualizacao=2s`, `libvirt=1s`), `OK` em 24 s (`sdn=5s`), `OK` em 21 s até o `login:`; todos com KVM |

## Medições da F3.3 (23/10/2026, VM de build sem KVM)

| Item | Valor |
| --- | --- |
| Build da ISO com libvirt | 267 s, `Build completed successfully` |
| Tamanho da ISO | 688914432 bytes (a ISO da parte 1 tinha 386924544: +301989888 bytes) |
| SHA256 | `8e8dd046b49b1e7a101f5329c8f36394c2a30d6e0944a724e3230beec10c16f8` |
| `tests/iso-smoke.sh ... virtualizacao,libvirt` (1 vCPU, 2048 MiB) | `OK: 2 teste(s) sem falha em 156 s`, `virtualizacao=23s`, `libvirt=7s`, sem KVM |
| Antes da correção do autostart | `FALHA: rede default não está ativa`, `NEXUS-SMOKE-END libvirt 1` |
| RED na ISO da parte 1 | `FALHA: virsh não instalado`, `DONE 2 2`, código 1 |
| Regressão `sdn` | `OK: 1 teste(s) sem falha em 144 s`, `sdn=16s`, sem KVM |
| Regressão `tests/iso.sh` | `OK: ISO chegou ao login` em 108 s, sem KVM |
| Mutação M1 (`libvirt.sh` exigindo a rede `outra`) | `FALHA: smoke com falhas: DONE 1 1, END com erro: NEXUS-SMOKE-END libvirt 1` |
| Mutação M2 (`virtualizacao.sh` com `type='invalido'`) | `FALHA: smoke com falhas: DONE 1 1, END com erro: NEXUS-SMOKE-END virtualizacao 1` |

## Medições da F3.5 e F3.7 (25/10/2026, VM Debian 13 no Hyper-V, com KVM, sem rede na ISO)

| Item | Valor |
| --- | --- |
| Build da ISO com `frr` e Containerlab | `OK: dist/nexus-os-poc-amd64.iso, 921698304 bytes, 346 s` (a ISO da parte 3 tinha 893386752: +28311552) |
| SHA256 | `392e651860a1e25c8682befcc42d14319ce5364bd2888aa1004704df016f68ef` |
| RED na ISO da parte 3 (`--extra tests/frr.sh --extra tests/nfv.sh`, `frr,nfv`) | `FALHA: smoke com falhas: DONE 2 2`, `FALHA: vtysh não instalado (pacote frr)`, `FALHA: containerlab não instalado` |
| GREEN `frr,nfv` | `OK: 2 teste(s) sem falha em 48 s`, `frr=1s`, `nfv=18s` |
| `all` (6 testes) | `OK` em 60 s |
| Regressão `sdn,virtualizacao,libvirt,containers` | `OK` em 42 s |
| Mutação M1 (`prepare-offline.sh` com SHA256 `0000...`) | `FALHA: SHA256 de containerlab_0.81.1_linux_amd64.deb diverge`, código 1 |
| Mutação M2 (`--extra` de `frr.sh` esperando o loopback 198.51.100.99/32) | `FALHA: smoke com falhas: DONE 1 1, END com erro: NEXUS-SMOKE-END frr 1` |
| Mutação M3 (`--extra` de `nfv.sh` esperando `198.51.100.9/32`, limite 30 s) | `FALHA: OSPF não convergiu em 30 s`, código 1 |

Detalhes e problemas conhecidos em [nfv.md](nfv.md).

## Problemas conhecidos

- Segurança: o serviço executa como root os scripts `extra/*.sh` do CD `NEXUS_SMOKE`. O `nexus-smoke --cd` só aceita dispositivo `sr*` (CD-ROM), então um pendrive USB com esse rótulo é recusado, mas quem tem acesso físico a uma ISO ligada pode inserir um CD. A ISO serve a laboratório e testes. Para uma ISO de entrega, desabilite `nexus-smoke.service` no hook. Essa restrição entrou depois do build da ISO medida e só será exercitada na próxima reconstrução.
- O stage copia só o que o git versiona ou o que é novo e não ignorado (`git ls-files --cached --others --exclude-standard`). Arquivo ignorado, como um `.log`, não vai para a ISO. Arquivo novo ainda não ignorado e não commitado vai.
- O `.gitignore` ignora `live-build/config/hooks/live/*` (links criados pelo `lb config`) e libera só os nomes com `nexus-`. O hook precisa conter `nexus-` no nome.
- O `scripts/build-iso.sh` roda o stage como root: a pasta gerada pertence ao root depois do build. Rodar o stage à mão como usuário comum falha até alguém apagá-la com `sudo`.
- O tempo de boot sem KVM varia muito (veja [iso-poc.md](iso-poc.md)). O limite padrão do smoke sem KVM é 2400 s.
- Na VM de build (VirtualBox com Hyper-V no Windows), o QEMU sem KVM às vezes sufoca a VM: o kernel dela mostra `soft lockup` de 23 s a 713 s, o SSH deixa de responder e o teste termina em `FALHA: NEXUS-SMOKE-DONE não apareceu`. Aconteceu 5 vezes em 23/10/2026, também durante o `mksquashfs` do build, e uma vez o guest parou em `Bringing up secondary CPUs` com 2 vCPU. Reiniciar a VM resolve. O que funcionou: `NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048 NEXUS_SMOKE_LIMIT=900`, um teste por vez, sem consultar a VM por SSH nos primeiros minutos.
- Com KVM no Hyper-V o smoke padrão (2 vCPU, 4096 MiB) passou 2 vezes seguidas (24 s), então o contorno acima não é necessário lá. No VirtualBox 7.2.20 com AMD o KVM aninhado derruba a VM de build (`VERR_SVM_UNKNOWN_EXIT`): nesse ambiente fica a emulação com o contorno (`NEXUS_SMOKE_SMP=1`, 2048 MiB). Veja [virtualizacao.md](virtualizacao.md).
- Sem rede (`-nic none`) o smoke não baixa nada. Testes que dependam de imagens de contêiner usam as que vão dentro da ISO (F3.4, veja [containers.md](containers.md)).
