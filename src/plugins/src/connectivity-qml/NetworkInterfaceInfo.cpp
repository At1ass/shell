#include "NetworkInterfaceInfo.h"
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QHostAddress>
#include <QTimer>

namespace {
const QString Service = "org.freedesktop.NetworkManager";
const QString ManagerPath = "/org/freedesktop/NetworkManager";
const QString Device = Service + ".Device";
const QString Properties = "org.freedesktop.DBus.Properties";
using AddressData = QList<QVariantMap>;
struct Family {
    QStringList addresses;
    QString gateway;
};
Family decode(const QVariantMap& properties, bool ipv6) {
    Family out;
    const auto variant = properties.value("AddressData");
    AddressData entries;
    if (variant.metaType() == QMetaType::fromType<QDBusArgument>()) entries = qdbus_cast<AddressData>(variant);
    else for (const auto& item : variant.toList()) entries.append(item.toMap());
    const auto protocol = ipv6 ? QAbstractSocket::IPv6Protocol : QAbstractSocket::IPv4Protocol;
    for (const auto& entry : entries) {
        if (out.addresses.size() >= 64) break;
        QHostAddress address(entry.value("address").toString());
        bool ok = false;
        const auto prefix = entry.value("prefix").toUInt(&ok);
        if (!ok || prefix > (ipv6 ? 128u : 32u) || address.protocol() != protocol || address.isNull()) continue;
        const auto value = address.toString() + "/" + QString::number(prefix);
        if (!out.addresses.contains(value)) out.addresses.append(value);
    }
    QHostAddress gateway(properties.value("Gateway").toString());
    if (gateway.protocol() == protocol && !gateway.isNull()) out.gateway = gateway.toString();
    return out;
}
}
struct NetworkInterfaceInfo::Snapshot {
    quint64 generation;
    bool valid = false;
    Family ipv4, ipv6;
};
NetworkInterfaceInfo::NetworkInterfaceInfo(QObject* parent)
    : NetworkInterfaceInfo(QDBusConnection::systemBus(), parent) {}
