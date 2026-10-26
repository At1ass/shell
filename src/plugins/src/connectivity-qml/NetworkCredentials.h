#pragma once
#include "NetworkSettings.h"
#include <QStringList>

namespace NetworkCredentials {
struct Description {
    bool supported = false;
    QString uuid, name, setting, keyMgmt, message;
    QVariantList fields;
    QVariantMap values;
    QMap<QString, quint32> secretFlags;
};
QMap<QString, QString> stringMap(const QVariant& value);
Description describe(const NetworkSettings& connection, const QString& setting, const QStringList& hints);
Description saved(const NetworkSettings& connection, const QString& setting);
bool validate(const Description& description, const QString& key, const QString& value);
NetworkSettings reply(const Description& description, const QVariantMap& values);
QVariantMap persistentValues(const Description& description, const QVariantMap& values);
}
