# 🦏 Fedora RYnux

Bem-vindo ao **Fedora RYnux**, um sistema operacional customizado, imutável e antifrágil. Construído sobre a tecnologia *bootc* do projeto Fedora e utilizando o KDE Plasma, o RYnux foi desenhado para ser uma base à prova de falhas para estações de trabalho e laboratórios.

Seu foco principal é fornecer um ambiente "time-proven" e altamente otimizado para pesquisadores, com ferramentas pré-configuradas para desenvolvimento avançado em C++, Computação de Alto Desempenho (HPC) e simulações numéricas.

---

## 🚀 Características Principais

* **Arquitetura Atômica:** Baseado no `fedora-bootc`. O núcleo do sistema é imutável (somente-leitura), o que significa que atualizações problemáticas não quebram a máquina.
* **Gerenciamento de Energia:** Otimizado nativamente para processadores AMD Ryzen (incluindo o motor `tuned` em vez do tradicional *power-profiles-daemon*).
* **Gráficos e Mídia:** Aceleração de hardware via AMD Radeon nativamente configurada com `mesa-va-drivers` e codecs completos multimídia via RPM Fusion.
* **Ambiente de Desenvolvimento:**
  * Compiladores modernos e ferramentas C++ (CMake, Ninja, GDB).
  * Suporte robusto a contêineres e virtualização (Podman, Docker, Distrobox, QEMU/KVM + Virt-Manager).

## 🛠️ Como instalar (Bare Metal ou VM)

A automação deste repositório compila o sistema operacional diariamente. Para instalar na sua máquina:

1. Acesse a aba [Actions](../../actions) deste repositório.
2. Clique no workflow **Construir ISO de Instalação (image-builder)** (ou baixe o artefato da compilação mais recente).
3. Faça o download do artefato `Fedora_RYnux-Installer-ISO`.
4. Utilize uma ferramenta (como o Fedora Media Writer, Rufus ou BalenaEtcher) para gravar a ISO em um pendrive.
5. Inicie a máquina pelo pendrive. O instalador gráfico **Anaconda WebUI** (customizado para o Fedora RYnux) permitirá selecionar o idioma/teclado e realizar o particionamento dos discos (com suporte nativo a BTRFS) para a instalação offline do sistema base. No primeiro boot, o assistente do KDE Plasma (*Plasma Setup*) assumirá o controle para a criação do seu usuário, fuso horário e configuração de rede.

## 🔄 Atualizações

Uma vez instalado, o sistema abandona o gerenciamento de pacotes tradicional. O RYnux se conecta automaticamente ao GitHub Container Registry (GHCR) e faz o download de atualizações de forma silenciosa em segundo plano. Basta reiniciar a máquina para aplicar a versão mais recente, mantendo a integridade do ecossistema.

## 🧰 Pós-instalação e Ambiente de Usuário

O Fedora RYnux entrega um sistema base limpo e imutável. Para instalar ferramentas de produtividade, players de multimídia ou configurar ambientes avançados de desenvolvimento, disponibilizamos scripts modulares de pós-instalação.

👉 **[Consulte o Guia de Pós-instalação na pasta `/setup`](./setup/README.md)** para personalizar o seu ambiente de forma automatizada.

## 🙏 Agradecimentos

Este projeto só é possível graças ao trabalho excepcional da comunidade de código aberto:

* **Time do [Fedora Project](https://fedoraproject.org/):** Pela excelência contínua na engenharia da distribuição e empacotamento impecável.
* **Time do [KDE Plasma](https://kde.org/plasma-desktop):** Por fornecer um ambiente de desktop moderno, elegante e altamente configurável.
* **Desenvolvedores do [bootc](https://github.com/bootc-dev/bootc) e [osbuild / image-builder](https://github.com/osbuild/image-builder-cli):** Por revolucionarem a arquitetura de sistemas operacionais Linux imutáveis baseados em contêineres OCI.
* **Fernando Fedora ([Ferlinuxdebian](https://github.com/Ferlinuxdebian)):** Pelo excelente trabalho e divulgação de conteúdos relacionados ao bootc na comunidade brasileira do Fedora Linux.
---
*Construído com a robustez do Fedora e a flexibilidade das imagens em contêiner.*
