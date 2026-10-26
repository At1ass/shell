#pragma once
#include <QDBusArgument>
#include <QMetaType>
#include <QVariantMap>

using NetworkSettings = QMap<QString, QVariantMap>;
Q_DECLARE_METATYPE(NetworkSettings)
inline QDBusArgument& operator<<(QDBusArgument& out, const NetworkSettings& settings) {
    out.beginMap(QMetaType::fromType<QString>(), QMetaType::fromType<QVariantMap>());
    for (auto it = settings.cbegin(); it != settings.cend(); ++it) {
        out.beginMapEntry(); out << it.key() << it.value(); out.endMapEntry();
    }
    out.endMap(); return out;
}
inline const QDBusArgument& operator>>(const QDBusArgument& in, NetworkSettings& settings) {
    in.beginMap();
    while (!in.atEnd()) {
        QString name; QVariantMap fields;
        in.beginMapEntry(); in >> name >> fields; in.endMapEntry();
        settings.insert(name, fields);
    }
    in.endMap(); return in;
}
