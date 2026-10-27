#include "VpnProfiles.h"
#include "NetworkSettings.h"
#include <QDBusArgument>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDeadlineTimer>
#include <QTimer>
#include <QUuid>
#include <algorithm>
#include <utility>

namespace {
const QString Service = "org.freedesktop.NetworkManager";
const QString Root = "/org/freedesktop/NetworkManager";
const QString Settings = Service + ".Settings";
const QString Connection = Settings + ".Connection";
const QString Active = Service + ".Connection.Active";
const QString Properties = "org.freedesktop.DBus.Properties";
using Paths = QList<QDBusObjectPath>;
QString uuid(const QString& value) {
    const QUuid parsed(value);
    return parsed.isNull() ? QString{} : parsed.toString(QUuid::WithoutBraces);
}
Paths paths(const QVariant& value) {
    if (value.metaType() == QMetaType::fromType<QDBusArgument>()) return qdbus_cast<Paths>(value);
    return value.value<Paths>();
}
}
struct VpnProfiles::Snapshot {
    quint64 generation;
    QDeadlineTimer deadline{5000};
    Paths settings, active;
    QHash<QString, QVariantMap> profiles;
    QHash<QString, uint> states;
};
VpnProfiles::VpnProfiles(QObject* parent) : VpnProfiles(QDBusConnection::systemBus(), parent) {}
VpnProfiles::VpnProfiles(QDBusConnection bus, QObject* parent)
    : QObject(parent), m_bus(std::move(bus)),
      m_serviceWatcher(new QDBusServiceWatcher(Service, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this)) {
    qDBusRegisterMetaType<NetworkSettings>(); qDBusRegisterMetaType<Paths>();
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &VpnProfiles::ownerChanged);
    m_bus.connect(Service, Root + "/Settings", Settings, "NewConnection", this, SLOT(topologyAdded(QDBusObjectPath)));
    m_bus.connect(Service, Root + "/Settings", Settings, "ConnectionRemoved", this, SLOT(topologyAdded(QDBusObjectPath)));
    m_bus.connect(Service, {}, Connection, "Updated", this, SLOT(topologyChanged()));
    m_bus.connect(Service, {}, Connection, "Removed", this, SLOT(topologyChanged()));
    m_bus.connect(Service, {}, Active, "StateChanged", this, SLOT(activeStateChanged(uint,uint)));
    m_bus.connect(Service, {}, Properties, "PropertiesChanged", this, SLOT(propertiesChanged(QString,QVariantMap,QStringList)));
    auto message = QDBusMessage::createMethodCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner");
    message.setArguments({Service});
    const auto generation = m_ownerGeneration;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 5000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, generation] {
        QDBusPendingReply<QString> reply = *watcher; watcher->deleteLater();
        if (generation != m_ownerGeneration) return;
        m_ownerResolved = true;
        if (!reply.isError()) setOwner(reply.value());
        else if (m_enabled) { m_error = "NetworkManager is unavailable"; emit changed(); }
    });
}
void VpnProfiles::setEnabled(bool enabled) {
    if (enabled == m_enabled) return;
    m_enabled = enabled; ++m_generation;
    if (!enabled) clear();
    else refresh();
    emit enabledChanged();
}
void VpnProfiles::clear() {
    m_profiles.clear(); m_index.clear(); m_names.clear(); m_activeNames.clear(); m_activeUuids.clear(); m_ready = false; m_error.clear(); emit changed();
}
void VpnProfiles::ownerChanged(const QString&, const QString&, const QString& owner) {
    ++m_ownerGeneration; m_ownerResolved = true; setOwner(owner);
}
void VpnProfiles::setOwner(const QString& owner) {
    if (owner == m_owner) return;
    m_owner = owner; ++m_generation; clear(); refresh();
}
QVariantMap VpnProfiles::profile(const QString& id) const { return m_index.value(uuid(id)); }
void VpnProfiles::topologyChanged() { refresh(); }
void VpnProfiles::topologyAdded(const QDBusObjectPath&) { refresh(); }
void VpnProfiles::activeStateChanged(uint, uint) { refresh(); }
void VpnProfiles::propertiesChanged(const QString& interface, const QVariantMap& changed, const QStringList& invalidated) {
    if ((interface == Service && (changed.contains("ActiveConnections") || invalidated.contains("ActiveConnections")))
        || (interface == Active && (changed.contains("State") || invalidated.contains("State")))) refresh();
}
void VpnProfiles::refresh() {
    if (!m_enabled) return;
    m_dirty = true;
    if (m_running || m_scheduled) return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this] { m_scheduled = false; start(); });
}
void VpnProfiles::start() {
    if (!m_enabled || m_running) return;
    if (m_owner.isEmpty()) { if (m_ownerResolved) { m_error = "NetworkManager is unavailable"; emit changed(); } return; }
    m_running = true; m_dirty = false;
    auto snapshot = std::make_shared<Snapshot>(); snapshot->generation = m_generation;
    request(snapshot, Root + "/Settings", Settings, "ListConnections", {}, [this, snapshot](const QDBusMessage& message) {
        QDBusPendingReply<Paths> reply(message);
        if (!current(snapshot)) { finish(snapshot); return; }
        if (reply.isError() || reply.value().size() > 512) { finish(snapshot, "Could not read VPN profiles"); return; }
        snapshot->settings = reply.value();
        request(snapshot, Root, Properties, "GetAll", {Service}, [this, snapshot](const QDBusMessage& message) {
            QDBusPendingReply<QVariantMap> reply(message);
            if (!current(snapshot)) { finish(snapshot); return; }
            if (reply.isError()) { finish(snapshot, "Could not read VPN connection state"); return; }
            snapshot->active = paths(reply.value().value("ActiveConnections"));
            if (snapshot->active.size() > 128) { finish(snapshot, "Too many active network connections"); return; }
            readNext(snapshot);
        });
    });
}
bool VpnProfiles::current(const std::shared_ptr<Snapshot>& snapshot) const {
    return m_enabled && snapshot->generation == m_generation && !m_dirty;
}
void VpnProfiles::request(const std::shared_ptr<Snapshot>& snapshot, const QString& path, const QString& interface,
                          const QString& method, const QVariantList& args, std::function<void(const QDBusMessage&)> callback) {
    if (snapshot->deadline.hasExpired()) { finish(snapshot, "VPN profile refresh timed out"); return; }
    auto message = QDBusMessage::createMethodCall(m_owner, path, interface, method);
    message.setArguments(args); message.setAutoStartService(false);
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message, static_cast<int>(std::max<qint64>(1, snapshot->deadline.remainingTime()))), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [watcher, callback = std::move(callback)] {
        const auto message = watcher->reply(); watcher->deleteLater(); callback(message);
    });
}
void VpnProfiles::readNext(const std::shared_ptr<Snapshot>& snapshot) {
    if (!current(snapshot)) { finish(snapshot); return; }
    if (!snapshot->settings.isEmpty()) {
        const auto path = snapshot->settings.takeFirst().path();
        request(snapshot, path, Connection, "GetSettings", {}, [this, snapshot](const QDBusMessage& message) {
            if (!current(snapshot)) { finish(snapshot); return; }
            QDBusPendingReply<NetworkSettings> reply(message);
            if (!reply.isError()) {
                const auto connection = reply.value().value("connection");
                const auto id = uuid(connection.value("uuid").toString());
                const auto name = connection.value("id").toString();
                if (connection.value("type").toString() == "vpn" && !id.isEmpty() && !name.isEmpty() && name.size() <= 1024)
                    snapshot->profiles.insert(id, {{"uuid", id}, {"name", name}});
            }
            readNext(snapshot);
        });
    } else if (!snapshot->active.isEmpty()) {
        const auto path = snapshot->active.takeFirst().path();
        request(snapshot, path, Properties, "GetAll", {Active}, [this, snapshot](const QDBusMessage& message) {
            if (!current(snapshot)) { finish(snapshot); return; }
            QDBusPendingReply<QVariantMap> reply(message);
            if (!reply.isError()) {
                const auto props = reply.value();
                const auto id = uuid(props.value("Uuid").toString());
                const auto state = props.value("State").toUInt();
                const auto name = props.value("Id").toString();
                if (props.value("Type").toString() == "vpn" && !id.isEmpty() && state >= 1 && state <= 3) {
                    // An active connection can briefly outlive a deleted profile.
                    if (!snapshot->profiles.contains(id) && !name.isEmpty() && name.size() <= 1024)
                        snapshot->profiles.insert(id, {{"uuid", id}, {"name", name}});
                    const auto old = snapshot->states.value(id);
                    if (!old || state == 2) snapshot->states.insert(id, state);
                }
            }
            readNext(snapshot);
        });
    } else finish(snapshot);
}
void VpnProfiles::finish(const std::shared_ptr<Snapshot>& snapshot, const QString& error) {
    m_running = false;
    if (current(snapshot)) {
        if (!error.isEmpty()) { m_error = error; emit changed(); }
        else {
            for (auto it = snapshot->profiles.begin(); it != snapshot->profiles.end(); ++it) {
                const auto state = snapshot->states.value(it.key());
                it.value().insert("connected", state == 2);
                it.value().insert("busy", state == 1 || state == 3);
                it.value().insert("state", state);
            }
            QVariantList profiles;
            for (const auto& profile : std::as_const(snapshot->profiles)) profiles.append(profile);
            std::sort(profiles.begin(), profiles.end(), [](const QVariant& a, const QVariant& b) {
                const auto first = a.toMap(), second = b.toMap();
                const auto order = QString::localeAwareCompare(first.value("name").toString(), second.value("name").toString());
                return order ? order < 0 : first.value("uuid").toString() < second.value("uuid").toString();
            });
            const bool differs = !m_ready || !m_error.isEmpty() || m_profiles != profiles;
            m_names.clear(); m_activeNames.clear(); m_activeUuids.clear();
            for (const auto& value : std::as_const(profiles)) {
                const auto profile = value.toMap();
                m_names.append(profile.value("name").toString());
                if (profile.value("connected").toBool()) {
                    m_activeNames.append(profile.value("name").toString());
                    m_activeUuids.append(profile.value("uuid").toString());
                }
            }
            m_profiles = profiles; m_index = snapshot->profiles; m_ready = true; m_error.clear();
            if (differs) emit changed();
        }
    }
    if (m_dirty) refresh();
}
