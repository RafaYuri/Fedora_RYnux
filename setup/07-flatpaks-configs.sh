#!/bin/bash
# ==============================================================================
# Script: 07-flatpaks-configs.sh
# Descrição: Instala utilitários de sistema, monitoramento e gerenciamento
# ==============================================================================

echo "🚀 Iniciando a instalação dos utilitários de configuração e monitoramento..."

# Lista de aplicativos agrupados em um Array para instalação paralela
FLATPAKS_CONFIGS=(
    "com.github.tchx84.Flatseal"                       # Gerenciador de permissões do Flatpak
    "it.mijorus.gearlever"                             # Gerenciador e integrador de AppImages
    "io.github.thetumultuousunicornofdarkness.cpu-x"   # Informações detalhadas de hardware (estilo CPU-Z)
    "io.missioncenter.MissionCenter"                   # Monitor de recursos do sistema moderno e detalhado
    "org.fedoraproject.MediaWriter"                    # Criador de pendrives bootáveis oficial do Fedora
)

echo "📦 Baixando pacotes. Origem forçada: repositório 'flathub'..."

# Expande a lista e instala de uma só vez sem interrupções
flatpak install -y flathub "${FLATPAKS_CONFIGS[@]}"

echo "✅ Limpando pacotes residuais não utilizados..."
flatpak uninstall --unused -y

echo "🎉 Utilitários de sistema instalados com sucesso!"
