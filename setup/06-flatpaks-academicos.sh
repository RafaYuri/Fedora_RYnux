#!/bin/bash
# ==============================================================================
# Script: 06-flatpaks-academicos.sh
# Descrição: Instala softwares para computação numérica, simulação e visualização
# ==============================================================================

echo "🚀 Iniciando a instalação do pacote acadêmico e de simulação..."

# Lista de aplicativos agrupados em um Array para instalação paralela
FLATPAKS_ACAD=(
    "org.scilab.Scilab"                       # Computação numérica e matemática aplicada
    "org.octave.Octave"                       # Linguagem de alto nível para cálculos numéricos
    "io.github.wxmaxima_developers.wxMaxima"  # Sistema de álgebra computacional (CAS)
    "org.paraview.ParaView"                   # Visualização e análise de dados (CFD/Malhas)
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# Expande a lista e instala de uma só vez sem interrupções
flatpak install -y flathub "${FLATPAKS_ACAD[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Aplicativos acadêmicos instalados com sucesso!"
