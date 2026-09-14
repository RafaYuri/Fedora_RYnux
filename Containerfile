# ====================================================================
# ESTÁGIO 1: Construção do Sistema (Herdado como 'final')
# ====================================================================
FROM quay.io/fedora/fedora-bootc:latest AS final
LABEL ostree.bootable="true"
LABEL containers.bootc="1"

# Instalando o KDE Desktop com otimização de cache para nuvem
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf update -y && \
    dnf install --setopt=tsflags=nodocs -y @kde-desktop --exclude=kcharselect,krfb,kwrite,akonadi* && \
    dnf clean all

# Copia a pasta de listas de pacotes para dentro da imagem temporariamente
COPY pacotes/ /tmp/pacotes/

# Instala os pacotes a partir das listas .txt
RUN --mount=type=cache,dst=/var/cache/dnf \
    grep -v '^#' /tmp/pacotes/packages_system.txt | tr '\n' ' ' | xargs dnf install --setopt=tsflags=nodocs -y && \
    grep -v '^#' /tmp/pacotes/packages_dev_cli.txt | tr '\n' ' ' | xargs dnf install --setopt=tsflags=nodocs -y && \
    grep -v '^#' /tmp/pacotes/packages_apps.txt | tr '\n' ' ' | xargs dnf install --setopt=tsflags=nodocs -y && \
    dnf remove -y PackageKit plasma-browser-integration firewall-config && \
    dnf clean all

# Instalando development tools
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf group install --setopt=tsflags=nodocs -y development-tools && \
    dnf clean all

# Instalando repositórios RPM Fusion, codecs multimídia e removendo o repositório
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install --setopt=tsflags=nodocs -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y --allowerasing gstreamer1-plugins-ugly gstreamer1-plugins-bad-freeworld ffmpeg libavcodec-freeworld pipewire-codec-aptx && \
    dnf remove -y rpmfusion-free-release rpmfusion-nonfree-release && \
    dnf clean all

