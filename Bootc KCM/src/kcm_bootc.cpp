#include "kcm_bootc.h"

#include <KAuth/Action>
#include <KAuth/ExecuteJob>
#include <KLocalizedString>
#include <KPluginFactory>

#include <QClipboard>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>

K_PLUGIN_CLASS_WITH_JSON(KcmBootc, "kcm_bootc.json")

KcmBootc::KcmBootc(QObject *parent, const KPluginMetaData &data)
    : KQuickManagedConfigModule(parent, data)
{
    setButtons(KQuickManagedConfigModule::NoAdditionalButton);

    // Verifica de imediato se /run/reboot-required existe (mesma lógica do bootc-notify.sh do RYnux)
    m_rebootRequiredFile = QFileInfo::exists(QStringLiteral("/run/reboot-required"));

    // Monitora /run via inotify (sem polling) para detectar criação/remoção de /run/reboot-required
    if (QFileInfo::exists(QStringLiteral("/run"))) {
        m_runWatcher.addPath(QStringLiteral("/run"));
        connect(&m_runWatcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &) {
            const bool existsNow = QFileInfo::exists(QStringLiteral("/run/reboot-required"));
            if (existsNow != m_rebootRequiredFile) {
                m_rebootRequiredFile = existsNow;
                Q_EMIT statusChanged();
                if (!m_busy) {
                    refreshStatus();
                }
            }
        });
    }

    refreshStatus();
}

QString KcmBootc::shortenDigest(const QString &digest)
{
    if (digest.isEmpty()) {
        return QStringLiteral("—");
    }
    if (digest.startsWith(QLatin1String("sha256:")) && digest.length() > 23) {
        return digest.left(19) + QStringLiteral("…") + digest.right(8);
    }
    if (digest.length() > 20) {
        return digest.left(12) + QStringLiteral("…") + digest.right(6);
    }
    return digest;
}

QString KcmBootc::formatIsoTimestamp(const QString &isoStr)
{
    if (isoStr.isEmpty()) {
        return QStringLiteral("—");
    }
    const QDateTime dt = QDateTime::fromString(isoStr, Qt::ISODate);
    if (!dt.isValid()) {
        return isoStr;
    }
    return QLocale::system().toString(dt.toLocalTime(), QStringLiteral("dd/MM/yyyy HH:mm:ss"));
}

void KcmBootc::appendLog(const QString &line)
{
    if (line.trimmed().isEmpty()) {
        return;
    }
    if (!m_logOutput.isEmpty()) {
        m_logOutput += QLatin1Char('\n');
    }
    m_logOutput += line;
    Q_EMIT logChanged();
}

void KcmBootc::clearMessages()
{
    m_errorMessage.clear();
    m_infoMessage.clear();
    Q_EMIT stateChanged();
}

void KcmBootc::copyToClipboard(const QString &text)
{
    if (QClipboard *clip = QGuiApplication::clipboard()) {
        clip->setText(text);
        m_infoMessage = i18n("Copiado para a área de transferência.");
        Q_EMIT stateChanged();
    }
}

void KcmBootc::requestReboot()
{
    // 1. Tenta o diálogo oficial de reinicialização da sessão do KDE Plasma 6
    QDBusMessage ksmMsg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.LogoutPrompt"),
        QStringLiteral("/LogoutPrompt"),
        QStringLiteral("org.kde.LogoutPrompt"),
        QStringLiteral("promptReboot"));
    QDBusMessage reply = QDBusConnection::sessionBus().call(ksmMsg, QDBus::Block, 3000);

    if (reply.type() == QDBusMessage::ErrorMessage) {
        // 2. Fallback direto via systemd-logind
        QDBusMessage loginMsg = QDBusMessage::createMethodCall(
            QStringLiteral("org.freedesktop.login1"),
            QStringLiteral("/org/freedesktop/login1"),
            QStringLiteral("org.freedesktop.login1.Manager"),
            QStringLiteral("Reboot"));
        loginMsg << true;
        QDBusConnection::systemBus().asyncCall(loginMsg);
    }
}

void KcmBootc::parseDeploymentSlot(const QJsonObject &slotObj,
                                   QString &outImage,
                                   QString &outTransport,
                                   QString &outVersion,
                                   QString &outDigest,
                                   QString &outTimestamp,
                                   QString &outArch,
                                   QString &outOstreeChecksum,
                                   bool &outPinned) const
{
    outPinned = slotObj.value(QStringLiteral("pinned")).toBool(false);

    const QJsonObject ostreeObj = slotObj.value(QStringLiteral("ostree")).toObject();
    outOstreeChecksum = ostreeObj.value(QStringLiteral("checksum")).toString();

    const QJsonObject imageStatusObj = slotObj.value(QStringLiteral("image")).toObject();
    outVersion = imageStatusObj.value(QStringLiteral("version")).toString(QStringLiteral("—"));
    outDigest = imageStatusObj.value(QStringLiteral("imageDigest")).toString();
    outTimestamp = formatIsoTimestamp(imageStatusObj.value(QStringLiteral("timestamp")).toString());
    outArch = imageStatusObj.value(QStringLiteral("architecture")).toString(QStringLiteral("x86_64"));

    // No bootc v1alpha1/v1beta1, 'image.image' é um objeto { "image": "...", "transport": "..." }
    const QJsonValue innerImageVal = imageStatusObj.value(QStringLiteral("image"));
    if (innerImageVal.isObject()) {
        const QJsonObject innerObj = innerImageVal.toObject();
        outImage = innerObj.value(QStringLiteral("image")).toString();
        outTransport = innerObj.value(QStringLiteral("transport")).toString(QStringLiteral("registry"));
    } else if (innerImageVal.isString()) {
        outImage = innerImageVal.toString();
        outTransport = QStringLiteral("registry");
    }
}

