#!/bin/bash
# ==============================================================================
# Script: uninstall.sh
# Projeto: Bootc KCM (Fedora RYnux)
# Descrição: Remove todos os binários, plugins, políticas Polkit, serviços D-Bus
#            e unidades systemd instalados pelo Bootc KCM.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/usr}"
MANIFEST_FILE="${SCRIPT_DIR}/.installed_files.manifest"

run_priv() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

echo "🗑️  [Bootc KCM] Desinstalando módulo Bootc KCM..."

# Desabilita a unidade systemd user antes de remover os arquivos
if [[ $EUID -ne 0 ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now rynux-bootc-reboot-notify.path 2>/dev/null || true
    systemctl --user stop rynux-bootc-reboot-notify.service 2>/dev/null || true
fi
run_priv systemctl --global disable rynux-bootc-reboot-notify.path 2>/dev/null || true

FILES_TO_REMOVE=(
    "${PREFIX}/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_bootc.so"
    "${PREFIX}/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_bootc.so"
    "${PREFIX}/libexec/kf6/kauth/kcm_bootc_authhelper"
    "${PREFIX}/lib/kf6/kauth/kcm_bootc_authhelper"
    "${PREFIX}/share/polkit-1/actions/org.fedoraproject.rynux.bootc.policy"
    "${PREFIX}/share/polkit-1/rules.d/90-rynux-kcm-bootc.rules"
    "${PREFIX}/share/dbus-1/system.d/org.fedoraproject.rynux.bootc.conf"
    "${PREFIX}/share/dbus-1/system-services/org.fedoraproject.rynux.bootc.service"
    "${PREFIX}/share/applications/kcm_bootc.desktop"
    "${PREFIX}/bin/rynux-bootc-desktop-notify.sh"
    "${PREFIX}/lib/systemd/user/rynux-bootc-reboot-notify.path"
    "${PREFIX}/lib/systemd/user/rynux-bootc-reboot-notify.service"
)

if [[ -f "$MANIFEST_FILE" ]]; then
    while IFS= read -r file; do
        [[ -n "$file" ]] && FILES_TO_REMOVE+=("$file")
    done < "$MANIFEST_FILE"
fi

for f in "${FILES_TO_REMOVE[@]}"; do
    if [[ -e "$f" || -L "$f" ]]; then
        echo "   Removendo: $f"
        run_priv rm -f "$f"
    fi
done

rm -f "$MANIFEST_FILE"

echo "🔄 [Bootc KCM] Recarregando D-Bus, Polkit e cache do KDE..."
run_priv systemctl reload dbus-broker.service 2>/dev/null || run_priv systemctl reload dbus.service 2>/dev/null || true
run_priv systemctl restart polkit.service 2>/dev/null || true

if [[ $EUID -ne 0 ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "✅ [Bootc KCM] Desinstalação concluída com sucesso."
