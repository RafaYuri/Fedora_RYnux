#pragma once

#include <KQuickManagedConfigModule>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QString>
#include <QVariantMap>

class KcmBootc : public KQuickManagedConfigModule
{
    Q_OBJECT

    // Estado de execução e mensagens
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString busyMessage READ busyMessage NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(QString infoMessage READ infoMessage NOTIFY stateChanged)
    Q_PROPERTY(QString logOutput READ logOutput NOTIFY logChanged)

    // Flags globais do sistema / atualização
    Q_PROPERTY(bool rebootRequired READ rebootRequired NOTIFY statusChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY statusChanged)
    Q_PROPERTY(QString availableVersion READ availableVersion NOTIFY statusChanged)
    Q_PROPERTY(QString availableDigest READ availableDigest NOTIFY statusChanged)
    Q_PROPERTY(QString availableTimestamp READ availableTimestamp NOTIFY statusChanged)
    Q_PROPERTY(bool autoUpdatesEnabled READ autoUpdatesEnabled NOTIFY statusChanged)

    // Imagem em execução (Booted)
    Q_PROPERTY(QString bootedImage READ bootedImage NOTIFY statusChanged)
    Q_PROPERTY(QString bootedTransport READ bootedTransport NOTIFY statusChanged)
    Q_PROPERTY(QString bootedVersion READ bootedVersion NOTIFY statusChanged)
    Q_PROPERTY(QString bootedDigest READ bootedDigest NOTIFY statusChanged)
    Q_PROPERTY(QString bootedShortDigest READ bootedShortDigest NOTIFY statusChanged)
    Q_PROPERTY(QString bootedTimestamp READ bootedTimestamp NOTIFY statusChanged)
    Q_PROPERTY(QString bootedArchitecture READ bootedArchitecture NOTIFY statusChanged)
    Q_PROPERTY(QString bootedOstreeChecksum READ bootedOstreeChecksum NOTIFY statusChanged)
    Q_PROPERTY(bool bootedPinned READ bootedPinned NOTIFY statusChanged)

    // Imagem preparada para o próximo boot (Staged)
    Q_PROPERTY(bool hasStaged READ hasStaged NOTIFY statusChanged)
    Q_PROPERTY(QString stagedImage READ stagedImage NOTIFY statusChanged)
    Q_PROPERTY(QString stagedVersion READ stagedVersion NOTIFY statusChanged)
    Q_PROPERTY(QString stagedDigest READ stagedDigest NOTIFY statusChanged)
    Q_PROPERTY(QString stagedShortDigest READ stagedShortDigest NOTIFY statusChanged)
    Q_PROPERTY(QString stagedTimestamp READ stagedTimestamp NOTIFY statusChanged)

    // Imagem de reversão (Rollback)
    Q_PROPERTY(bool hasRollback READ hasRollback NOTIFY statusChanged)
    Q_PROPERTY(bool rollbackQueued READ rollbackQueued NOTIFY statusChanged)
    Q_PROPERTY(QString rollbackImage READ rollbackImage NOTIFY statusChanged)
    Q_PROPERTY(QString rollbackVersion READ rollbackVersion NOTIFY statusChanged)
    Q_PROPERTY(QString rollbackDigest READ rollbackDigest NOTIFY statusChanged)
    Q_PROPERTY(QString rollbackShortDigest READ rollbackShortDigest NOTIFY statusChanged)
    Q_PROPERTY(QString rollbackTimestamp READ rollbackTimestamp NOTIFY statusChanged)

public:
    explicit KcmBootc(QObject *parent, const KPluginMetaData &data);
    ~KcmBootc() override = default;

    bool busy() const { return m_busy; }
    QString busyMessage() const { return m_busyMessage; }
    QString errorMessage() const { return m_errorMessage; }
    QString infoMessage() const { return m_infoMessage; }
    QString logOutput() const { return m_logOutput; }

