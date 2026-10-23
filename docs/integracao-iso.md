# Integração dos componentes na ISO

Contrato entre a receita do live-build e os componentes da Fase 3. Cada componente entra na ISO por PR, com um teste em `tests/<nome>.sh` que roda **dentro da ISO** pelo runner `nexus-smoke`.

## Layout dentro da ISO

| Caminho na ISO | Origem | Como chega |
| --- | --- | --- |
| `/usr/share/nexus-os/{sdn,nfv,labs,tests,docs}` | cópia das pastas de mesmo nome do repositório | `scripts/stage-iso-files.sh`, chamado por `scripts/build-iso.sh` entre `lb config` e `lb build` |
| `/usr/local/bin/nexus-smoke` | `live-build/config/includes.chroot/usr/local/bin/nexus-smoke` | `includes.chroot` do live-build |
| `/etc/systemd/system/nexus-smoke.service` | `live-build/config/includes.chroot/etc/systemd/system/nexus-smoke.service` | `includes.chroot` |
| `/usr/local/bin/nexus-sdn` | link para `/usr/share/nexus-os/sdn/lab-ovs.sh` | hook `0500-nexus-servicos.hook.chroot` |
| `/usr/share/nexus-os/tests/smoke.list` | `tests/smoke.list` | cópia de `tests/` |

A pasta gerada `live-build/config/includes.chroot/usr/share/nexus-os/` (e `var/lib/nexus-os/`, reservada) está no `.gitignore`. O resto de `includes.chroot/` e o hook `live-build/config/hooks/live/*nexus-*` são versionados.
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

## Serviço `nexus-smoke.service`

Habilitado em `multi-user.target`. A condição `ExecCondition=/usr/sbin/blkid -L NEXUS_SMOKE` faz o systemd pular a unidade (sem marcar falha) quando não existe um CD com esse rótulo: o `blkid` sai com 2 e, pelo `man systemd.service`, códigos de 1 a 254 pulam a unidade. Sem o CD o serviço não faz nada.
Com o CD, `nexus-smoke --cd` monta o CD em leitura, lê `testes.txt` (nomes ou `all`), copia `extra/*.sh` do CD para `/usr/share/nexus-os/tests/` (sobrescreve), roda os testes, imprime `DONE` e executa `systemctl --no-block poweroff`.
A saída vai para a serial: o último `console=` da linha de comando do kernel é `console=ttyS0,115200n8`.

Ordenação: o `After=` lista só os serviços de componente existentes (hoje `openvswitch-switch.service`). Não há `After=multi-user.target`, para não criar ciclo com o `WantedBy=`.

## Como rodar no host (VM de build)

```bash
tests/iso-smoke.sh [--extra arq.sh]... <iso> <nome[,nome]...|all>
tests/iso-smoke.sh dist/nexus-os-poc-amd64.iso sdn
```

O script cria um CD com `xorriso` (rótulo `NEXUS_SMOKE`, `testes.txt` e `extra/`) em diretório temporário e inicia o QEMU sem interface e sem rede (`-nic none`), com 4096 MiB (`NEXUS_SMOKE_MEM`), 2 vCPU (`NEXUS_SMOKE_SMP`), a ISO e o CD como dois CD-ROMs e a serial em arquivo. Envia Enter pelo monitor (FIFO, sem porta TCP) nos primeiros 60 s, por causa do menu do isolinux. Usa KVM só se `/dev/kvm` for acessível.
Limite de tempo `NEXUS_SMOKE_LIMIT`: 900 s com KVM, 2400 s sem.
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
| F3.2 Open vSwitch | `openvswitch-switch` 3.5.0-1+b1 (`iproute2` e `iputils-ping` já vêm na base) | `sdn` | ✅ `iso-smoke` OK sem KVM (119 s); reprodução por segunda pessoa pendente |
| F3.3 libvirt | | `virtualizacao` | ⏳ parte 2 |
| F3.4 Docker e imagens offline | | | ⏳ parte 3 |
| F3.5 FRRouting | | `nfv` | ⏳ parte 4 |
| F3.7 Containerlab | | `nfv` | ⏳ parte 4 |

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

## Problemas conhecidos

- Segurança: o serviço executa como root os scripts `extra/*.sh` do CD `NEXUS_SMOKE`. O `nexus-smoke --cd` só aceita dispositivo `sr*` (CD-ROM), então um pendrive USB com esse rótulo é recusado, mas quem tem acesso físico a uma ISO ligada pode inserir um CD. A ISO serve a laboratório e testes. Para uma ISO de entrega, desabilite `nexus-smoke.service` no hook. Essa restrição entrou depois do build da ISO medida e só será exercitada na próxima reconstrução.
- O stage copia só o que o git versiona ou o que é novo e não ignorado (`git ls-files --cached --others --exclude-standard`). Arquivo ignorado, como um `.log`, não vai para a ISO. Arquivo novo ainda não ignorado e não commitado vai.
- O `.gitignore` ignora `live-build/config/hooks/live/*` (links criados pelo `lb config`) e libera só os nomes com `nexus-`. O hook precisa conter `nexus-` no nome.
- O `scripts/build-iso.sh` roda o stage como root: a pasta gerada pertence ao root depois do build. Rodar o stage à mão como usuário comum falha até alguém apagá-la com `sudo`.
- O tempo de boot sem KVM varia muito (veja [iso-poc.md](iso-poc.md)). O limite padrão do smoke sem KVM é 2400 s.
- Na VM de build (VirtualBox com Hyper-V no Windows), o QEMU sem KVM às vezes sufoca a VM: o kernel dela mostra `soft lockup` de 23 s a 713 s, o SSH deixa de responder e o teste termina em `FALHA: NEXUS-SMOKE-DONE não apareceu`. Aconteceu 5 vezes em 23/10/2026, também durante o `mksquashfs` do build, e uma vez o guest parou em `Bringing up secondary CPUs` com 2 vCPU. Reiniciar a VM resolve. O que funcionou: `NEXUS_SMOKE_SMP=1 NEXUS_SMOKE_MEM=2048 NEXUS_SMOKE_LIMIT=900`, um teste por vez, sem consultar a VM por SSH nos primeiros minutos.
- Sem rede (`-nic none`) o smoke não baixa nada. Testes que dependam de imagens de contêiner precisam delas dentro da ISO (parte 3).
