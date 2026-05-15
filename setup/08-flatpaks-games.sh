#!/bin/bash
# ==============================================================================
# Script: 08-flatpaks-games.sh
# Descrição: Instala jogos casuais e o gerenciador de ambientes Wine (Bottles)
# ==============================================================================

echo "🚀 Iniciando a instalação do pacote de entretenimento..."

# Lista de aplicativos agrupados em um Array para instalação paralela
FLATPAKS_GAMES=(
    "com.usebottles.bottles"                   # Sandbox perfeito para rodar aplicativos/jogos de Windows
    "net.supertuxkart.SuperTuxKart"            # Jogo de corrida casual e open-source
    "com.github.k4zmu2a.spacecadetpinball"     # O clássico e nostálgico Pinball (Full Tilt!)
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# Expande a lista e instala de uma só vez sem interrupções
flatpak install -y flathub "${FLATPAKS_GAMES[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Pacote de diversão e isolamento Wine instalado com sucesso!"
