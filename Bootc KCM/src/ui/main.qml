import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property bool showLogs: false

    actions: [
        Kirigami.Action {
            text: i18n("Verificar Atualizações")
            icon.name: "view-refresh"
            enabled: !kcm.busy
            onTriggered: kcm.checkForUpdates()
        },
        Kirigami.Action {
            text: kcm.hasStaged ? i18n("Reverificar / Atualizar") : i18n("Baixar e Aplicar (Stage)")
            icon.name: "system-software-update"
            enabled: !kcm.busy
            onTriggered: kcm.performUpgrade()
        }
    ]

    // Diálogo de confirmação para Rollback Atômico
    QQC2.Dialog {
        id: rollbackDialog
        title: i18n("Confirmar Reversão Atômica (Rollback)")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.Cancel
        width: Math.min(root.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 26)

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Deseja agendar a reversão para a imagem anterior (%1) no próximo boot?\n\nNota: Caso haja uma atualização em estado 'staged', ela será descartada e a imagem anterior passará a ser o alvo padrão de inicialização.",
                           kcm.rollbackVersion !== "" ? kcm.rollbackVersion : kcm.rollbackShortDigest)
            }
        }

        onAccepted: kcm.performRollback()
    }

    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        // =====================================================================
        // 1. BANNERS DE STATUS E ALERTAS (InlineMessages)
        // =====================================================================

        // Banner de Reinicialização Necessária (/run/reboot-required, staged ou rollback agendado)
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.rebootRequired
            type: Kirigami.MessageType.Positive
            icon.name: "system-reboot"
            text: kcm.rollbackQueued
                  ? i18n("Reversão (Rollback) agendada para o próximo boot. Reinicie o sistema para iniciar na imagem anterior.")
                  : (kcm.hasStaged
                     ? i18n("Nova atualização preparada (Staged: %1). Reinicie o sistema para concluir a aplicação da imagem.", kcm.stagedVersion)
                     : i18n("Atualização pendente detectada (/run/reboot-required). Reinicie o sistema para aplicar as alterações."))
            actions: [
                Kirigami.Action {
                    text: i18n("Reiniciar Agora")
                    icon.name: "system-reboot"
                    onTriggered: kcm.requestReboot()
                }
            ]
        }

        // Banner de Nova Atualização Disponível no Registry Remoto
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.updateAvailable && !kcm.hasStaged
            type: Kirigami.MessageType.Information
            icon.name: "software-update-available"
            text: kcm.availableVersion !== ""
                  ? i18n("Há uma nova imagem disponível no registro remoto (Versão: %1).", kcm.availableVersion)
                  : i18n("Há uma nova camada/imagem disponível no registro remoto para download.")
            actions: [
                Kirigami.Action {
                    text: i18n("Baixar e Preparar Agora")
                    icon.name: "download"
                    enabled: !kcm.busy
                    onTriggered: kcm.performUpgrade()
                }
            ]
        }

        // Banner Informativo
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.infoMessage !== "" && !kcm.busy
            type: Kirigami.MessageType.Information
            text: kcm.infoMessage
            showCloseButton: true
            onVisibleChanged: {
                if (!visible && kcm.infoMessage !== "") {
                    kcm.clearMessages()
                }
            }
        }

        // Banner de Erro
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.errorMessage !== ""
            type: Kirigami.MessageType.Error
            text: kcm.errorMessage
            showCloseButton: true
            onVisibleChanged: {
                if (!visible && kcm.errorMessage !== "") {
                    kcm.clearMessages()
                }
            }
        }

        // Indicador de Operação em Andamento
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            visible: kcm.busy

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC2.BusyIndicator {
                    running: kcm.busy
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    QQC2.Label {
                        Layout.fillWidth: true
                        font.bold: true
                        text: kcm.busyMessage
                        wrapMode: Text.WordWrap
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        opacity: 0.75
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        text: i18n("Executando via KAuth sob demanda (nenhum daemon residente em segundo plano).")
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // =====================================================================
        // 2. CARD PRINCIPAL: IMAGEM ATIVA (BOOTED DEPLOYMENT)
        // =====================================================================
        Kirigami.AbstractCard {
            Layout.fillWidth: true

            header: RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "fedora_rynux"
                    fallback: "system-run"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Kirigami.Heading {
                        level: 2
                        text: i18n("Imagem Ativa (Booted)")
                    }

                    QQC2.Label {
                        opacity: 0.75
                        text: kcm.bootedImage !== "" ? kcm.bootedImage : i18n("Carregando informações do bootc...")
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                QQC2.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Atualizar Status")
                    display: QQC2.AbstractButton.IconOnly
                    enabled: !kcm.busy
                    onClicked: kcm.refreshStatus()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Recarregar status do bootc")
                }
            }

            contentItem: Kirigami.FormLayout {
                wideMode: true

                RowLayout {
                    Kirigami.FormData.label: i18n("Imagem OCI:")
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: kcm.bootedImage !== "" ? kcm.bootedImage : "—"
                        font.family: "monospace"
                    }

                    QQC2.ToolButton {
                        visible: kcm.bootedImage !== ""
                        icon.name: "edit-copy"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: kcm.copyToClipboard(kcm.bootedImage)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Copiar referência da imagem")
                    }
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Versão:")
                    text: kcm.bootedVersion !== "" ? kcm.bootedVersion : "—"
                    font.bold: true
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Compilada em:")
                    text: kcm.bootedTimestamp !== "" ? kcm.bootedTimestamp : "—"
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Digest (SHA256):")
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: kcm.bootedShortDigest
                        font.family: "monospace"
                        QQC2.ToolTip.visible: digestMouse.containsMouse && kcm.bootedDigest !== ""
                        QQC2.ToolTip.text: kcm.bootedDigest

                        MouseArea {
                            id: digestMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }

                    QQC2.ToolButton {
                        visible: kcm.bootedDigest !== ""
                        icon.name: "edit-copy"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: kcm.copyToClipboard(kcm.bootedDigest)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Copiar digest SHA256 completo")
                    }
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Transporte / Arquitetura:")
                    text: (kcm.bootedTransport !== "" ? kcm.bootedTransport : "registry")
                          + " • "
                          + (kcm.bootedArchitecture !== "" ? kcm.bootedArchitecture : "x86_64")
                          + (kcm.bootedPinned ? i18n(" • Fixada (Pinned)") : "")
                }
            }
        }

        // =====================================================================
        // 3. CARD DE IMAGEM PREPARADA (STAGED DEPLOYMENT)
        // =====================================================================
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            visible: kcm.hasStaged

            header: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "system-software-update"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Kirigami.Heading {
                        level: 3
                        text: i18n("Imagem Preparada para o Próximo Boot (Staged)")
                    }

                    QQC2.Label {
                        opacity: 0.75
                        text: i18n("Esta imagem já foi baixada e será ativada automaticamente ao reiniciar.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                QQC2.Button {
                    text: i18n("Reiniciar para Aplicar")
                    icon.name: "system-reboot"
                    onClicked: kcm.requestReboot()
                }
            }

            contentItem: Kirigami.FormLayout {
                wideMode: true

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Imagem Alvo:")
                    text: kcm.stagedImage !== "" ? kcm.stagedImage : "—"
                    font.family: "monospace"
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Nova Versão:")
                    text: kcm.stagedVersion !== "" ? kcm.stagedVersion : "—"
                    font.bold: true
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Data da Imagem:")
                    text: kcm.stagedTimestamp !== "" ? kcm.stagedTimestamp : "—"
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Novo Digest:")
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: kcm.stagedShortDigest
                        font.family: "monospace"
                    }

                    QQC2.ToolButton {
                        visible: kcm.stagedDigest !== ""
                        icon.name: "edit-copy"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: kcm.copyToClipboard(kcm.stagedDigest)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Copiar digest SHA256 completo")
                    }
                }
            }
        }

        // =====================================================================
        // 4. CARD DE RECUPERAÇÃO ATÔMICA (ROLLBACK DEPLOYMENT)
        // =====================================================================
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            visible: kcm.hasRollback

            header: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "edit-undo"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Kirigami.Heading {
                        level: 3
                        text: i18n("Imagem de Recuperação (Rollback)")
                    }

                    QQC2.Label {
                        opacity: 0.75
                        text: kcm.rollbackQueued
                              ? i18n("Esta imagem já está agendada para iniciar no próximo boot.")
                              : i18n("Versão anterior preservada localmente para reversão imediata em caso de problemas.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                QQC2.Button {
                    text: kcm.rollbackQueued ? i18n("Rollback Agendado") : i18n("Reverter no Próximo Boot")
                    icon.name: "edit-undo"
                    enabled: !kcm.busy && !kcm.rollbackQueued
                    onClicked: rollbackDialog.open()
                }
            }

            contentItem: Kirigami.FormLayout {
                wideMode: true

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Versão Anterior:")
                    text: kcm.rollbackVersion !== "" ? kcm.rollbackVersion : "—"
                    font.bold: true
                }

                QQC2.Label {
                    Kirigami.FormData.label: i18n("Data da Imagem:")
                    text: kcm.rollbackTimestamp !== "" ? kcm.rollbackTimestamp : "—"
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Digest Anterior:")
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: kcm.rollbackShortDigest
                        font.family: "monospace"
                    }

                    QQC2.ToolButton {
                        visible: kcm.rollbackDigest !== ""
                        icon.name: "edit-copy"
                        display: QQC2.AbstractButton.IconOnly
                        onClicked: kcm.copyToClipboard(kcm.rollbackDigest)
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: i18n("Copiar digest SHA256 completo")
                    }
                }
            }
        }

        // =====================================================================
        // 5. CONFIGURAÇÕES DE AUTOMAÇÃO E LOGS DE EXECUÇÃO
        // =====================================================================
        Kirigami.AbstractCard {
            Layout.fillWidth: true

            header: Kirigami.Heading {
                level: 3
                text: i18n("Automação e Diagnóstico")
            }

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        QQC2.Label {
                            text: i18n("Preparar atualizações automaticamente em segundo plano")
                            font.bold: true
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            opacity: 0.75
                            wrapMode: Text.WordWrap
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            text: i18n("Controla o timer nativo 'bootc-fetch-apply-updates.timer'. No Fedora RYnux, as atualizações são apenas preparadas (staged) sem reiniciar a máquina automaticamente.")
                        }
                    }

                    QQC2.Switch {
                        checked: kcm.autoUpdatesEnabled
                        enabled: !kcm.busy
                        onToggled: kcm.setAutoUpdates(checked)
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: kcm.logOutput !== ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: kcm.logOutput !== ""

                    QQC2.Button {
                        flat: true
                        icon.name: root.showLogs ? "arrow-down" : "arrow-right"
                        text: root.showLogs ? i18n("Ocultar Saída do Comando (bootc)") : i18n("Mostrar Saída do Comando (bootc)")
                        onClicked: root.showLogs = !root.showLogs
                    }

                    Item { Layout.fillWidth: true }

                    QQC2.ToolButton {
                        visible: root.showLogs && kcm.logOutput !== ""
                        icon.name: "edit-copy"
                        text: i18n("Copiar Log")
                        onClicked: kcm.copyToClipboard(kcm.logOutput)
                    }
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 10
                    visible: (root.showLogs || kcm.busy) && kcm.logOutput !== ""

                    QQC2.TextArea {
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        font.family: "monospace"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        text: kcm.logOutput
                    }
                }
            }
        }
    }
}
