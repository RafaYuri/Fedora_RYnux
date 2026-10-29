#!/bin/bash
# ==============================================================================
# Script: 10-branding.sh
# Descrição: Aplica a identidade visual do Fedora RYnux (Ícones, os-release,
#            Plymouth BGRT e Fastfetch) durante o build da imagem container.
# ==============================================================================
set -euo pipefail

echo "🎨 [10-branding] Aplicando ícones do Fedora RYnux..."

for res in 16 24 32 48 64 128 256 512; do
    for cat in apps places; do
        target_dir="/usr/share/icons/hicolor/${res}x${res}/${cat}"
        mkdir -p "$target_dir"
        cp "/tmp/branding/icons/${res}x${res}/fedora_rynux_${res}x${res}.png" "${target_dir}/fedora_rynux.png"
        ln -sf fedora_rynux.png "${target_dir}/fedora-logo-icon.png"
        ln -sf fedora_rynux.png "${target_dir}/start-here-kde.png"
        ln -sf fedora_rynux.png "${target_dir}/start-here.png"
        ln -sf fedora_rynux.png "${target_dir}/distributor-logo.png"
        ln -sf fedora_rynux.png "${target_dir}/distributor-logo-fedora.png"
    done
done

# Remove qualquer SVG residual do Fedora que possa sobrepor os PNGs
find /usr/share/icons/ -type f \( \
    -name "*fedora-logo*.svg" -o \
    -name "*start-here*.svg" -o \
    -name "*distributor-logo*.svg" \
\) -delete

# Substitui os logos legados em /usr/share/pixmaps
mkdir -p /usr/share/pixmaps
cp /tmp/branding/icons/512x512/fedora_rynux_512x512.png /usr/share/pixmaps/fedora_rynux.png
ln -sf fedora_rynux.png /usr/share/pixmaps/fedora-logo.png
ln -sf fedora_rynux.png /usr/share/pixmaps/fedora-gdm-logo.png
ln -sf fedora_rynux.png /usr/share/pixmaps/system-logo-white.png

# Atualiza layouts do painel do Plasma aceitando aspas simples ou duplas
find /usr/share/plasma/ -name "*.js" -exec sed -i -E \
    's/(["'\''"])(fedora-logo-icon|start-here-kde)(["'\''"])/\1fedora_rynux\3/g' {} +

# Atualiza o cache de ícones do hicolor e temas Breeze
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor
for theme in /usr/share/icons/breeze*; do
    [ -d "$theme" ] && gtk-update-icon-cache -q -t -f "$theme" 2>/dev/null || true
done
touch /usr/share/icons/hicolor

echo "🏷️ [10-branding] Configurando identidade em /usr/lib/os-release..."
sed -i 's/NAME="Fedora Linux"/NAME="Fedora RYnux"/' /usr/lib/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Fedora RYnux"/' /usr/lib/os-release
sed -i 's|^LOGO=.*|LOGO="fedora_rynux"|' /usr/lib/os-release
sed -i 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="fedora-rynux"|' /usr/lib/os-release
sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release
sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release
sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release
sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release

echo "🖥️ [10-branding] Configurando Plymouth (BGRT + Watermark) e Fastfetch..."
cp /tmp/branding/fedora_rynux_plymouth.png /usr/share/plymouth/themes/spinner/watermark.png
plymouth-set-default-theme bgrt
systemctl mask systemd-remount-fs.service

mkdir -p /usr/share/fastfetch /etc/fastfetch /etc/xdg/fastfetch
cp /tmp/branding/fedora_rynux.txt /usr/share/fastfetch/fedora_rynux.txt
cp /tmp/branding/fastfetch.jsonc /etc/fastfetch/config.jsonc
ln -sf /etc/fastfetch/config.jsonc /etc/xdg/fastfetch/config.jsonc

rm -rf /tmp/branding
echo "✅ [10-branding] Identidade visual aplicada com sucesso."
