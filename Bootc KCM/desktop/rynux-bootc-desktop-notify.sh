#!/bin/bash
# ==============================================================================
# Script: rynux-bootc-desktop-notify.sh
# Descrição: Evolução gráfica (daemonless) do bootc-notify.sh do Fedora RYnux.
#            Disparado automaticamente pelo systemd user via inotify
#            (PathExists=/run/reboot-required) quando uma atualização do bootc
#            entra em estado 'staged' aguardando reinicialização.
# ==============================================================================
set -euo pipefail

if [ ! -f /run/reboot-required ]; then
    exit 0
fi

if ! command -v notify-send >/dev/null 2>&1; then
    exit 0
fi

ACTION="$(notify-send \
    --app-name="Fedora RYnux (bootc)" \
    --icon="fedora_rynux" \
    --urgency=normal \
    --action="reboot=Reiniciar Agora" \
    --action="settings=Abrir Painel Bootc" \
    "🔄 Atualização do Sistema Pronta" \
    "Uma nova imagem do Fedora RYnux foi preparada (staged) pelo bootc. Reinicie o computador para aplicar." || true)"

case "$ACTION" in
    reboot)
        qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot 2>/dev/null \
            || qdbus org.kde.LogoutPrompt /LogoutPrompt promptReboot 2>/dev/null \
            || systemctl reboot
        ;;
    settings)
        systemsettings kcm_bootc >/dev/null 2>&1 &
        ;;
esac