    bool rebootRequired() const { return m_rebootRequiredFile || m_hasStaged || m_rollbackQueued; }
    bool updateAvailable() const { return m_updateAvailable; }
    QString availableVersion() const { return m_availableVersion; }
    QString availableDigest() const { return m_availableDigest; }
    QString availableTimestamp() const { return m_availableTimestamp; }
    bool autoUpdatesEnabled() const { return m_autoUpdatesEnabled; }

    QString bootedImage() const { return m_bootedImage; }
    QString bootedTransport() const { return m_bootedTransport; }
    QString bootedVersion() const { return m_bootedVersion; }
    QString bootedDigest() const { return m_bootedDigest; }
    QString bootedShortDigest() const { return shortenDigest(m_bootedDigest); }
    QString bootedTimestamp() const { return m_bootedTimestamp; }
    QString bootedArchitecture() const { return m_bootedArchitecture; }
    QString bootedOstreeChecksum() const { return m_bootedOstreeChecksum; }
    bool bootedPinned() const { return m_bootedPinned; }

    bool hasStaged() const { return m_hasStaged; }
    QString stagedImage() const { return m_stagedImage; }
    QString stagedVersion() const { return m_stagedVersion; }
    QString stagedDigest() const { return m_stagedDigest; }
    QString stagedShortDigest() const { return shortenDigest(m_stagedDigest); }
    QString stagedTimestamp() const { return m_stagedTimestamp; }

    bool hasRollback() const { return m_hasRollback; }
    bool rollbackQueued() const { return m_rollbackQueued; }
    QString rollbackImage() const { return m_rollbackImage; }
    QString rollbackVersion() const { return m_rollbackVersion; }
    QString rollbackDigest() const { return m_rollbackDigest; }
    QString rollbackShortDigest() const { return shortenDigest(m_rollbackDigest); }
    QString rollbackTimestamp() const { return m_rollbackTimestamp; }

    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void performUpgrade();
    Q_INVOKABLE void performRollback();
    Q_INVOKABLE void setAutoUpdates(bool enabled);
    Q_INVOKABLE void requestReboot();
    Q_INVOKABLE void copyToClipboard(const QString &text);
    Q_INVOKABLE void clearMessages();

Q_SIGNALS:
    void stateChanged();
    void statusChanged();
    void logChanged();

private:
    void executeHelperAction(const QString &actionName,
                             const QString &busyText,
                             const QVariantMap &args = {});
    void parseStatusPayload(const QVariantMap &payload);
    void parseDeploymentSlot(const QJsonObject &slotObj,
                             QString &outImage,
                             QString &outTransport,
                             QString &outVersion,
                             QString &outDigest,
                             QString &outTimestamp,
                             QString &outArch,
                             QString &outOstreeChecksum,
                             bool &outPinned) const;
    static QString formatIsoTimestamp(const QString &isoStr);
    static QString shortenDigest(const QString &digest);
    void appendLog(const QString &line);

    QFileSystemWatcher m_runWatcher;

    bool m_busy = false;
    QString m_busyMessage;
    QString m_errorMessage;
    QString m_infoMessage;
    QString m_logOutput;

    bool m_rebootRequiredFile = false;
    bool m_updateAvailable = false;
    QString m_availableVersion;
    QString m_availableDigest;
    QString m_availableTimestamp;
    bool m_autoUpdatesEnabled = true;

    QString m_bootedImage;
    QString m_bootedTransport;
    QString m_bootedVersion;
    QString m_bootedDigest;
    QString m_bootedTimestamp;
    QString m_bootedArchitecture;
    QString m_bootedOstreeChecksum;
    bool m_bootedPinned = false;

    bool m_hasStaged = false;
    QString m_stagedImage;
    QString m_stagedVersion;
    QString m_stagedDigest;
    QString m_stagedTimestamp;

    bool m_hasRollback = false;
    bool m_rollbackQueued = false;
    QString m_rollbackImage;
    QString m_rollbackVersion;
    QString m_rollbackDigest;
    QString m_rollbackTimestamp;
};
