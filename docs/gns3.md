# GNS3: instalação e uso (só documentado), passo a passo

F3.8. O GNS3 é a topologia de demonstração secundária do Nexus OS. Por decisão do escopo reduzido ele **só é documentado**: não entra na ISO. A topologia principal é o Containerlab ([nfv.md](nfv.md)). Este documento foi escrito para quem **nunca viu o projeto**: cada passo diz **onde fazer**, **o que fazer**, **por que fazer**, **o que deve aparecer** e **o que fazer se não aparecer**.

Cada comando abaixo está marcado:

- **executado**: rodado em 26/10/2026 na VM de build (Debian 13 no Hyper-V, com KVM), com o resultado registrado;
- **da documentação oficial, não executado**: copiado das páginas oficiais, sem execução nesta tarefa. Para estes, o "deve aparecer" é o que a documentação oficial descreve e **não foi conferido pelo projeto**.

Fontes (lidas em 26/10/2026):

- Instalação no Linux: https://docs.gns3.com/docs/getting-started/installation/linux
- Servidor remoto: https://docs.gns3.com/docs/getting-started/installation/remote-server
- Um servidor, vários clientes: https://docs.gns3.com/docs/getting-started/installation/one-server-multiple-clients

## Sumário

1. [O que é o GNS3 e por que ele só é documentado](#o-que-é-o-gns3-e-por-que-ele-só-é-documentado)
2. [Regras que valem o tempo todo](#regras-que-valem-o-tempo-todo)
3. [Pré-requisitos](#pré-requisitos)
4. [Instalação](#instalação)
5. [Uso](#uso)
6. [Fora da ISO](#fora-da-iso)
7. [Problemas conhecidos](#problemas-conhecidos)
8. [Como relatar uma falha](#como-relatar-uma-falha)

## O que é o GNS3 e por que ele só é documentado

O **GNS3** é um programa para montar e simular redes: você arrasta roteadores e switches virtuais para uma tela e liga um ao outro. Para o Nexus OS ele é a demonstração **secundária**; a principal é o Containerlab (comandos `containerlab deploy` e `nexus-vnf`, descritos no [manual](manual.md)). O projeto instalou e executou **só o servidor do GNS3**; a interface gráfica, o Dynamips e a abertura de um projeto não foram testados.

**Resultado esperado de uma execução bem-sucedida deste documento:** um servidor `gns3server` instalado, respondendo na porta 3080 com a versão.

## Regras que valem o tempo todo

1. **Faça só o que está escrito aqui.** Se precisar de algo que não está escrito, isso é uma falha da documentação: anote e relate (seção "Como relatar uma falha").
2. **Um passo de cada vez, na ordem**, conferindo o resultado antes de seguir.
3. **O repositório é público.** Nunca cole em issue: senha, chave, token, e-mail, nome de usuário do seu computador.
4. **Instale numa máquina ou VM de laboratório**, não dentro da ISO do Nexus OS (ela é live e some ao desligar).

## Pré-requisitos

| Item | Por quê | Observação |
| --- | --- | --- |
| Debian 13 (ou derivado) ou outro Linux, com internet | O GNS3 não está no `apt` do Debian: a página oficial manda usar o `pipx` ("GNS3 is not available through apt; you will have to use `pipx`") | Executado no Debian 13 |
| Python 3 e `pipx` | O `pipx` instala programas Python em ambiente isolado | Medido na VM: Python 3.13.5 e `pipx` 1.7.1 (pacote `pipx` 1.7.1-1 do Debian 13) |
| Para a interface gráfica (`gns3-gui`): PyQt6 e uma sessão gráfica | A interface é uma janela | A ISO RC1 não tem ambiente gráfico (a RC2 tem) |
| Para nós QEMU: KVM e libvirt | Os nós QEMU rodam máquinas virtuais | A página oficial lista `qemu-kvm`, `qemu-utils`, `libvirt-clients`, `libvirt-daemon-system` e `virtinst` |
| Para roteadores Cisco IOS (Dynamips): compilar o código-fonte | No Debian 13 o pacote `dynamips` saiu do `apt` | Veja "Dynamips" na seção Instalação |
| Servidor dedicado (para a instalação de servidor remoto) | A página oficial recomenda um servidor dedicado e avisa que provedores de nuvem costumam bloquear as instruções de virtualização da CPU, o que deixa o QEMU lento | Só para o uso remoto |

## Instalação

### Passo 1: instalar só o servidor (executado)

**Onde:** terminal da VM Linux, como usuário comum com `sudo`.

**O que fazer:** método da documentação oficial (`pipx`), com a instalação isolada numa pasta temporária (`PIPX_HOME`), para não deixar rastro na VM:

```bash
sudo apt-get install -y pipx
export PIPX_HOME=/tmp/gns3-pipx PIPX_BIN_DIR=/tmp/gns3-pipx/bin
pipx install gns3-server
/tmp/gns3-pipx/bin/gns3server --version
```

**Por quê:** o primeiro comando instala o `pipx`; as variáveis mandam o `pipx` usar uma pasta temporária em vez do seu diretório pessoal; `pipx install gns3-server` instala o servidor; o último comando imprime a versão para provar que funciona.

**Deve aparecer:** `pipx install gns3-server` termina com código 0 e instala `gns3-server 3.0.6` com Python 3.13.5; `gns3server --version` imprime `3.0.6`. O `apt-get install pipx` mais o `pipx install` levaram 23 s (uma única tentativa, 26/10/2026).

**Se não aparecer:** copie a mensagem exata e relate; o projeto não viu falha nesta instalação. Depois do teste, a pasta temporária, `~/GNS3`, `~/.config/GNS3`, o pacote `pipx` e as dependências que só ele trouxe foram removidos. A interface gráfica não foi instalada.

**Instalação normal, sem pasta temporária (da documentação oficial, não executada):**

```bash
pipx install gns3-server
```

### Passo 2: interface gráfica e emulação (da documentação oficial, não executados)

**Onde:** terminal de uma máquina Linux com sessão gráfica.

**O que fazer:** Debian 13 (a página oficial retira `dynamips` e `software-properties-common` da lista):

```bash
sudo apt update
sudo apt install python3 python3-pip pipx python3-pyqt6 python3-pyqt6.qtwebsockets python3-pyqt6.qtsvg qemu-kvm qemu-utils libvirt-clients libvirt-daemon-system virtinst ca-certificates curl gnupg2
pipx install gns3-server
pipx install gns3-gui
pipx inject gns3-gui gns3-server PyQt6
```

**Por quê:** instala as dependências, o servidor e a interface, e injeta o servidor e o PyQt6 no ambiente da interface. **Deve aparecer:** o que a documentação oficial descreve (instalação sem erro); o projeto não executou. **Se não aparecer:** relate a mensagem exata.

### Passo 3: Dynamips no Debian 13, compilado do código-fonte (da documentação oficial, não executado)

**O que fazer:**

```bash
sudo apt update
sudo apt install build-essential cmake libelf-dev libpcap0.8-dev
git clone https://github.com/GNS3/dynamips.git
cd dynamips
mkdir build
cd build
cmake ..
make install
```

**Por quê:** o Dynamips emula roteadores Cisco IOS e não está mais no `apt` do Debian 13. A página oficial dá os pacotes de compilação em comandos separados; aqui estão juntos, com os mesmos nomes. Para o Ubuntu a página usa o PPA `ppa:gns3/ppa` e o grupo `ubridge,libvirt,kvm,wireshark,docker`; não se aplica ao Debian e não foi usado.

## Uso

### Passo 4: subir o servidor (executado)

**Onde:** terminal da VM, com a instalação temporária do passo 1.

**O que fazer:** o servidor sobe e responde pela API (comandos rodados na VM, com a escuta só em `127.0.0.1`):

```bash
/tmp/gns3-pipx/bin/gns3server --host 127.0.0.1 --port 3080
curl -s http://127.0.0.1:3080/v3/version
```

O primeiro comando **fica rodando** (ele é o servidor): rode o `curl` em **outro** terminal.

**Por quê:** `--host 127.0.0.1` faz o servidor escutar só na própria máquina; `--port 3080` fixa a porta; o `curl` pede a versão pela API.

**Deve aparecer:** `ss -ltn` mostra `127.0.0.1:3080` em escuta e o `curl` devolve `{"controller_host":"127.0.0.1","version":"3.0.6","local":false}`. Opções do `gns3server --help` (3.0.6): `--host`, `--port`, `--ssl`, `--config`, `--local`, `--daemon`, `--logfile`. A porta foi passada de forma explícita; a página oficial não declara a porta padrão do servidor, então ela não está confirmada aqui.

**Se não aparecer:** o `curl` sem resposta indica que o servidor não subiu: veja a saída do primeiro terminal e relate.

### Passo 5: cliente gráfico (da documentação oficial, não executado)

**O que fazer:** depois de instalar o `gns3-gui`, o comando oficial para abrir a interface é `gns3`. No assistente de configuração, "Run appliances on a remote server" aponta a interface para um servidor GNS3 remoto; os valores de host e porta aparecem na página oficial só em imagens. Um servidor pode atender vários clientes desde o GNS3 2.0.

**Deve aparecer:** a janela do GNS3 com o assistente. Não foi conferido pelo projeto.

### Relação com o Nexus OS

O GNS3 não substitui a demonstração do Nexus OS. Para a demonstração use `nexus-vnf` e a topologia `frr-duo` do Containerlab ([manual.md](manual.md)).

## Fora da ISO

Motivos para o GNS3 não entrar na ISO:

- Decisão do escopo reduzido (grupo): o GNS3 é só documentado, e o Containerlab é a topologia principal.
- A instalação oficial no Debian usa `pipx` e baixa pacotes da internet, e a ISO precisa funcionar sem rede. Empacotar as dependências exigiria um espelho offline que o projeto não construiu.
- A interface gráfica exige sessão gráfica; a ISO RC1 não tem desktop.
- No Debian 13 o Dynamips precisa ser compilado, o que não cabe numa receita de live-build simples.

Como usar ao lado da ISO: instale o GNS3 em outra máquina ou VM, seguindo a seção "Instalação", e use a ISO do Nexus OS em seu próprio QEMU ou Hyper-V ([manual.md](manual.md)). Importar a ISO como nó QEMU de um projeto GNS3 não foi testado.

## Problemas conhecidos

- Só o servidor foi instalado e executado; a interface gráfica, o Dynamips e a abertura de um projeto não foram testados.
- A porta padrão do `gns3server` e os valores de conexão do cliente remoto não aparecem em texto nas páginas oficiais lidas; a porta 3080 só foi confirmada porque foi passada com `--port`.
- Um resumo da busca citou que o README do `gns3-server` trata o uBridge como necessário e o QEMU como recomendado no Linux. A página de instalação para Debian não traz comando para o uBridge, e o nome do pacote no Debian 13 não foi conferido.
- O Dynamips compilado do código-fonte e os pacotes da lista do Debian 13 não foram executados.
- A página oficial de instalação mudou de endereço em relação a versões antigas (a raiz `/docs/getting-started/installation/` devolve 404); use as três URLs da lista de fontes.
- Reprodução por segunda pessoa pendente.

## Como relatar uma falha

**Quando:** para cada comando deste documento que falhar e para tudo que ele não explicou.

**Onde:** uma **issue** no repositório do projeto no GitHub. **Título:** `F3.8: <passo>: <resumo curto>`. **Corpo:** **Passos** (comandos exatos), **Saída** (texto exato copiado e colado), **Esperado** (o que o documento dizia) e **Ambiente** (Debian, versões do Python e do `pipx`, se tinha KVM). Uma issue por falha, sem dado pessoal (regra 3).