NetworkInterfaceInfo::NetworkInterfaceInfo(QDBusConnection bus, QObject* parent)
    : QObject(parent), m_bus(std::move(bus)),
      m_serviceWatcher(new QDBusServiceWatcher(Service, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this)) {
    qDBusRegisterMetaType<AddressData>();
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &NetworkInterfaceInfo::ownerChanged);
    m_bus.connect(Service, {}, Properties, "PropertiesChanged", this,
        SLOT(propertiesChanged(QString,QVariantMap,QStringList,QDBusMessage)));
    auto message = QDBusMessage::createMethodCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner");
    message.setArguments({Service});
    const auto generation = m_ownerGeneration;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 5000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, generation] {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        if (generation == m_ownerGeneration && !reply.isError()) setOwner(reply.value());
    });
}
void NetworkInterfaceInfo::setInterfaceName(const QString& value) {
    const auto name = value.size() <= 255 && !value.contains(QChar('\0')) ? value : QString{};
    if (name == m_interface) return;
    m_interface = name; ++m_generation;
    m_devicePath.clear(); m_ip4Path.clear(); m_ip6Path.clear();
    clear(); emit interfaceNameChanged(); refresh();
}
void NetworkInterfaceInfo::ownerChanged(const QString&, const QString&, const QString& owner) {
    ++m_ownerGeneration; setOwner(owner);
}
void NetworkInterfaceInfo::setOwner(const QString& owner) {
    if (m_owner == owner) return;
    m_owner = owner; ++m_generation;
    m_devicePath.clear(); m_ip4Path.clear(); m_ip6Path.clear();
    clear(); refresh();
}
void NetworkInterfaceInfo::clear() {
    if (!m_ready && m_ipv4.isEmpty() && m_ipv6.isEmpty() && m_gateway4.isEmpty() && m_gateway6.isEmpty()) return;
    m_ready = false; m_ipv4.clear(); m_ipv6.clear(); m_gateway4.clear(); m_gateway6.clear(); emit changed();
}
void NetworkInterfaceInfo::propertiesChanged(const QString& interface, const QVariantMap&, const QStringList&, const QDBusMessage& message) {
    if (message.service() != m_owner) return;
    const auto path = message.path();
    if ((path == m_devicePath && interface == Device)
        || (path == m_ip4Path && interface == Service + ".IP4Config")
        || (path == m_ip6Path && interface == Service + ".IP6Config")) refresh();
}
void NetworkInterfaceInfo::refresh() {
    m_dirty = true;
    if (m_scheduled || m_running) return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this] { m_scheduled = false; start(); });
}
void NetworkInterfaceInfo::start() {
    if (m_running || m_interface.isEmpty() || m_owner.isEmpty()) return;
    m_running = true; m_dirty = false;
    auto snapshot = std::make_shared<Snapshot>(); snapshot->generation = m_generation;
    request(ManagerPath, Service, "GetDeviceByIpIface", {m_interface}, [this, snapshot](const QDBusMessage& message) {
        QDBusPendingReply<QDBusObjectPath> reply(message);
        if (!current(snapshot) || reply.isError() || reply.value().path() == "/") { finish(snapshot); return; }
        m_devicePath = reply.value().path(); readDevice(snapshot);
    });
}
bool NetworkInterfaceInfo::current(const std::shared_ptr<Snapshot>& snapshot) const {
    return snapshot->generation == m_generation && !m_dirty;
}
void NetworkInterfaceInfo::request(const QString& path, const QString& interface, const QString& method,
                                  const QVariantList& args, std::function<void(const QDBusMessage&)> callback) {
    auto message = QDBusMessage::createMethodCall(m_owner, path, interface, method);
    message.setArguments(args); message.setAutoStartService(false);
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 5000), this);
    m_watcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, callback = std::move(callback)] {
        const auto reply = watcher->reply(); watcher->deleteLater();
        m_watcher = nullptr; callback(reply);
    });
}
void NetworkInterfaceInfo::readDevice(const std::shared_ptr<Snapshot>& snapshot) {
    request(m_devicePath, Properties, "GetAll", {Device}, [this, snapshot](const QDBusMessage& message) {
        QDBusPendingReply<QVariantMap> reply(message);
        if (!current(snapshot) || reply.isError() || reply.value().value("State").toUInt() != 100u) { finish(snapshot); return; }
        const auto props = reply.value();
        m_ip4Path = qvariant_cast<QDBusObjectPath>(props.value("Ip4Config")).path();
        m_ip6Path = qvariant_cast<QDBusObjectPath>(props.value("Ip6Config")).path();
        snapshot->valid = true; readFamily(snapshot, false);
    });
}
void NetworkInterfaceInfo::readFamily(const std::shared_ptr<Snapshot>& snapshot, bool ipv6) {
    const auto path = ipv6 ? m_ip6Path : m_ip4Path;
    if (path.isEmpty() || path == "/") {
        if (ipv6) finish(snapshot); else readFamily(snapshot, true);
        return;
    }
    const auto interface = Service + (ipv6 ? ".IP6Config" : ".IP4Config");
    request(path, Properties, "GetAll", {interface}, [this, snapshot, ipv6](const QDBusMessage& message) {
        if (!current(snapshot)) { finish(snapshot); return; }
        QDBusPendingReply<QVariantMap> reply(message);
        if (!reply.isError()) (ipv6 ? snapshot->ipv6 : snapshot->ipv4) = decode(reply.value(), ipv6);
        if (ipv6) finish(snapshot); else readFamily(snapshot, true);
    });
}
void NetworkInterfaceInfo::finish(const std::shared_ptr<Snapshot>& snapshot) {
    m_running = false;
    if (current(snapshot)) {
        if (!snapshot->valid) clear();
        else {
            const bool differs = !m_ready || m_ipv4 != snapshot->ipv4.addresses || m_ipv6 != snapshot->ipv6.addresses
                || m_gateway4 != snapshot->ipv4.gateway || m_gateway6 != snapshot->ipv6.gateway;
            m_ready = true; m_ipv4 = snapshot->ipv4.addresses; m_ipv6 = snapshot->ipv6.addresses;
            m_gateway4 = snapshot->ipv4.gateway; m_gateway6 = snapshot->ipv6.gateway;
            if (differs) emit changed();
        }
    }
    if (m_dirty) refresh();
}