void KcmBootc::parseStatusPayload(const QVariantMap &payload)
{
    if (payload.contains(QStringLiteral("rebootRequiredFile"))) {
        m_rebootRequiredFile = payload.value(QStringLiteral("rebootRequiredFile")).toBool();
    } else {
        m_rebootRequiredFile = QFileInfo::exists(QStringLiteral("/run/reboot-required"));
    }

    if (payload.contains(QStringLiteral("autoTimerEnabled"))) {
        m_autoUpdatesEnabled = payload.value(QStringLiteral("autoTimerEnabled")).toBool();
    }

    const QString jsonStr = payload.value(QStringLiteral("statusJson")).toString();
    if (jsonStr.isEmpty()) {
        Q_EMIT statusChanged();
        return;
    }

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        m_errorMessage = i18n("Erro ao interpretar JSON do bootc: %1", err.errorString());
        Q_EMIT stateChanged();
        return;
    }

    const QJsonObject root = doc.object();
    const QJsonObject specObj = root.value(QStringLiteral("spec")).toObject();
    const QJsonObject statusObj = root.value(QStringLiteral("status")).toObject();

    // 1. Booted Deployment
    const QJsonValue bootedVal = statusObj.value(QStringLiteral("booted"));
    if (bootedVal.isObject()) {
        const QJsonObject bootedObj = bootedVal.toObject();
        parseDeploymentSlot(bootedObj,
                            m_bootedImage,
                            m_bootedTransport,
                            m_bootedVersion,
                            m_bootedDigest,
                            m_bootedTimestamp,
                            m_bootedArchitecture,
                            m_bootedOstreeChecksum,
                            m_bootedPinned);

        // Verifica cachedUpdate no deployment booted (populado após bootc upgrade --check)
        const QJsonValue cachedVal = bootedObj.value(QStringLiteral("cachedUpdate"));
        if (cachedVal.isObject()) {
            const QJsonObject cachedObj = cachedVal.toObject();
            const QString cachedDigest = cachedObj.value(QStringLiteral("imageDigest")).toString();
            if (!cachedDigest.isEmpty() && cachedDigest != m_bootedDigest) {
                m_updateAvailable = true;
                m_availableDigest = cachedDigest;
                m_availableVersion = cachedObj.value(QStringLiteral("version")).toString(QStringLiteral("Nova versão"));
                m_availableTimestamp = formatIsoTimestamp(cachedObj.value(QStringLiteral("timestamp")).toString());
            } else {
                m_updateAvailable = false;
            }
        }
    }

    // Fallback para spec.image se bootedImage vier vazio
    if (m_bootedImage.isEmpty()) {
        const QJsonObject specImg = specObj.value(QStringLiteral("image")).toObject();
        m_bootedImage = specImg.value(QStringLiteral("image")).toString(QStringLiteral("Desconhecida"));
        m_bootedTransport = specImg.value(QStringLiteral("transport")).toString(QStringLiteral("registry"));
    }

    // 2. Staged Deployment
    const QJsonValue stagedVal = statusObj.value(QStringLiteral("staged"));
    if (stagedVal.isObject() && !stagedVal.isNull()) {
        m_hasStaged = true;
        QString dummyTransport, dummyArch, dummyChecksum;
        bool dummyPinned = false;
        parseDeploymentSlot(stagedVal.toObject(),
                            m_stagedImage,
                            dummyTransport,
                            m_stagedVersion,
                            m_stagedDigest,
                            m_stagedTimestamp,
                            dummyArch,
                            dummyChecksum,
                            dummyPinned);

        // Se a atualização já está em staged, não precisamos mais exibir como "pendente de download"
        if (m_stagedDigest == m_availableDigest) {
            m_updateAvailable = false;
        }
    } else {
        m_hasStaged = false;
        m_stagedImage.clear();
        m_stagedVersion.clear();
        m_stagedDigest.clear();
        m_stagedTimestamp.clear();
    }

    // 3. Rollback Deployment
    m_rollbackQueued = statusObj.value(QStringLiteral("rollbackQueued")).toBool(false)
                       || specObj.value(QStringLiteral("bootOrder")).toString() == QLatin1String("rollback");

    const QJsonValue rollbackVal = statusObj.value(QStringLiteral("rollback"));
    if (rollbackVal.isObject() && !rollbackVal.isNull()) {
        m_hasRollback = true;
        QString dummyTransport, dummyArch, dummyChecksum;
        bool dummyPinned = false;
        parseDeploymentSlot(rollbackVal.toObject(),
                            m_rollbackImage,
                            dummyTransport,
                            m_rollbackVersion,
                            m_rollbackDigest,
                            m_rollbackTimestamp,
                            dummyArch,
                            dummyChecksum,
                            dummyPinned);
    } else {
        m_hasRollback = false;
        m_rollbackImage.clear();
        m_rollbackVersion.clear();
        m_rollbackDigest.clear();
        m_rollbackTimestamp.clear();
    }

    Q_EMIT statusChanged();
}

