# RC1 do Nexus OS (F3.10 e F3.11)

Primeira release candidate: o núcleo da stack (Open vSwitch, libvirt e QEMU, Docker com imagem offline, FRRouting, Containerlab e orquestração da VNF), **sem ambiente gráfico**. O desktop entra na RC2. Não há tag Git nesta fase: a tag é do congelamento (F4.6).

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc1-amd64.iso` (cópia da ISO do build limpo, com `.sha256` regenerado para esse nome) |
| Commit do build | `27d2014dd686af8ba67df1ab54c0fd53f0a4e69c` (clone novo de `origin/marcos`) |
| Data | 2026-10-26 |
| Tamanho | 921698304 bytes |
| SHA256 | `6a194300113308bcf340759cd4cd5d5f471a99e7690ef5f378bcce9f97d3bfe1` |
| Tempo do build | 516 s, um comando (`sudo scripts/build-iso.sh`), terminou com `Build completed successfully` |
| Ambiente do build | Debian 13 em VM Hyper-V com KVM, 4 vCPU, 6 GB estáticos, live-build 20250505+deb13u1, QEMU 10.0.13 |
| Onde fica | na máquina do responsável (VM de build, pasta `dist/` do clone, fora do Git) |

Os documentos desta pasta que entram na ISO (`/usr/share/nexus-os/docs`) são os do commit do build. `rc1.md` e `requisitos.md` têm o SHA256 da ISO e por isso nascem depois dela: a ISO não os contém.

## F3.10: build limpo com um comando

Clone novo de `origin/marcos` em pasta nova, depois só `sudo scripts/build-iso.sh` (ordem interna: `lb clean`, `lb config`, `scripts/stage-iso-files.sh`, `scripts/prepare-offline.sh`, `lb build`). Medido nesse build:

| Item | Valor |
| --- | --- |
| Tempo | 516 s (de 20:17 a 20:26, com o clone) |
| Disco ocupado ao fim | 5383 MiB (pasta do clone; `live-build/` tem 4504 MiB, dos quais `chroot` 2551, `cache` 879 e `binary` 879) |
| RAM usada no pico do build | 1332 MiB (amostra a cada 5 s; o mínimo de RAM disponível foi 4598 MiB na VM de 5930 MiB) |
| Internet | o build baixa o `.deb` do Containerlab (26197450 bytes) e os pacotes do Debian; a imagem FRR já estava no Docker da VM |

Revisão da receita (nada precisou ser corrigido): cinco listas `nexus-*.list.chroot` (base, containers, frr, sdn, virt), o hook `0500-nexus-servicos.hook.chroot` (habilita `openvswitch-switch`, `libvirtd`, `docker`, `nexus-images`, `frr` e `nexus-smoke`, cria os links `nexus-sdn`, `nexus-vm`, `nexus-vnf`), `.gitignore` e `scripts/build-iso.sh`. Dentro da ISO, `systemd-analyze verify` de `nexus-smoke.service`, `nexus-images.service`, `var-lib-docker.mount` e `docker.service` saiu com código 0 e sem aviso; os seis serviços estão `enabled` e os cinco comandos em `/usr/local/bin` existem e são executáveis.

## F3.11: validação em VM limpa

"VM limpa" é o guest QEMU que inicia a ISO do zero a cada execução (live, sem persistência, sem rede). Todas as execuções abaixo foram **com KVM** (VM de build no Hyper-V, `/dev/kvm` presente) e usam a ISO do build limpo.

| Teste | Resultado |
| --- | --- |
| `tests/iso.sh` (boot até `login:`) | `OK` em 27 s e em 28 s, SHA256 conferido |
| `tests/iso-smoke.sh <iso> all`, `NEXUS_SMOKE_MEM=4096` | `OK: 7 teste(s) sem falha em 69 s` (`sdn` 6 s, `virtualizacao` 2 s, `libvirt` 1 s, `containers` 2 s, `frr` 1 s, `nfv` 19 s, `orquestracao` 9 s); pico de RAM 813 MiB |
| `tests/iso-smoke.sh <iso> all`, `NEXUS_SMOKE_MEM=1536` (RAM recomendada) | `OK: 7 teste(s) sem falha em 73 s`; pico de RAM 637 MiB |
| `tests/run-fase2.sh <iso>` (regressão) | `OK: tests/run-fase2.sh (5 testes)` em 54 s: lint, iso, sdn, virtualizacao e nfv |
| Mínimo do smoke `containers` | 1024 e 896 MiB passam (2 de 2); 768 MiB falha (2 de 2). Veja [requisitos.md](requisitos.md) |

Requisitos de hardware: [requisitos.md](requisitos.md) (recomendado 1536 MiB de RAM). Esta validação fecha o item "boot em KVM" da F2.4 para a RC1. A reprodução por uma segunda pessoa e a premissa 1 nas máquinas dos demais integrantes continuam pendentes: nada daqui conta como tal.

## Boot no Hyper-V

Evidência complementar e manual (não bloqueia a F3.11). A ISO tem boot BIOS (isolinux) e UEFI (`/boot/grub/efi.img`), conferido com `xorriso -indev <iso> -report_el_torito plain`. O caminho validado em QEMU é o BIOS, então a VM de laboratório é de **Geração 1**; o boot UEFI não foi testado. Procedimento (PowerShell como administrador no Windows, ISO copiada da VM de build para `C:\HyperV`, fora do repositório):

```powershell
$vm = "nexus-rc1-lab"
New-VM -Name $vm -Generation 1 -MemoryStartupBytes 4096MB -BootDevice CD -NoVHD
Set-VMProcessor -VMName $vm -Count 2
Set-VMMemory -VMName $vm -DynamicMemoryEnabled $false -StartupBytes 4096MB
Add-VMDvdDrive -VMName $vm -Path "C:\HyperV\nexus-os-rc1-amd64.iso"
Start-VM -Name $vm
vmconnect.exe localhost $vm
```

Sem `-SwitchName`, a VM não fica ligada a nenhuma rede (comportamento do `New-VM` na documentação da Microsoft). No console: Enter no menu do isolinux, login `user` e senha `live` (credencial pública da Debian Live), e então:

```bash
sudo nexus-smoke all > /tmp/smoke.txt 2>&1
grep -a -e NEXUS-SMOKE-END -e NEXUS-SMOKE-DONE -e NEXUS-SMOKE-MEMPEAK /tmp/smoke.txt
free -m
```

Resultado da rodada no Hyper-V: **não executado**.

## Riscos conhecidos

- `nexus-smoke.service` fica na RC1 porque é com ele que a RC1 é validada. Ele só age quando existe um CD `sr*` com o rótulo `NEXUS_SMOKE` e roda **como root** o que houver nesse CD (`testes.txt` e `extra/*.sh`). Quem tem acesso físico a uma ISO ligada (ou à configuração da VM) pode inserir esse CD e executar código. A decisão de removê-lo ou de condicioná-lo a um argumento da linha de comando do kernel fica para o congelamento (F4.6); ele não foi alterado nesta fase (issue #32).
- Credencial de laboratório da Debian Live: usuário `user`, senha `live`, `sudo` sem senha. A ISO é de laboratório e demonstração, sem hardening de produção.

## Limitações

- Medições e testes **com KVM** apenas; a emulação por software não foi repetida nesta parte.
- O boot em UEFI e em máquina física não foi testado; o Hyper-V ainda não rodou a RC1.
- Os 7 smokes rodam sem rede e dentro do QEMU; a orquestração e o laboratório de rede usam a imagem FRR embutida.
- A RAM em repouso varia com a RAM do guest e o pico é amostrado a cada 5 s (veja [requisitos.md](requisitos.md)).
- Sem ambiente gráfico (RC2).

## Problemas conhecidos

- Abaixo de cerca de 896 MiB de RAM o `docker load` do `nexus-images.service` falha por falta de espaço no tmpfs do Docker (`size=50%`), e o smoke `containers` dá `FALHA`. Issue #31.
- Ao desligar, a live pode parar em `Please remove the live-medium, close the tray (if any) and press ENTER to continue:`, visto na serial de um smoke com 896 MiB. Issue #34.
- Para rodar `tests/run-fase2.sh` na VM de build, instale antes `openvswitch-switch`, `iproute2` e `iputils-ping` ([sdn.md](sdn.md)); sem isso o `tests/sdn.sh` dá `FALHA: ovs-vsctl não instalado`.
