#!/bin/bash
# ==============================================================================
# Script: install.sh
# Projeto: Bootc KCM (Fedora RYnux)
# Descrição: Compila e instala o módulo KCM do bootc (com helper KAuth, regras
#            Polkit e unidade systemd user daemonless para notificação gráfica).
#            Compatível tanto com build de imagem (Containerfile) quanto com
#            teste local em sistemas imutáveis bootc (via Podman + usr-overlay).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
STAGING_DIR="${BUILD_DIR}/staging"
PREFIX="${PREFIX:-/usr}"
DESTDIR="${DESTDIR:-}"
ENABLE_USR_OVERLAY=0
FORCE_CONTAINER_BUILD=0

BUILD_DEPS=(
    cmake
    extra-cmake-modules
    gcc-c++
    ninja-build
     gettext
    qt6-qtbase-devel
    qt6-qtdeclarative-devel
    kf6-kcoreaddons-devel
    kf6-ki18n-devel
    kf6-kcmutils-devel
    kf6-kauth-devel
)

usage() {
    cat <<EOF
Uso: ./install.sh [OPÇÕES]

Opções:
  --usr-overlay       Ativa 'bootc usr-overlay' automaticamente se /usr for somente-leitura
  --container-build   Compila dentro de um container Podman efêmero (ideal para host imutável)
  --prefix <DIR>      Define o prefixo de instalação (padrão: /usr)
  --destdir <DIR>     Define o diretório de destino para staging (ex.: empacotamento)
  -h, --help          Exibe esta mensagem de ajuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --usr-overlay)
            ENABLE_USR_OVERLAY=1
            shift
            ;;
        --container-build)
            FORCE_CONTAINER_BUILD=1
            shift
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --destdir)
            DESTDIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Opção desconhecida: $1" >&2
            usage
            exit 1
            ;;
    esac
done

run_priv() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

check_usr_writable() {
    local target_Check="${DESTDIR}${PREFIX}"
    if [[ -w "$target_Check" ]]; then
        return 0
    fi
    # Tenta verificar como root se /usr está montado como read-only (comum em bootc/OSTree)
    if run_priv test -w "$target_Check" 2>/dev/null; then
        return 0
    fi
    return 1
}

has_native_build_deps() {
    command -v cmake >/dev/null 2>&1 || return 1
    command -v g++ >/dev/null 2>&1 || return 1
    [[ -d /usr/share/ECM/cmake ]] || return 1
    [[ -d /usr/lib64/cmake/KF6KCMUtils ]] || return 1
    [[ -d /usr/lib64/cmake/KF6Auth ]] || return 1
    return 0
}

build_native() {
    echo "🔨 [Bootc KCM] Compilando nativamente com CMake..."
    if ! has_native_build_deps; then
        echo "📦 [Bootc KCM] Instalando dependências de compilação via DNF..."
        run_priv dnf install --setopt=tsflags=nodocs -y "${BUILD_DEPS[@]}"
    fi

    rm -rf "$BUILD_DIR"
    cmake -B "$BUILD_DIR" -S "$SCRIPT_DIR" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF

    cmake --build "$BUILD_DIR" --parallel "$(nproc)"
    mkdir -p "$STAGING_DIR"
    DESTDIR="$STAGING_DIR" cmake --install "$BUILD_DIR"
}

build_in_podman() {
    if ! command -v podman >/dev/null 2>&1; then
        echo "❌ Erro: 'podman' não encontrado e os pacotes '-devel' não estão instalados no host." >&2
        exit 1
    fi

    local fedora_ver
    fedora_ver="$(rpm -E %fedora 2>/dev/null || echo 'latest')"
    local builder_img="quay.io/fedora/fedora:${fedora_ver}"
    if ! podman image exists "$builder_img" && podman image exists "quay.io/fedora/fedora:latest"; then
        builder_img="quay.io/fedora/fedora:latest"
    fi

    echo "🐳 [Bootc KCM] Compilando em container Podman efêmero (${builder_img})..."
    rm -rf "$STAGING_DIR"
    mkdir -p "$BUILD_DIR" "$STAGING_DIR"

    podman run --rm \
        --security-opt label=disable \
        -v bootc-kcm-dnf-cache:/var/cache/libdnf5:Z \
        -v "${SCRIPT_DIR}:/src:Z" \
        -w /src \
        "$builder_img" \
        bash -exc "
            dnf install --setopt=keepcache=True --setopt=tsflags=nodocs -y ${BUILD_DEPS[*]} &&
            cmake -B /src/build -S /src \
                -DCMAKE_INSTALL_PREFIX=${PREFIX} \
                -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_TESTING=OFF &&
            cmake --build /src/build --parallel \$(nproc) &&
            DESTDIR=/src/build/staging cmake --install /src/build
        "
}

echo "🚀 [Bootc KCM] Iniciando processo de compilação e instalação..."

if [[ $FORCE_CONTAINER_BUILD -eq 1 ]]; then
    build_in_podman
elif has_native_build_deps || [[ ! -f /run/ostree-booted ]]; then
    build_native
else
    echo "ℹ️  Sistema imutável (ostree/bootc) detectado sem pacotes '-devel' locais."
    echo "   Utilizando Podman para compilar sem poluir o sistema base..."
    build_in_podman
fi

# Verifica se o destino (/usr) é gravável; caso seja um host bootc em execução, oferece usr-overlay
if [[ -z "$DESTDIR" ]] && ! check_usr_writable; then
    if [[ $ENABLE_USR_OVERLAY -eq 1 ]]; then
        echo "🔓 [Bootc KCM] Ativando overlayfs transiente em /usr ('bootc usr-overlay')..."
        run_priv bootc usr-overlay
    else
        echo "⚠️  O diretório ${PREFIX} está montado como somente-leitura (padrão de sistemas bootc)."
        read -r -p "Deseja ativar 'sudo bootc usr-overlay' para instalar e testar agora? [s/N] " resp
        if [[ "$resp" =~ ^[sS](im)?$ || "$resp" =~ ^[yY](es)?$ ]]; then
            run_priv bootc usr-overlay
        else
            echo "ℹ️  Binários compilados estão prontos em: ${STAGING_DIR}"
            echo "   Execute './install.sh --usr-overlay' quando quiser instalá-los no host."
            exit 0
        fi
    fi
fi

TARGET_ROOT="${DESTDIR:-/}"
echo "📂 [Bootc KCM] Instalando arquivos em ${TARGET_ROOT}..."
run_priv cp -rv "${STAGING_DIR}/"* "$TARGET_ROOT"

# Salva manifesto de arquivos instalados para desinstalação limpa
MANIFEST_FILE="${SCRIPT_DIR}/.installed_files.manifest"
(cd "$STAGING_DIR" && find . -type f -o -type l | sed 's|^\./|/|') > "$MANIFEST_FILE"

if [[ -z "$DESTDIR" ]]; then
    echo "🔄 [Bootc KCM] Atualizando configurações do D-Bus, Polkit e systemd..."
    run_priv systemctl reload dbus-broker.service 2>/dev/null || run_priv systemctl reload dbus.service 2>/dev/null || true
    run_priv systemctl restart polkit.service 2>/dev/null || true
    run_priv systemctl --global enable rynux-bootc-reboot-notify.path 2>/dev/null || true

    # Se estiver rodando em uma sessão gráfica de usuário, habilita o .path imediatamente
    if [[ $EUID -ne 0 ]] && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now rynux-bootc-reboot-notify.path 2>/dev/null || true
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
fi

echo "✅ [Bootc KCM] Instalação concluída com sucesso!"
echo "   Para abrir diretamente: systemsettings kcm_bootc"
