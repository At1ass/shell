#include "NetworkCredentials.h"
#include <QDBusMetaType>
#include <QRegularExpression>
#include <QUuid>

namespace NetworkCredentials {
QMap<QString, QString> stringMap(const QVariant& value) {
    if (value.metaType() == QMetaType::fromType<QDBusArgument>())
        return qdbus_cast<QMap<QString, QString>>(value.value<QDBusArgument>());
    QMap<QString, QString> out;
    const auto map = value.toMap();
    for (auto it = map.cbegin(); it != map.cend(); ++it) out.insert(it.key(), it.value().toString());
    return out;
}
Description describe(const NetworkSettings& connection, const QString& setting, const QStringList& hints) {
    Description out;
    const auto identity = connection.value("connection");
    out.uuid = identity.value("uuid").toString();
    out.name = identity.value("id").toString().left(256);
    out.setting = setting;
    if (QUuid(out.uuid).isNull() || out.name.isEmpty() || hints.size() > 32 || connection.size() > 32) return out;
    const auto props = connection.value(setting);
    if (props.size() > 128) return out;
    QStringList keys;
    QMap<QString, QString> labels;
    if (setting == "802-11-wireless-security") {
        out.keyMgmt = props.value("key-mgmt").toString();
        if (out.keyMgmt == "wpa-psk" || out.keyMgmt == "sae") {
            keys << "psk"; labels.insert("psk", "Wi-Fi password");
        } else if (out.keyMgmt == "none") {
            const auto index = props.value("wep-tx-keyidx", 0).toUInt();
            if (index > 3) return out;
            keys << QString("wep-key%1").arg(index); labels.insert(keys.first(), "Wi-Fi key");
        } else return out;
    } else if (setting == "802-1x") {
        const QStringList supported = {"password", "password-raw", "private-key-password", "phase2-private-key-password", "pin"};
        for (const auto& hint : hints) {
            if (!supported.contains(hint)) return out;
            if (!keys.contains(hint)) keys << hint;
        }
        if (keys.isEmpty()) {
            const auto eap = props.value("eap").toStringList();
            keys << (eap.contains("tls") ? "private-key-password" : "password");
        }
        labels = {{"password", "Network password"}, {"password-raw", "Network password"},
                  {"private-key-password", "Private key password"},
                  {"phase2-private-key-password", "Inner private key password"}, {"pin", "Security token PIN"}};
    } else if (setting == "pppoe" || setting == "ppp" || setting == "gsm" || setting == "cdma") {
        keys << (setting == "gsm" && hints.contains("pin") ? "pin" : "password");
        labels.insert(keys.first(), keys.first() == "pin" ? "SIM PIN" : "Connection password");
    } else return out; // VPN is described by its trusted external-UI helper.
    if (setting != "802-1x") {
        for (const auto& hint : hints) if (!keys.contains(hint)) return out;
    }
    for (const auto& key : keys) {
        const QString flagsKey = key.startsWith("wep-key") ? "wep-key-flags" : key + "-flags";
        const auto flags = props.value(flagsKey, 0).toUInt();
        if (flags & ~7u) return out;
        out.secretFlags.insert(key, flags);
        out.fields.append(QVariantMap{{"key", key}, {"label", labels.value(key, "Password")}, {"secret", true}});
        const auto value = props.value(key);
        const QString text = value.metaType() == QMetaType::fromType<QByteArray>()
            ? QString::fromUtf8(value.toByteArray()) : value.toString();
        if (!text.isEmpty()) out.values.insert(key, text);
    }
    out.supported = !out.fields.isEmpty();
    return out;
}
Description saved(const NetworkSettings& connection, const QString& setting) {
    auto out = describe(connection, setting, {});
    const auto identity = connection.value("connection");
    out.uuid = identity.value("uuid").toString(); out.name = identity.value("id").toString().left(256); out.setting = setting;
    if (QUuid(out.uuid).isNull() || connection.size() > 32) return {};
    const auto props = connection.value(setting);
    if (props.size() > 128) return {};
    if (setting == "vpn") {
        const auto data = stringMap(props.value("data"));
        const auto values = stringMap(props.value("secrets"));
        if (values.size() > 128) return {};
        for (auto it = values.cbegin(); it != values.cend(); ++it) {
            if (it.key().contains("challenge") || it.key().size() > 128) continue;
            bool ok = true;
            const auto flags = data.contains(it.key()+"-flags") ? data.value(it.key()+"-flags").toUInt(&ok) : 0u;
            if (!ok || (flags & ~7u)) return {};
            out.values.insert(it.key(), it.value()); out.secretFlags.insert(it.key(), flags);
        }
        out.supported = true;
    } else if (out.supported) {
        QStringList keys;
        if (setting == "802-1x") keys = {"password", "password-raw", "private-key-password", "phase2-private-key-password", "pin"};
        else if (setting == "802-11-wireless-security" && out.keyMgmt == "none") keys = {"wep-key0", "wep-key1", "wep-key2", "wep-key3"};
        else if (setting == "gsm") keys = {"password", "pin"};
        for (const auto& key : keys) {
            if (!props.contains(key)) continue;
            const auto value = props.value(key);
            out.values.insert(key, value.metaType() == QMetaType::fromType<QByteArray>() ? QString::fromUtf8(value.toByteArray()) : value.toString());
            const auto flagsKey = key.startsWith("wep-key") ? QStringLiteral("wep-key-flags") : key + "-flags";
            bool ok = false;
            const auto flags = props.value(flagsKey, 0).toUInt(&ok);
            if (!ok || (flags & ~7u)) return {};
            out.secretFlags.insert(key, flags);
        }
    }
    return out;
}
bool validate(const Description& description, const QString& key, const QString& value) {
    const auto bytes = value.toUtf8();
    if (bytes.isEmpty() || bytes.size() > 16384 || value.contains(QChar('\0'))) return false;
    if (key == "psk" && description.keyMgmt != "sae") {
        static const QRegularExpression hex("^[0-9a-fA-F]{64}$");
        return (bytes.size() >= 8 && bytes.size() <= 63) || hex.match(value).hasMatch();
    }
    if (description.setting == "gsm" && key == "pin") {
        static const QRegularExpression digits("^[0-9]{4,8}$");
        return digits.match(value).hasMatch();
    }
    return true;
}
NetworkSettings reply(const Description& description, const QVariantMap& values) {
    QVariantMap props;
    if (description.setting == "vpn") {
        QMap<QString, QString> secrets;
        for (auto it = values.cbegin(); it != values.cend(); ++it) secrets.insert(it.key(), it.value().toString());
        props.insert("secrets", QVariant::fromValue(secrets));
    } else {
        props = values;
        if (props.contains("password-raw")) props["password-raw"] = props["password-raw"].toString().toUtf8();
    }
    return {{description.setting, props}};
}
QVariantMap persistentValues(const Description& description, const QVariantMap& values) {
    QVariantMap out;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        const auto flags = description.secretFlags.value(it.key());
        if ((flags & 1u) && !(flags & 2u)) out.insert(it.key(), it.value());
    }
    return out;
}
}
