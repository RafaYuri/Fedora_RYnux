#!/bin/bash
# ==============================================================================
# Script: 30-setup-tui.sh
# Descrição: Embute os scripts modulares de pós-instalação em /usr/share/rynux/setup
#            e instala a aplicação TUI interativa 'rynux-setup' + atalho desktop.
# ==============================================================================
set -euo pipefail

echo "🧰 [30-setup-tui] Instalando scripts de pós-instalação em /usr/share/rynux/setup..."
mkdir -p /usr/share/rynux/setup /usr/local/bin /usr/share/applications

cp /tmp/setup/*.sh /usr/share/rynux/setup/
[ -f /tmp/setup/README.md ] && cp /tmp/setup/README.md /usr/share/rynux/setup/
chmod +x /usr/share/rynux/setup/*.sh

echo "🖥️ [30-setup-tui] Instalando aplicação TUI /usr/local/bin/rynux-setup..."
cp /tmp/setup/rynux-setup /usr/local/bin/rynux-setup
chmod +x /usr/local/bin/rynux-setup

cat << 'EOF' > /usr/share/applications/rynux-setup.desktop
[Desktop Entry]
Name=Fedora RYnux Setup
Name[pt_BR]=Pós-Instalação do Fedora RYnux
Comment=Instale aplicativos Flatpak, fontes Microsoft e o laboratório Distrobox
Icon=fedora_rynux
Exec=/usr/local/bin/rynux-setup
Terminal=true
Type=Application
Categories=System;Settings;PackageManager;
Keywords=rynux;setup;flatpak;distrobox;pos-instalacao;
EOF

rm -rf /tmp/setup
echo "✅ [30-setup-tui] Aplicação TUI 'rynux-setup' instalada com sucesso."
