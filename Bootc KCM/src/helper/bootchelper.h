#pragma once

#include <QObject>
#include <QVariantMap>
#include <KAuth/ActionReply>

using namespace KAuth;

class BootcHelper : public QObject
{
    Q_OBJECT

public:
    explicit BootcHelper(QObject *parent = nullptr);

public Q_SLOTS:
    ActionReply status(const QVariantMap &args);
    ActionReply check(const QVariantMap &args);
    ActionReply upgrade(const QVariantMap &args);
    ActionReply rollback(const QVariantMap &args);
    ActionReply toggleautotimer(const QVariantMap &args);

private:
    QVariantMap collectStatusPayload(QString *errorOut = nullptr) const;
    bool isAutoTimerEnabled() const;
    void syncRebootRequiredMarker(const QByteArray &statusJson) const;
};
