#!/bin/bash
# ==============================================================================
# Script: 10-distrobox-dev-env.sh
# Descrição: Cria o laboratório de desenvolvimento (C++, Qt6, CFD, Python)
# ==============================================================================

CONTAINER_NAME="dev-lab"
IMAGE="quay.io/fedora/fedora:latest"

echo "🚀 Iniciando a criação do laboratório de alta performance: $CONTAINER_NAME..."

# 1. Cria o contêiner se ele não existir
if distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "⚠️ O contêiner '$CONTAINER_NAME' já existe."
else
    distrobox create --name $CONTAINER_NAME --image $IMAGE --yes
    echo "✅ Contêiner criado com sucesso."
fi

echo "📦 Injetando o arsenal de engenharia e programação..."

# 2. Executa a instalação de todas as dependências dentro do container
distrobox enter $CONTAINER_NAME -- sh -c "
    # Configuração do Repositório VSCode
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    echo -e '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc' | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    sudo dnf update -y && \

    # Ferramentas C++ e HPC (Adicionado GDB, Git, Eigen e OpenMPI)
    sudo dnf install -y \
        cmake gcc-c++ gdb ninja-build make git pkg-config \
        libgomp clang llvm libomp-devel \
        openmpi openmpi-devel \
        eigen3-devel boost-devel && \

    # Ambiente Qt6 e IDEs
    sudo dnf install -y \
        qt6-*-devel qt6-*-examples qtcreator code && \

    # Bibliotecas Científicas e Visualização
    sudo dnf install -y \
        opencv-devel gnuplot fftw-devel \
        gmsh gmsh-devel --setopt=install_weak_deps=False && \

    # Stack Python para Ciência de Dados
    sudo dnf install -y \
        python3-aiohttp python3-pandas python3-matplotlib python3-pip && \

    # Instalação do Janus via Pip
    pip install janus && \

    sudo dnf clean all
"

echo "🎉 Laboratório configurado com sucesso!"
echo "👉 Para entrar no ambiente: distrobox enter $CONTAINER_NAME"
echo "👉 Para exportar o VSCode para o menu do host: distrobox-export --app code"
