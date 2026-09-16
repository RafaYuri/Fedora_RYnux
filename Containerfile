# ====================================================================
# ESTÁGIO 1: Construção do Sistema
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

# Geração do cache de fontes estático e preserva para o boot
RUN fc-cache -f

# Virtualização ativada sob demanda por sockets
RUN systemctl enable virtqemud.socket virtnetworkd.socket virtstoraged.socket 2>/dev/null || systemctl enable libvirtd.socket

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
    # Remove qualquer SVG residual do Fedora no hicolor escalável
    rm -f /usr/share/icons/hicolor/scalable/apps/fedora-logo-icon.svg \
          /usr/share/icons/hicolor/scalable/apps/distributor-logo*.svg \
          /usr/share/icons/hicolor/scalable/apps/fedora_rynux.svg && \
    # Remove logos vetorizados nos temas Breeze
    find /usr/share/icons/breeze* -name "*distributor-logo*.svg" -delete && \
    find /usr/share/icons/breeze* -name "*fedora-logo*.svg" -delete && \
    # Substitui os logos legados em /usr/share/pixmaps
    mkdir -p /usr/share/pixmaps && \
    cp /tmp/branding_icons/512x512/fedora_rynux_512x512.png /usr/share/pixmaps/fedora_rynux.png && \
    ln -sf fedora_rynux.png /usr/share/pixmaps/fedora-logo.png && \
    ln -sf fedora_rynux.png /usr/share/pixmaps/fedora-gdm-logo.png && \
    ln -sf fedora_rynux.png /usr/share/pixmaps/system-logo-white.png && \
    rm -rf /tmp/branding_icons && \
    # Atualiza layouts do painel do Plasma
    find /usr/share/plasma/ -name "layout.js" -exec sed -i 's/"fedora-logo-icon"/"fedora_rynux"/g' {} + && \
    find /usr/share/plasma/ -name "layout.js" -exec sed -i 's/"start-here-kde"/"fedora_rynux"/g' {} + && \
    # OTIMIZAÇÃO: Atualiza cache do hicolor E temas Breeze modificados (evita I/O e varredura do KDE no boot)
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor && \
    for theme in /usr/share/icons/breeze*; do \
        [ -d "$theme" ] && gtk-update-icon-cache -q -t -f "$theme" 2>/dev/null || true; \
    done && \
    touch /usr/share/icons/hicolor

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
# PLYMOUTH: Watermark Personalizado + Transição UEFI Suave
# ====================================================================
COPY branding/fedora_rynux_plymouth.png /usr/share/plymouth/themes/spinner/watermark.png
RUN plymouth-set-default-theme bgrt
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

# Configuração restritiva do Dracut: exclui drivers Intel/Nvidia, rede e LVM do initramfs
RUN printf '%s\n' \
    'hostonly="no"' \
    'reproducible="yes"' \
    'do_strip="yes"' \
    'omit_drivers+=" nouveau "' \
    'omit_dracutmodules+=" network network-manager lvm mdraid multipath fips iscsi nfs cifs qemu qemu-net "' \
    > /etc/dracut.conf.d/01-lean-initramfs.conf

# 1. Rebuild do initramfs enxuto (apenas com o kernel-core/modules básico)
RUN kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)" && \
    dracut -vf --compress "zstd -19 -T0" "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

# 2. Instalação dos módulos extras para o userspace (fora do initramfs) e limpeza final
RUN kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)" && \
    dnf install --setopt=tsflags=nodocs -y "kernel-modules-extra-${kver}" && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/lib/dnf /var/log/* /tmp/* /var/tmp/*

# LINTING: Verifica integridade da imagem para bootc/OSTree
RUN bootc container lint