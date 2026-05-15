#!/bin/bash
# ==============================================================================
# Script: 04-flatpaks-media.sh
# Descrição: Instala aplicativos multimídia, edição de imagem e modelagem 3D
# ==============================================================================

echo "🚀 Iniciando a instalação das ferramentas multimídia e de design..."

# Lista de aplicativos agrupados em um Array para instalação paralela
FLATPAKS_MEDIA=(
    "org.upscayl.Upscayl"             # Upscaling de imagens com IA
    "com.jgraph.drawio.desktop"       # Criação de diagramas e fluxogramas
    "org.freecad.FreeCAD"             # Modelagem 3D paramétrica (excelente para exportar geometrias)
    "org.kde.kcolorchooser"           # Seletor de cores rápido do ecossistema KDE
    "org.gimp.GIMP"                   # Edição avançada de imagens
    "org.kde.kolourpaint"             # Edição simples e rápida (estilo MS Paint)
    "io.github.cosmic_utils.camera"   # Aplicativo minimalista de câmera
    "org.kde.haruna"                  # Reprodutor de vídeo fluido e moderno do KDE
    "org.videolan.VLC"                # O clássico reprodutor multimídia universal
    "com.obsproject.Studio"           # Gravação de tela e transmissão (OBS Studio)
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# Expande a lista e instala de uma só vez sem interrupções
flatpak install -y flathub "${FLATPAKS_MEDIA[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Aplicativos multimídia instalados com sucesso!"
