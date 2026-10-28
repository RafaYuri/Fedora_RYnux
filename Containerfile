# ====================================================================
# ESTÁGIO 1: Construção do Sistema (Base Fedora 45)
# ====================================================================
FROM quay.io/fedora/fedora-bootc:45 AS final
LABEL ostree.bootable="true"
LABEL containers.bootc="1"

# Instalando o KDE Desktop com otimização de cache para nuvem
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf update -y && \
    dnf install --setopt=tsflags=nodocs -y @kde-desktop --exclude=kcharselect,plasma-discover-packagekit,krfb,kwrite,akonadi* && \
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

# Configuração de compressão BTRFS com zstd
COPY config/01-args.toml /tmp/sysconfig/
RUN mv -v /tmp/sysconfig/01-args.toml /usr/lib/bootc/kargs.d/01-args.toml && \
    rm -rf /tmp/*

# Instalando repositórios RPM Fusion, codecs multimídia e removendo o repositório
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install --setopt=tsflags=nodocs -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y --allowerasing gstreamer1-plugins-ugly gstreamer1-plugins-bad-freeworld ffmpeg libavcodec-freeworld pipewire-codec-aptx && \
    dnf remove -y rpmfusion-free-release rpmfusion-nonfree-release && \
    dnf clean all

# Geração do cache de fontes estático e preservação para o boot
RUN fc-cache -f

# Virtualização ativada sob demanda por sockets
RUN systemctl enable virtqemud.socket virtnetworkd.socket virtstoraged.socket 2>/dev/null || systemctl enable libvirtd.socket

# Configuração dos repositórios Flatpak (Flathub puro)
RUN dnf remove -y fedora-flathub-remote && \
    mkdir -p /etc/flatpak/remotes.d/ && \
    curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo && \
    rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

# Correção para impedir reboots automáticos do bootc e abertura do firewall para KDE Connect
RUN mkdir -p /etc/systemd/system/bootc-fetch-apply-updates.service.d/ && \
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/bootc upgrade --quiet\n' \
    > /etc/systemd/system/bootc-fetch-apply-updates.service.d/override.conf && \
    firewall-offline-cmd --add-service=kdeconnect

# ====================================================================
# CONFIGURAÇÃO MODULAR VIA SHELL SCRIPTS (build_scripts/)
# ====================================================================
COPY branding/ /tmp/branding/
COPY setup/ /tmp/setup/
COPY build_scripts/ /tmp/build_scripts/

# 1. Identidade visual (Ícones, os-release, Plymouth BGRT e Fastfetch)
# 2. Oh My Bash, notificação de atualização no .bashrc e Homebrew nativos
# 3. Central TUI de Pós-Instalação (rynux-setup) e scripts em /usr/share/rynux/setup
# 4. Consolidação de usuários/grupos em /usr/lib/{passwd,group} e rebuild do initramfs
RUN chmod +x /tmp/build_scripts/*.sh && \
    /tmp/build_scripts/10-branding.sh && \
    /tmp/build_scripts/20-shell-and-homebrew.sh && \
    /tmp/build_scripts/30-setup-tui.sh && \
    /tmp/build_scripts/40-sysusers-and-initramfs.sh && \
    rm -rf /tmp/build_scripts

# Instalação dos módulos extras para o userspace (fora do initramfs) e limpeza final
RUN kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)" && \
    dnf install --setopt=tsflags=nodocs -y "kernel-modules-extra-${kver}" && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/lib/dnf /var/log/* /tmp/* /var/tmp/*

# LINTING: Verifica integridade da imagem para bootc/OSTree
RUN bootc container lint
