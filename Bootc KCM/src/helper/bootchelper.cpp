#include "bootchelper.h"

#include <KAuth/HelperSupport>

#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStringList>

BootcHelper::BootcHelper(QObject *parent)
    : QObject(parent)
{
}

bool BootcHelper::isAutoTimerEnabled() const
{
    QProcess proc;
    proc.start(QStringLiteral("/usr/bin/systemctl"),
               {QStringLiteral("is-enabled"), QStringLiteral("bootc-fetch-apply-updates.timer")});
    proc.waitForFinished(5000);
    const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    return out == QLatin1String("enabled") || out == QLatin1String("static") || out == QLatin1String("enabled-runtime");
}

void BootcHelper::syncRebootRequiredMarker(const QByteArray &statusJson) const
{
    QJsonParseError parseErr{};
    const QJsonDocument doc = QJsonDocument::fromJson(statusJson, &parseErr);
    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        return;
    }

    const QJsonObject root = doc.object();
    const QJsonObject statusObj = root.value(QStringLiteral("status")).toObject();
    const bool hasStaged = !statusObj.value(QStringLiteral("staged")).isNull()
                           && statusObj.value(QStringLiteral("staged")).isObject();
    const bool rollbackQueued = statusObj.value(QStringLiteral("rollbackQueued")).toBool(false);

    QFile marker(QStringLiteral("/run/reboot-required"));
    if (hasStaged || rollbackQueued) {
        if (!marker.exists()) {
            if (marker.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                marker.write("bootc\n");
                marker.close();
            }
        }
    }
}

QVariantMap BootcHelper::collectStatusPayload(QString *errorOut) const
{
    QVariantMap data;

    QProcess proc;
    proc.start(QStringLiteral("/usr/bin/bootc"),
               {QStringLiteral("status"), QStringLiteral("--format=json")});

    if (!proc.waitForFinished(30000)) {
        if (errorOut) {
            *errorOut = QStringLiteral("Tempo limite excedido ao executar 'bootc status --format=json'.");
        }
        return data;
    }

    const QByteArray stdoutBytes = proc.readAllStandardOutput();
    const QByteArray stderrBytes = proc.readAllStandardError();

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        if (errorOut) {
            *errorOut = QString::fromUtf8(stderrBytes.isEmpty() ? stdoutBytes : stderrBytes).trimmed();
        }
        return data;
    }

    syncRebootRequiredMarker(stdoutBytes);

    data.insert(QStringLiteral("statusJson"), QString::fromUtf8(stdoutBytes));
    data.insert(QStringLiteral("rebootRequiredFile"), QFileInfo::exists(QStringLiteral("/run/reboot-required")));
    data.insert(QStringLiteral("autoTimerEnabled"), isAutoTimerEnabled());
    return data;
}

ActionReply BootcHelper::status(const QVariantMap &args)
{
    Q_UNUSED(args);

    QString err;
    const QVariantMap payload = collectStatusPayload(&err);
    if (payload.isEmpty()) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(err.isEmpty() ? QStringLiteral("Falha ao obter status do bootc.") : err);
        return reply;
    }

    ActionReply reply = ActionReply::SuccessReply();
    reply.setData(payload);
    return reply;
}

ActionReply BootcHelper::check(const QVariantMap &args)
{
    Q_UNUSED(args);

    HelperSupport::progressStep(QVariantMap{
        {QStringLiteral("line"), QStringLiteral("Consultando registro remoto por novas camadas da imagem (bootc upgrade --check)...")}
    });

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(QStringLiteral("/usr/bin/bootc"),
               {QStringLiteral("upgrade"), QStringLiteral("--check")});

    QString fullOutput;
    while (!proc.waitForFinished(250)) {
        if (HelperSupport::isStopped()) {
            proc.terminate();
            proc.waitForFinished(2000);
            ActionReply reply = ActionReply::HelperErrorReply();
            reply.setErrorDescription(QStringLiteral("Verificação cancelada pelo usuário."));
            return reply;
        }
        while (proc.canReadLine()) {
            const QString line = QString::fromUtf8(proc.readLine()).trimmed();
            if (!line.isEmpty()) {
                fullOutput += line + QLatin1Char('\n');
                HelperSupport::progressStep(QVariantMap{{QStringLiteral("line"), line}});
            }
        }
    }

    const QString remaining = QString::fromUtf8(proc.readAll()).trimmed();
    if (!remaining.isEmpty()) {
        fullOutput += remaining + QLatin1Char('\n');
        for (const QString &line : remaining.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
            HelperSupport::progressStep(QVariantMap{{QStringLiteral("line"), line.trimmed()}});
        }
    }

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(fullOutput.trimmed().isEmpty()
                                      ? QStringLiteral("Erro ao verificar atualizações com 'bootc upgrade --check'.")
                                      : fullOutput.trimmed());
        return reply;
    }

    QString statusErr;
    QVariantMap payload = collectStatusPayload(&statusErr);
    payload.insert(QStringLiteral("commandOutput"), fullOutput.trimmed());

    // Detecta se a saída textual do 'bootc upgrade --check' indica ausência de mudanças
    const QString lowerOut = fullOutput.toLower();
    const bool noChanges = lowerOut.contains(QLatin1String("no changes"))
                           || lowerOut.contains(QLatin1String("already at latest"))
                           || lowerOut.contains(QLatin1String("up to date"));
    payload.insert(QStringLiteral("checkReportedUpdate"), !noChanges && !fullOutput.trimmed().isEmpty());

    ActionReply reply = ActionReply::SuccessReply();
    reply.setData(payload);
    return reply;
}

