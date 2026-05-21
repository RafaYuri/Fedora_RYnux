# ====================================================================
# ESTÁGIO 1: Construção do Sistema (Herdado como 'final')
# ====================================================================
FROM quay.io/fedora/fedora-bootc:latest AS final
LABEL ostree.bootable="true"
LABEL containers.bootc="1"


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

# Instala a IDE windsurf
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install -y windsurf && \
    dnf clean all

# Copia a pasta de listas de pacotes para dentro da imagem temporariamente
COPY pacotes/ /tmp/pacotes/

# Instala os pacotes a partir das listas .txt
RUN --mount=type=cache,dst=/var/cache/dnf \
    grep -v '^#' /tmp/pacotes/packages_system.txt | tr '\n' ' ' | xargs dnf install -y && \
    grep -v '^#' /tmp/pacotes/packages_dev_cli.txt | tr '\n' ' ' | xargs dnf install -y && \
    grep -v '^#' /tmp/pacotes/packages_apps.txt | tr '\n' ' ' | xargs dnf install -y && \
    dnf remove -y PackageKit plasma-browser-integration && \
    dnf clean all

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

# Configuração dos repositórios Flatpak (Flathub puro)
RUN dnf remove -y fedora-flathub-remote && \
    mkdir -p /etc/flatpak/remotes.d/ && \
    curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo && \
    rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

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

# ====================================================================
# CORREÇÃO: Impedir reboots automáticos do bootc
# ====================================================================
RUN mkdir -p /etc/systemd/system/bootc-fetch-apply-updates.service.d/ && \
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/bootc upgrade --queue --quiet\n' \
    > /etc/systemd/system/bootc-fetch-apply-updates.service.d/override.conf

# ====================================================================
# SCRIPT DE AVISO: Notificação de atualizações pendentes (Versão Final)
# ====================================================================

# 1. Cria o script que roda como root e valida a estrutura YAML do bootc
RUN printf '%s\n' \
    '#!/bin/bash' \
    '# Procura pela linha "staged:" isolada no YAML, o que indica que há um deploy agendado' \
    'if bootc status 2>/dev/null | grep -qE "^\s*staged:\s*$"; then' \
    '    touch /run/bootc-update-ready' \
    'else' \
    '    rm -f /run/bootc-update-ready' \
    'fi' \
    > /usr/local/bin/check-bootc-staged.sh && \
    chmod +x /usr/local/bin/check-bootc-staged.sh

# 2. Cria o serviço do systemd para executar a checagem
RUN printf '%s\n' \
    '[Unit]' \
    'Description=Verifica se existem atualizações prontas no bootc' \
    '[Service]' \
    'Type=oneshot' \
    'ExecStart=/usr/local/bin/check-bootc-staged.sh' \
    > /etc/systemd/system/bootc-check-staged.service

# 3. Cria o timer para rodar a checagem 1 minuto após o boot e a cada 15 minutos depois disso
RUN printf '%s\n' \
    '[Unit]' \
    'Description=Roda a checagem de staged updates do bootc periodicamente' \
    '[Timer]' \
    'OnBootSec=1min' \
    'OnUnitActiveSec=15min' \
    '[Install]' \
    'WantedBy=timers.target' \
    > /etc/systemd/system/bootc-check-staged.timer

# 4. Habilita o timer para iniciar junto com o sistema
RUN systemctl enable bootc-check-staged.timer

# 5. Cria o script do perfil do terminal (executado instantaneamente pelo usuário comum)
RUN printf '%s\n' \
    '#!/bin/bash' \
    'if [ -f /run/bootc-update-ready ]; then' \
    '    echo -e "\n\e[1;36m🔄 [Fedora RYnux]* Há uma atualização do sistema pronta para ser aplicada no próximo reboot.\e[0m\n"' \
    'fi' \
    > /etc/profile.d/bootc-pending-notify.sh && \
    chmod +x /etc/profile.d/bootc-pending-notify.sh

# ====================================================================
# OTIMIZAÇÕES DE KERNEL, MEMÓRIA E BOOT (Dracut / ZRAM)
# ====================================================================

# Otimização do ZRAM para alta compressão (zstd) e uso total da RAM
RUN echo -e "[zram0]\nzram-size = ram\ncompression-algorithm = zstd" > /etc/systemd/zram-generator.conf

# Remoção de módulos de rede NFS do Dracut para boot mais rápido e reconstrução do initramfs
RUN printf 'omit_dracutmodules+=" nfs "\nomit_drivers+=" nfs nfsv3 nfsv4 nfs_acl nfs_common sunrpc rxrpc rpcrdma auth_rpcgss rpcsec_gss_krb5 "\n' > /etc/dracut.conf.d/no-nfs.conf && \
    kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dracut -f /usr/lib/modules/${kver}/initramfs.img ${kver}

# LINTING: Verifica se a imagem atômica foi construída de forma íntegra e sem violações do OSTree
RUN bootc container lint

# ====================================================================
# ESTÁGIO 2: Otimização Extrema de Camadas com Chunkah
# ====================================================================
# Puxa a ferramenta de compressão da CoreOS
FROM quay.io/coreos/chunkah AS chunkah
ARG CHUNKAH_CONFIG_STR
# Monta a nossa imagem 'final' e comprime todas as camadas
RUN --mount=from=final,src=/,target=/chunkah,ro \
    --mount=type=bind,target=/run/src,rw \
    chunkah build --max-layers 128 \
    --prune /sysroot/ \
    --label ostree.commit- \
    --label ostree.final-diffid- \
    > /run/src/out.ociarchive

# ====================================================================
# ESTÁGIO 3: Imagem OCI Finalizada
# ====================================================================
# Gera o sistema a partir do arquivo comprimido
FROM oci-archive:out.ociarchive
LABEL ostree.bootable="true"
LABEL containers.bootc="1"
