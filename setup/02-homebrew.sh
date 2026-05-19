#!/bin/bash
# ==============================================================================
# Script: 02-homebrew.sh
# Descrição: Instala e configura o gerenciador de pacotes Homebrew
# ==============================================================================

echo "🚀 Iniciando a instalação do Homebrew..."

# 1. Verifica se o Homebrew já está instalado para evitar reinstalações desnecessárias
if command -v brew &> /dev/null; then
    echo "✅ O Homebrew já está instalado no sistema."
else
    echo "🔑 O instalador precisa preparar diretórios na raiz. Por favor, valide o administrador:"

    # Atualiza o ticket do sudo antecipadamente para evitar pausas interativas
    sudo -v

    # Roda a instalação e avalia se o resultado foi um sucesso (exit code 0)
    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        echo "✅ Instalação base do Homebrew concluída."
    else
        echo "❌ Ocorreu um erro durante a instalação base. Abortando."
        exit 1
    fi
fi

echo "⚙️ Configurando as variáveis de ambiente (PATH)..."

# 2. Configura o PATH no .bashrc, mas primeiro verifica se já não foi feito antes
if grep -q "brew shellenv" ~/.bashrc; then
    echo "✅ O Homebrew já está configurado no seu ~/.bashrc."
else
    echo "🔧 Injetando configurações no ~/.bashrc..."

    # Injeta o bloco de configuração corrigindo as quebras de linha
    cat << 'EOF' >> ~/.bashrc

# Inicialização do Homebrew
if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d "$HOME/.linuxbrew" ]; then
    eval "$($HOME/.linuxbrew/bin/brew shellenv)"
fi
EOF
    echo "✅ Variáveis de ambiente configuradas com sucesso!"
fi

echo "🎉 Homebrew pronto para uso!"
echo "👉 Para carregar os comandos na sessão atual, digite: source ~/.bashrc"
