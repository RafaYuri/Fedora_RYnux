#!/bin/bash
# ==============================================================================
# Script: 03-flatpaks-dev.sh
# Descrição: Instala ferramentas e IDEs de desenvolvimento via Flatpak
# ==============================================================================

echo "🚀 Iniciando a instalação das ferramentas de desenvolvimento..."

# Lista de aplicativos agrupados em um Array para facilitar a leitura e manutenção
FLATPAKS_DEV=(
    "cc.arduino.IDE2"                 # Ambiente de prototipagem e hardware
    "io.podman_desktop.PodmanDesktop" # Interface gráfica para gerenciamento de contêineres
    "io.github.wh201906.serialtest"   # Monitoramento de comunicação serial/sensores
    "io.github.DenysMb.Kontainer"     # Gerenciador alternativo de contêineres
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# A sintaxe "${FLATPAKS_DEV[@]}" expande a lista inteira na mesma linha.
# A flag '-y' garante que ele não faça perguntas durante o processo.
flatpak install -y flathub "${FLATPAKS_DEV[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Ferramentas de desenvolvimento instaladas com sucesso!"