# Força a geração do cache do fontconfig no nível do sistema
RUN fc-cache -fsv && rm -rf /var/cache/fontconfig/*

# Habilitar o serviço de virtualização para iniciar com o sistema
RUN systemctl enable libvirtd

# Configuração dos repositórios Flatpak (Flathub puro)
RUN dnf remove -y fedora-flathub-remote && \
    mkdir -p /etc/flatpak/remotes.d/ && \
    curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo && \
    rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

# ====================================================================
# BRANDING: Ícones do Sistema, Menu Iniciar e KInfoCenter
# ====================================================================
COPY branding/icons/ /tmp/branding_icons/
COPY branding/fedora_rynux.png /tmp/branding_icons/512x512/fedora_rynux_512x512.png

RUN for res in 16 24 32 48 64 128 256 512; do \
        target_dir="/usr/share/icons/hicolor/${res}x${res}/apps"; \
        mkdir -p "$target_dir" && \
        cp "/tmp/branding_icons/${res}x${res}/fedora_rynux_${res}x${res}.png" "${target_dir}/fedora_rynux.png" && \
        ln -sf fedora_rynux.png "${target_dir}/fedora-logo-icon.png" && \
        ln -sf fedora_rynux.png "${target_dir}/start-here-kde.png" && \
        ln -sf fedora_rynux.png "${target_dir}/distributor-logo.png" && \
        ln -sf fedora_rynux.png "${target_dir}/distributor-logo-fedora.png"; \
    done && \
    # Gera um SVG escalável embutindo o PNG em base64 para sobrepor os SVGs do Fedora
    mkdir -p /usr/share/icons/hicolor/scalable/apps && \
    b64="$(base64 -w 0 /tmp/branding_icons/512x512/fedora_rynux_512x512.png)" && \
    printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512" width="100%%" height="100%%"><image width="512" height="512" xlink:href="data:image/png;base64,%s"/></svg>\n' "$b64" > /usr/share/icons/hicolor/scalable/apps/fedora_rynux.svg && \
    # Sobrescreve os links vetoriais no hicolor
    ln -sf fedora_rynux.svg /usr/share/icons/hicolor/scalable/apps/distributor-logo.svg && \
    ln -sf fedora_rynux.svg /usr/share/icons/hicolor/scalable/apps/distributor-logo-fedora.svg && \
    ln -sf fedora_rynux.svg /usr/share/icons/hicolor/scalable/apps/fedora-logo-icon.svg && \
    # Substitui eventuais SVGs existentes nos temas Breeze ativos
    find /usr/share/icons/breeze* -name "distributor-logo*.svg" -exec ln -sf /usr/share/icons/hicolor/scalable/apps/fedora_rynux.svg {} + 2>/dev/null || true && \
    rm -rf /tmp/branding_icons && \
    # Atualiza layouts do painel do Plasma
    find /usr/share/plasma/ -name "layout.js" -exec sed -i 's/"fedora-logo-icon"/"fedora_rynux"/g' {} + && \
    find /usr/share/plasma/ -name "layout.js" -exec sed -i 's/"start-here-kde"/"fedora_rynux"/g' {} + && \
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor

# ====================================================================
# BRANDING: Identidade do Sistema (/etc/os-release)
# ====================================================================
RUN sed -i 's/NAME="Fedora Linux"/NAME="Fedora RYnux"/' /usr/lib/os-release && \
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Fedora RYnux"/' /usr/lib/os-release && \
    sed -i 's|^LOGO=.*|LOGO="fedora_rynux"|' /usr/lib/os-release && \
    sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release && \
    sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release && \
    sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release && \
    sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release

# ====================================================================
# PLYMOUTH: Substituição da logo e definição do tema
# ====================================================================
COPY branding/fedora_rynux_plymouth.png /usr/share/plymouth/themes/spinner/watermark.png
RUN plymouth-set-default-theme spinner

# Mascara o serviço de remount para evitar erros visuais inofensivos no boot
RUN systemctl mask systemd-remount-fs.service

# ====================================================================
# BRANDING: Fastfetch (ASCII Art e Configuração de Cores)
# ====================================================================
RUN mkdir -p /usr/share/fastfetch /etc/fastfetch /etc/xdg/fastfetch

COPY branding/fedora_rynux.txt /usr/share/fastfetch/fedora_rynux.txt
COPY branding/fastfetch.jsonc /etc/fastfetch/config.jsonc
RUN ln -sf /etc/fastfetch/config.jsonc /etc/xdg/fastfetch/config.jsonc

# ====================================================================
# CORREÇÃO: Impedir reboots automáticos do bootc
# ====================================================================
RUN mkdir -p /etc/systemd/system/bootc-fetch-apply-updates.service.d/ && \
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/bootc upgrade --quiet\n' \
    > /etc/systemd/system/bootc-fetch-apply-updates.service.d/override.conf

# ====================================================================
# NOTIFICAÇÃO DE REBOOT: Versão para Bash + Oh-My-Bash
# ====================================================================
RUN printf '%s\n' \
    '#!/bin/bash' \
    'if [ -f /run/reboot-required ]; then' \
    '    echo -e "\e[1;36m🔄 Atualização pendente, reinicie para aplicação.\e[0m"' \
    'fi' \
    > /usr/local/bin/bootc-notify.sh && \
    chmod +x /usr/local/bin/bootc-notify.sh

# ====================================================================
# CONFIGURAÇÃO DE REDE / FIREWALL
# ====================================================================
RUN firewall-offline-cmd --add-service=kdeconnect

# ====================================================================
# OTIMIZAÇÃO DE MEMÓRIA (ZRAM), DRACUT E LIMPEZA
# ====================================================================
RUN echo -e "[zram0]\nzram-size = ram\ncompression-algorithm = zstd" > /etc/systemd/zram-generator.conf

# Instalação dos módulos extras para o kernel mais recente, rebuild do initramfs e limpeza
RUN kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)" && \
    dnf install --setopt=tsflags=nodocs -y "kernel-modules-extra-${kver}" && \
    dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}" && \
    dnf clean all && \
    rm -rfv /var/cache/* /var/lib/dnf /var/log/* /tmp/* /var/tmp/*

# LINTING: Verifica integridade da imagem para bootc/OSTree
RUN bootc container lint