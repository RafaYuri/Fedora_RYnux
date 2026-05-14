FROM quay.io/fedora/fedora-bootc:latest

# Instalando o KDE Desktop com otimização de cache para nuvem
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install -y @kde-desktop --exclude=kcharselect,krfb,kwrite && \
    dnf clean all

# Configurar a chave GPG e o repositório do Windsurf
RUN rpm --import https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/RPM-GPG-KEY-windsurf && \
    echo "[windsurf]" > /etc/yum.repos.d/windsurf.repo && \
    echo "name=Windsurf Repository" >> /etc/yum.repos.d/windsurf.repo && \
    echo "baseurl=https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/repo/" >> /etc/yum.repos.d/windsurf.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/windsurf.repo && \
    echo "autorefresh=1" >> /etc/yum.repos.d/windsurf.repo && \
    echo "gpgcheck=1" >> /etc/yum.repos.d/windsurf.repo && \
    echo "gpgkey=https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/RPM-GPG-KEY-windsurf" >> /etc/yum.repos.d/windsurf.repo

# Atualização do sistema e instalação dos pacotes adicionais
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf update -y && \
    dnf install -y kate wireshark fastfetch podman-compose podman-docker \
    plymouth plymouth-theme-spinner virt-manager qemu qemu-kvm libvirt curl gh git btop ripgrep eza \
    tesseract-langpack-por tesseract-langpack-eng tesseract-langpack-fra \
    glibc-langpack-pt \
    distrobox windsurf procps-ng file \
    mesa-vulkan-drivers mesa-va-drivers mesa-libGL \
    fwupd setroubleshoot \
    fira-code-fonts cascadia-code-fonts \
    cmake ninja-build gdb \
    && dnf remove -y PackageKit \
    && dnf clean all

# Instalando development tools
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf group install -y development-tools && \
    dnf clean all

# Instalando repositórios RPM Fusion, codecs multimídia e removendo o repositório
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y --allowerasing gstreamer1-plugins-ugly gstreamer1-plugins-bad-freeworld ffmpeg libavcodec-freeworld && \
    dnf remove -y rpmfusion-free-release rpmfusion-nonfree-release && \
    dnf clean all

# Habilitar o serviço de virtualização para iniciar com o sistema
RUN systemctl enable libvirtd

# Configuração dos repositórios Flatpak (Removendo a insistência do repositório Fedora)
RUN rm -rf /etc/flatpak/remotes.d/fedora* && \
    rm -rf /usr/share/flatpak/remotes.d/fedora* && \
    mkdir -p /etc/flatpak/remotes.d && \
    curl -o /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo

# Customizando a identidade do sistema para RYnux e adicionando o GitHub
RUN sed -i 's/NAME="Fedora Linux"/NAME="Fedora RYnux"/' /usr/lib/os-release && \
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Fedora RYnux"/' /usr/lib/os-release && \
    sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release && \
    sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/RafaYuri/Fedora_RYnux"|' /usr/lib/os-release && \
    sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release && \
    sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/RafaYuri/Fedora_RYnux/issues"|' /usr/lib/os-release

# Aplicando o tema BGRT padrão e injetando a logo do Fedora
RUN plymouth-set-default-theme spinner

# Mascara o serviço de remount para evitar erros visuais inofensivos no boot
RUN systemctl mask systemd-remount-fs.service

# LINTING: Verifica se a imagem atômica foi construída de forma íntegra e sem violações do OSTree
RUN bootc container lint