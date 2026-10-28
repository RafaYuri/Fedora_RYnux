#!/bin/bash
# ==============================================================================
# Script: 07-microsoft-fonts.sh
# Descrição: Instala fontes essenciais da Microsoft via Homebrew
# ==============================================================================
set -euo pipefail

echo "🚀 Preparando a instalação de fontes da Microsoft..."

# 1. Garante que o Homebrew esteja carregado no PATH (caso executado via atalho .desktop)
if ! command -v brew &> /dev/null; then
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    elif [ -x "/usr/local/bin/rynux-homebrew-init.sh" ]; then
        echo "⚙️ Inicializando o diretório do Homebrew em /home/linuxbrew..."
        sudo /usr/local/bin/rynux-homebrew-init.sh
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

if ! command -v brew &> /dev/null; then
    echo "❌ Erro: O Homebrew não foi encontrado no sistema."
    exit 1
fi

echo "📦 Adicionando o repositório de fontes (Tap)..."
# O comando tap adiciona o repositório específico de fontes não-livres
brew tap colindean/fonts-nonfree

echo "📥 Iniciando o download e instalação das fontes..."
# Instala o pacote Office, a nova fonte Aptos e as clássicas de sistema
brew install --cask \
    font-microsoft-office \
    font-microsoft-aptos \
    font-arial \
    font-arial-black \
    font-courier-new \
    font-times-new-roman \
    font-georgia

echo "⚙️  Atualizando o cache de fontes do sistema..."
# Garante que o KDE Plasma e outros apps reconheçam as fontes imediatamente
fc-cache -f -v

echo "🎉 Fontes instaladas com sucesso!"
echo "👉 Arial, Times New Roman, Georgia e Aptos já estão disponíveis nos seus editores."
