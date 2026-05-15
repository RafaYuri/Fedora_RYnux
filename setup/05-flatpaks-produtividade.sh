#!/bin/bash
# ==============================================================================
# Script: 05-flatpaks-produtividade.sh
# Descrição: Instala suítes de escritório, comunicação e utilitários de rede
# ==============================================================================

echo "🚀 Iniciando a instalação dos aplicativos de produtividade..."

# Lista de aplicativos agrupados em um Array para instalação paralela
FLATPAKS_PROD=(
    "org.libreoffice.LibreOffice"                 # Suíte office robusta (excelente para dados/calc)
    "org.onlyoffice.desktopeditors"               # Alta compatibilidade com formatos MS Office
    "com.github.johnfactotum.Foliate"             # Leitor de e-books e PDFs moderno
    "io.github.zarestia_dev.rclone-manager"       # Gerenciador gráfico para o Rclone (Nuvem)
    "org.kde.kclock"                              # Relógio, alarmes e timers do ecossistema KDE
    "org.telegram.desktop"                        # Mensageiro instantâneo
    "org.qbittorrent.qBittorrent"                 # Cliente Torrent leve e open-source
    "io.github.mhogomchungu.media-downloader"     # Download de mídias e vídeos
    "org.localsend.localsend_app"                 # Transferência de arquivos via rede local (AirDrop open-source)
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# Expande a lista e instala de uma só vez sem interrupções
flatpak install -y flathub "${FLATPAKS_PROD[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Aplicativos de produtividade instalados com sucesso!"
