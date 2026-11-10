# Congelamento da ISO do Nexus OS (F4.6)

Este documento registra a ISO que foi congelada ao fim da Fase 4: a **RC2 final v2**, o que ela é, onde fica, o que não pode mais mudar nela, os riscos aceitos e as issues de prioridade baixa que seguem abertas. A conferência é feita por [../tests/congelamento.sh](../tests/congelamento.sh), que roda no Git Bash e no Linux sem a ISO.

## Identificação

| Item | Valor |
| --- | --- |
| Arquivo | `dist/nexus-os-rc2-amd64.iso` |
| SHA256 | `cb13d258153162f4ebe6d1d81cf507357e754152b1eef27d3b33ac74d4be876e` |
| Tamanho (bytes) | 1990639616 |
| Commit do build | `480e5d8` |
| Data | 2026-11-10 |
| Tempo do build (s) | 1100 |
| Tag | `v1.0.0-rc2`, criada na `main` depois do merge de `marcos` (F4.6 só fecha com a tag no remoto: `git ls-remote --tags origin`) |
| Onde fica guardada | na máquina do responsável: VM de build em `dist/` e cópia no Windows fora do repositório |
| Conferência | o mesmo SHA256 por `sha256sum` na VM de build e por `Get-FileHash` na cópia do Windows (10/11/2026) |

O SHA256, o tamanho e o tempo são os de [rc2.md](rc2.md), tabela "Identificação". A ISO foi gerada em clone novo de `origin/marcos` pelos comandos da seção "Gerar a ISO" do [manual v2.1](manual.md). Nenhum arquivo `.iso` é versionado: a ISO e o `.sha256` ficam fora do Git.

## Nada mais entra na ISO

**Nada mais entra na ISO** congelada. Qualquer mudança em `live-build/`, nas listas de pacotes, nos arquivos de `live-build/config/includes.chroot/` ou nos scripts de build exige uma ISO nova, com novo SHA256 e nova tag (por exemplo `v1.0.0-rc3`), e repete os testes T1 a T7.

O que pode mudar no repositório depois do congelamento é a documentação e os testes. Os documentos que ficam **dentro** da ISO (`/usr/share/nexus-os/docs` e a Documentação em HTML) são os do commit do build (`480e5d8`); o manual do repositório é a referência e pode ficar mais novo que a cópia da ISO.

## ISO anteriores (só histórico)

| ISO | SHA256 (início e fim) | Commit | Situação |
| --- | --- | --- | --- |
| RC2 final v2 | `cb13d258...876e` | `480e5d8` | **congelada** |
| descartada | `ac33affd...6176` | `ccb55f0` | o `~/.inputrc` que desligava a colagem em bloco fazia o `sudo` engolir as linhas coladas; removido |
| anterior | `28efa045...de97` | `61e02b9` | a Documentação em HTML mostrava os blocos `bash nexus-exec` como texto corrido |

Todas ficam fora do Git, na máquina de build. As evidências de cada uma estão em [../evidencias/README.md](../evidencias/README.md).

## Riscos aceitos

### Issue #32: `nexus-smoke.service` roda como root o conteúdo de um CD `NEXUS_SMOKE`

**Decisão:** risco **aceito** para a ISO de laboratório e de demonstração, sem alterar a ISO. O serviço fica habilitado porque é com ele que os testes dentro da ISO rodam (`tests/iso-smoke.sh`, `nexus-smoke`).

**Razão:** quem consegue anexar um CD virtual a uma ISO em execução já controla o hipervisor e o console da máquina, e a ISO traz uma credencial pública de laboratório (usuário `user`, senha `live`, `sudo` sem senha). O serviço não amplia o que essa pessoa já pode fazer.

**Contexto medido (10/11/2026, ISO em execução):** `sudo -n true` como `user` saiu com código 0, e `systemctl is-enabled nexus-smoke.service` disse `enabled`.

**Revisão:** se uma ISO for usada fora de laboratório e demonstração, o serviço deve ser removido ou condicionado a um argumento da linha de comando do kernel, o que exige uma ISO nova (veja "Nada mais entra na ISO"). O risco também está em [rc1.md](rc1.md), seção "Riscos conhecidos".

## Issues de prioridade baixa abertas

Nenhuma impede o uso da ISO. Estão em "Limitações conhecidas" de [rc2.md](rc2.md) ou têm saída descrita no manual.

| Issue | Assunto | Tratamento |
| --- | --- | --- |
| 82 | colar bloco no terminal às vezes escreve `^[[200~` no começo e `~` no fim | Ctrl+C e colar de novo (seção "Colar comandos numa VM sem rede" do manual); desligar a colagem em bloco piora, veja a ISO descartada |
| 79 | papel de parede e ícones aparecem cerca de 2 s depois da barra no Hyper-V | estético |
| 57 | a barra da tela de login mostra o nome de máquina `debian` | estético |
| 56 | papel de parede padrão conferido só no monitor `Virtual-1` do QEMU | outros monitores não testados |
| 35 | o smoke da libvirt falhou uma vez no Hyper-V sem KVM; intermitente | repetir o teste e registrar |
| 34 | ao desligar, a ISO live pede Enter | apertar Enter no console |
| 33 | a RAM em repouso varia entre execuções (539 a 796 MiB sem desktop) | causa não investigada; a RAM recomendada vem do pico, com folga |
| 31 | `docker load` falha com menos de 896 MiB de RAM | o mínimo está em [requisitos.md](requisitos.md) |

## Como conferir

No Linux (VM de build), na pasta `nexus-os`:

```bash
sha256sum dist/nexus-os-rc2-amd64.iso
tests/congelamento.sh
git ls-remote --tags origin
```

No Windows, na cópia da ISO (PowerShell):

```powershell
Get-FileHash C:\HyperV\nexus-os-rc2-cb13d258-amd64.iso -Algorithm SHA256
```

**Deve aparecer:** o mesmo SHA256 da tabela "Identificação" nos dois sistemas, `OK: congelamento conferido ...` no teste e, depois do merge, `refs/tags/v1.0.0-rc2` na lista de tags.

## Pendências

- Reprodução dos testes T1 a T7 e do manual por uma segunda pessoa (os testes foram executados por Marcos).
- A tag `v1.0.0-rc2` na `main` e o registro do resultado.