ActionReply BootcHelper::upgrade(const QVariantMap &args)
{
    Q_UNUSED(args);

    HelperSupport::progressStep(QVariantMap{
        {QStringLiteral("line"), QStringLiteral("Iniciando download e preparação da imagem (bootc upgrade)...")}
    });

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(QStringLiteral("/usr/bin/bootc"), {QStringLiteral("upgrade")});

    QString fullOutput;
    while (!proc.waitForFinished(250)) {
        if (HelperSupport::isStopped()) {
            proc.terminate();
            proc.waitForFinished(3000);
            ActionReply reply = ActionReply::HelperErrorReply();
            reply.setErrorDescription(QStringLiteral("Atualização interrompida pelo usuário."));
            return reply;
        }
        while (proc.canReadLine()) {
            const QString line = QString::fromUtf8(proc.readLine()).trimmed();
            if (!line.isEmpty()) {
                fullOutput += line + QLatin1Char('\n');
                HelperSupport::progressStep(QVariantMap{{QStringLiteral("line"), line}});
            }
        }
    }

    const QString remaining = QString::fromUtf8(proc.readAll()).trimmed();
    if (!remaining.isEmpty()) {
        fullOutput += remaining + QLatin1Char('\n');
        for (const QString &line : remaining.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
            HelperSupport::progressStep(QVariantMap{{QStringLiteral("line"), line.trimmed()}});
        }
    }

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(fullOutput.trimmed().isEmpty()
                                      ? QStringLiteral("Falha durante a execução do 'bootc upgrade'.")
                                      : fullOutput.trimmed());
        return reply;
    }

    QString statusErr;
    QVariantMap payload = collectStatusPayload(&statusErr);
    payload.insert(QStringLiteral("commandOutput"), fullOutput.trimmed());

    ActionReply reply = ActionReply::SuccessReply();
    reply.setData(payload);
    return reply;
}

ActionReply BootcHelper::rollback(const QVariantMap &args)
{
    Q_UNUSED(args);

    HelperSupport::progressStep(QVariantMap{
        {QStringLiteral("line"), QStringLiteral("Agendando reversão para a imagem anterior (bootc rollback)...")}
    });

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(QStringLiteral("/usr/bin/bootc"), {QStringLiteral("rollback")});
    proc.waitForFinished(30000);

    const QString fullOutput = QString::fromUtf8(proc.readAll()).trimmed();
    if (!fullOutput.isEmpty()) {
        HelperSupport::progressStep(QVariantMap{{QStringLiteral("line"), fullOutput}});
    }

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(fullOutput.isEmpty()
                                      ? QStringLiteral("Falha ao executar 'bootc rollback'.")
                                      : fullOutput);
        return reply;
    }

    QString statusErr;
    QVariantMap payload = collectStatusPayload(&statusErr);
    payload.insert(QStringLiteral("commandOutput"), fullOutput);

    ActionReply reply = ActionReply::SuccessReply();
    reply.setData(payload);
    return reply;
}

ActionReply BootcHelper::toggleautotimer(const QVariantMap &args)
{
    const bool enable = args.value(QStringLiteral("enable"), true).toBool();
    const QString subcmd = enable ? QStringLiteral("enable") : QStringLiteral("disable");

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.start(QStringLiteral("/usr/bin/systemctl"),
               {subcmd, QStringLiteral("--now"), QStringLiteral("bootc-fetch-apply-updates.timer")});
    proc.waitForFinished(15000);

    const QString fullOutput = QString::fromUtf8(proc.readAll()).trimmed();
    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        ActionReply reply = ActionReply::HelperErrorReply();
        reply.setErrorDescription(fullOutput.isEmpty()
                                      ? QStringLiteral("Não foi possível alterar o estado do timer bootc-fetch-apply-updates.timer.")
                                      : fullOutput);
        return reply;
    }

    QVariantMap payload;
    payload.insert(QStringLiteral("autoTimerEnabled"), isAutoTimerEnabled());
    payload.insert(QStringLiteral("commandOutput"), fullOutput);

    ActionReply reply = ActionReply::SuccessReply();
    reply.setData(payload);
    return reply;
}

KAUTH_HELPER_MAIN("org.fedoraproject.rynux.bootc", BootcHelper)
