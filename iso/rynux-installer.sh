#!/usr/bin/env bash
set -uo pipefail

# Garante mapa de teclas ABNT2 no console do instalador
loadkeys br-abnt2 2>/dev/null || true

PAYLOAD_IMAGE="@@PAYLOAD_IMAGE@@"
BACKTITLE="Fedora RYnux - Instalador do Sistema (bootc)"

while true; do
    # Descobre o disco físico onde a ISO Live está montada para não listá-lo como destino
    LIVE_DEV=$(findmnt -n -o SOURCE /run/initramfs/live 2>/dev/null || true)
    LIVE_PKNAME=""
    if [[ -n "$LIVE_DEV" ]]; then
        LIVE_PKNAME=$(lsblk -no PKNAME "$LIVE_DEV" 2>/dev/null | head -n1 || true)
        [[ -z "$LIVE_PKNAME" ]] && LIVE_PKNAME=$(basename "$LIVE_DEV")
    fi

    # Monta a lista de discos disponíveis (ignorando loop=7, rom=11, zram=252)
    DISK_ARGS=()
    while read -r name size model tran; do
        base_name=$(basename "$name")
        if [[ -n "$LIVE_PKNAME" && "$base_name" == "$LIVE_PKNAME" ]]; then
            continue
        fi
        desc=$(printf "%-8s | %-6s | %s" "${size:-N/A}" "${tran:-disk}" "${model:-Disco Generico}")
        DISK_ARGS+=("$name" "$desc")
    done < <(lsblk -d -n -p -e 7,11,252 -o NAME,SIZE,MODEL,TRAN | sort)

    if [[ ${#DISK_ARGS[@]} -eq 0 ]]; then
        dialog --backtitle "$BACKTITLE" \
            --title "Nenhum Disco Encontrado" \
            --msgbox "Nenhum disco rígido ou NVMe disponível foi detectado.\n\nPressione OK para abrir um shell de diagnóstico." 10 60
        exec /bin/bash -l
    fi

    TARGET_DISK=$(dialog --clear --backtitle "$BACKTITLE" \
        --title "Seleção do Disco de Destino" \
        --cancel-label "Abrir Shell" \
        --menu "Selecione o disco onde o Fedora RYnux será instalado.\n\nO disco será formatado em GPT + BTRFS (compress=zstd:1):" \
        18 76 8 \
        "${DISK_ARGS[@]}" \
        2>&1 >/dev/tty) || {
            clear
            echo "Entrando no shell de manutenção. Digite 'exit' para retornar ao instalador."
            /bin/bash -l
            continue
        }

    # Confirmação destrutiva
    dialog --clear --backtitle "$BACKTITLE" \
        --title "⚠️  CONFIRMAR FORMATAÇÃO" \
        --defaultno \
        --yes-label "Sim, Formatar e Instalar" \
        --no-label "Voltar" \
        --yesno "ATENÇÃO: TODOS OS DADOS no disco abaixo serão permanentemente apagados!\n\n  Disco selecionado: ${TARGET_DISK}\n  Imagem a instalar: ${PAYLOAD_IMAGE}\n  Sistema de arquivos: BTRFS\n\nDeseja prosseguir com a instalação?" \
        15 72 || continue

    clear
    echo "===================================================================="
    echo " Iniciando instalação do Fedora RYnux em ${TARGET_DISK}..."
    echo "===================================================================="
    echo ""

    # Garante que nenhuma partição do disco alvo esteja montada ou em uso
    for part in $(lsblk -ln -o NAME -p "$TARGET_DISK" | tail -n +2); do
        umount -fl "$part" 2>/dev/null || true
        swapoff "$part" 2>/dev/null || true
    done
    wipefs -a "$TARGET_DISK" 2>/dev/null || true

    # Executa a instalação oficial via bootc a partir do container embutido na ISO
    if podman run --rm --privileged \
        --pid=host \
        --net=host \
        --security-opt label=type:unconfined_t \
        -v /dev:/dev \
        -v /var/lib/containers:/var/lib/containers \
        -v /etc/containers:/etc/containers \
        "${PAYLOAD_IMAGE}" \
        bootc install to-disk \
            --wipe \
            --filesystem btrfs \
            --source-imgref "containers-storage:${PAYLOAD_IMAGE}" \
            --target-imgref "${PAYLOAD_IMAGE}" \
            --skip-fetch-check \
            "${TARGET_DISK}"; then

        sync
        dialog --clear --backtitle "$BACKTITLE" \
            --title "✅ Instalação Concluída com Sucesso!" \
            --yes-label "Reiniciar Agora" \
            --no-label "Abrir Shell" \
            --yesno "O Fedora RYnux foi instalado com sucesso em ${TARGET_DISK}!\n\nRemova a mídia de instalação (pendrive) quando o computador desligar.\nNo primeiro boot, o assistente do KDE Plasma (Plasma Setup) guiará a criação do seu usuário.\n\nDeseja reiniciar agora?" \
            15 72 && systemctl reboot || exec /bin/bash -l
    else
        echo ""
        echo "❌ ERRO: A instalação falhou. Verifique as mensagens acima."
        read -rp "Pressione ENTER para abrir um shell de diagnóstico..." _
        /bin/bash -l
    fi
done
