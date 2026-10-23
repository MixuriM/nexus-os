# ISO da prova de conceito

Base Debian 13 (trixie) sem a stack de rede. Serve para validar o pipeline de build (F2.3) e o boot (F2.4).
Nenhum pacote de Open vSwitch, libvirt, FRRouting, Docker ou Containerlab entra nesta ISO.

## Resultado (21/10/2026)

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-poc-amd64.iso` (fora do Git) |
| Tamanho | 363855872 bytes (347 MiB) |
| SHA256 | `3d31ecb586aaf3d29ea677952875dfb35bd00ac72940c7b223f42efa66725350` |
| Tempo de build | 1374 s (cerca de 23 min), em VM com 4 vCPU e 8 GB de RAM |
| Boot até `login:` | `debian login: ` na serial, sem KVM (veja abaixo) |
| Reprodução por segunda pessoa | pendente |

O hash vale só para a ISO medida nesta data. A igualdade de hash entre builds diferentes não foi testada: cada build gera o seu próprio `.sha256`.

## Validação em clone limpo pelo autor (22/10/2026)

Não vale como reprodução por segunda pessoa: quem validou é o autor do build. A reprodução por segunda pessoa segue pendente ([checklist-teste-documentacao.md](checklist-teste-documentacao.md)).

| Item | Valor |
| --- | --- |
| Ambiente | VM Debian 13 no VirtualBox (4 vCPU, 8 GB), clone novo de `origin/marcos` no commit `c201c42`, sem `/dev/kvm` |
| Passos | os do `README.md`: `sudo scripts/build-iso.sh` e `tests/iso.sh` |
| Build | saída 0, 399 s (o primeiro build levou 1374 s; a causa da diferença não foi diagnosticada) |
| Tamanho | 363855872 bytes (igual ao build anterior) |
| SHA256 | `bb79026c02ded030efdf037ff58fcc1ccf5ca08e23fd934c609a264ac086aad2` (difere do build de 21/10/2026, como esperado: cada build gera o seu) |
| `tests/run-fase2.sh` | `OK` nos 5 testes (`lint-repo`, `iso`, `sdn`, `virtualizacao`, `nfv`); `iso` chegou ao `login:` em 97 s sem KVM; total do runner 125 s |

## Como gerar

Na VM de build ([ambiente-de-build.md](ambiente-de-build.md)), com o repositório clonado no disco da VM:

```bash
sudo scripts/build-iso.sh
```

O script recusa rodar fora de Linux, em `/mnt/*` ou sem root. Ele entra em `live-build/`, roda `lb clean`, `lb config` (via `live-build/auto/config`) e `lb build`,
grava o log em `live-build/build.log`, move a ISO para `dist/nexus-os-poc-amd64.iso` e gera `dist/nexus-os-poc-amd64.iso.sha256`.

## ISO integrada (Fase 3)

A mesma receita (`sudo scripts/build-iso.sh`) agora gera a ISO integrada: além da base, ela traz o Open vSwitch, os arquivos de `/usr/share/nexus-os/` e o runner `nexus-smoke` ([integracao-iso.md](integracao-iso.md)). O nome `nexus-os-poc-amd64.iso` fica até o congelamento da RC1. Os números acima são da ISO da prova de conceito, sem a stack.

## Parâmetros da ISO

Definidos em `live-build/auto/config`, com os nomes das opções conferidos em `lb config --help`:

- Distribuição `trixie`, arquitetura `amd64`, imagem `iso-hybrid`, sem debian-installer, apenas a área `main`, espelho padrão do Debian.
- Nome da imagem `nexus-os`, rótulo e aplicação "Nexus OS".
- Linha de comando do kernel: `boot=live components console=tty0 console=ttyS0,115200n8` (console serial além do vídeo, sem `quiet splash`).
- Pacotes extras em `live-build/config/package-lists/nexus-base.list.chroot`: `sudo`, `ca-certificates`, `nano`.
- Sem a opção `--distribution`, o `lb config` usa `testing`. Por isso ela é obrigatória em `auto/config`.

Versões dentro da ISO (de `live-build/chroot.packages.install`, 233 pacotes): linux-image-amd64 6.12.113-1, live-boot 1:20250815~deb13u1, live-config 11.0.5, systemd 257.13-1~deb13u1, sudo 1.9.16p2-3+deb13u2, nano 8.4-1+deb13u1, ca-certificates 20250419+deb13u1.

## Credencial padrão de laboratório

O live-config cria o usuário `user` com a senha `live` (lida em `/usr/lib/live/config/0030-user-setup` e `/usr/lib/live/init-config.sh` do chroot).
É uma credencial pública e documentada do Debian Live, própria de laboratório. Não é segredo e não serve para produção.

## Teste de boot

```bash
tests/iso.sh dist/nexus-os-poc-amd64.iso
```

O teste confere o SHA256 contra o `.sha256`, inicia a ISO em QEMU sem interface, com a serial gravada em arquivo temporário, e espera `login:` por até 300 s com KVM ou 900 s sem KVM.
O menu do isolinux espera uma tecla (`timeout 0` em `isolinux.cfg`), então o teste envia Enter pelo monitor do QEMU nos primeiros 60 s.
O monitor usa FIFOs dentro do diretório temporário (modo 0700), e não uma porta TCP, para que outro usuário da máquina não consiga mandar comandos ao QEMU.

Medido na VM de build, `/dev/kvm` ausente, QEMU 10.0.13 em emulação por software:

| Execução | Resultado | Tempo até `login:` |
| --- | --- | --- |
| 1 | OK | 827 s |
| 2 | OK, linha `debian login: ` | 104 s |
| 3 | OK, linha `debian login: `, já com o monitor do QEMU por FIFO | 129 s |

## Limitações

- **Sem KVM.** O Hyper-V do Windows está ativo no notebook de build, então o VirtualBox não expõe VT-x/AMD-V à VM de build:
  `/dev/kvm` não existe e `egrep -c '(vmx|svm)' /proc/cpuinfo` retorna 0, mesmo com `--nested-hw-virt=on`. O boot foi medido em emulação por software (QEMU TCG), e não em KVM.
  O critério F2.4 pede boot em VM KVM: falta repetir o teste em máquina com KVM (limite de 300 s no `tests/iso.sh`).
- **Tempo de boot instável sem KVM.** Duas execuções iguais deram 827 s e 104 s. A causa não foi diagnosticada. O limite de 900 s foi mantido, mas o pior caso medido passa de 90% dele.
- **Reprodução por segunda pessoa: pendente.** Falta outra pessoa seguir a seção "Como gerar a ISO" do `README.md` em máquina limpa e conferir o boot.

## Problemas conhecidos

- O `lb config` e o `lb build` criam em `live-build/` links para hooks padrão (`config/hooks/live/` e `config/hooks/normal/`), `config/package-lists/live.list.chroot` e arquivos de controle.
  Eles são gerados a cada build e estão no `.gitignore`. Hook próprio precisa de `nexus-` no nome (exceção no `.gitignore`), como o `0500-nexus-servicos.hook.chroot`.
- O `tests/lint-repo.sh` só roda o `shellcheck` se ele estiver instalado (na VM de build está; no Git Bash do Windows, não).