void KcmBootc::executeHelperAction(const QString &actionName,
                                   const QString &busyText,
                                   const QVariantMap &args)
{
    if (m_busy) {
        return;
    }

    m_busy = true;
    m_busyMessage = busyText;
    m_errorMessage.clear();
    m_infoMessage.clear();
    Q_EMIT stateChanged();

    KAuth::Action action(actionName);
    action.setHelperId(QStringLiteral("org.fedoraproject.rynux.bootc"));
    action.setArguments(args);
    action.setTimeout(600000); // 10 minutos para downloads de camadas grandes

    KAuth::ExecuteJob *job = action.execute();

    connect(job, &KAuth::ExecuteJob::newData, this, [this](const QVariantMap &data) {
        const QString line = data.value(QStringLiteral("line")).toString();
        if (!line.isEmpty()) {
            appendLog(line);
        }
    });

    connect(job, &KJob::result, this, [this, job, actionName]() {
        m_busy = false;
        m_busyMessage.clear();

        if (job->error() != 0) {
            m_errorMessage = job->errorString().isEmpty()
                                 ? i18n("A operação falhou (código %1).", job->error())
                                 : job->errorString();
            appendLog(QStringLiteral("[ERRO] ") + m_errorMessage);
            Q_EMIT stateChanged();
            return;
        }

        const QVariantMap replyData = job->data();
        parseStatusPayload(replyData);

        if (actionName.endsWith(QLatin1String(".check"))) {
            const bool checkReported = replyData.value(QStringLiteral("checkReportedUpdate"), false).toBool();
            if (m_updateAvailable || checkReported) {
                m_updateAvailable = true;
                m_infoMessage = i18n("Nova atualização da imagem encontrada no registro remoto!");
                Q_EMIT statusChanged();
            } else if (m_hasStaged) {
                m_infoMessage = i18n("Uma atualização já está preparada (staged) aguardando reinicialização.");
            } else {
                m_infoMessage = i18n("O sistema já está na versão mais recente da imagem.");
            }
        } else if (actionName.endsWith(QLatin1String(".upgrade"))) {
            if (m_hasStaged || m_rebootRequiredFile) {
                m_infoMessage = i18n("Atualização preparada com sucesso! Reinicie o sistema para aplicar a nova imagem.");
            } else {
                m_infoMessage = i18n("Verificação concluída: nenhuma nova camada precisou ser aplicada.");
            }
        } else if (actionName.endsWith(QLatin1String(".rollback"))) {
            m_infoMessage = i18n("Reversão (Rollback) agendada! Reinicie o sistema para iniciar na imagem anterior.");
        } else if (actionName.endsWith(QLatin1String(".toggleautotimer"))) {
            m_infoMessage = m_autoUpdatesEnabled
                                ? i18n("Atualizações automáticas em segundo plano ativadas.")
                                : i18n("Atualizações automáticas em segundo plano desativadas.");
        }

        Q_EMIT stateChanged();
    });

    job->start();
}

void KcmBootc::refreshStatus()
{
    executeHelperAction(QStringLiteral("org.fedoraproject.rynux.bootc.status"),
                        i18n("Lendo status da imagem bootc..."));
}

void KcmBootc::checkForUpdates()
{
    m_logOutput.clear();
    Q_EMIT logChanged();
    executeHelperAction(QStringLiteral("org.fedoraproject.rynux.bootc.check"),
                        i18n("Verificando atualizações no registro remoto..."));
}

void KcmBootc::performUpgrade()
{
    m_logOutput.clear();
    Q_EMIT logChanged();
    executeHelperAction(QStringLiteral("org.fedoraproject.rynux.bootc.upgrade"),
                        i18n("Baixando e preparando nova imagem do sistema (bootc upgrade)..."));
}

void KcmBootc::performRollback()
{
    m_logOutput.clear();
    Q_EMIT logChanged();
    executeHelperAction(QStringLiteral("org.fedoraproject.rynux.bootc.rollback"),
                        i18n("Agendando reversão atômica para a imagem anterior..."));
}

void KcmBootc::setAutoUpdates(bool enabled)
{
    executeHelperAction(QStringLiteral("org.fedoraproject.rynux.bootc.toggleautotimer"),
                        i18n("Alterando configuração do timer automático..."),
                        {{QStringLiteral("enable"), enabled}});
}

#include "kcm_bootc.moc"
