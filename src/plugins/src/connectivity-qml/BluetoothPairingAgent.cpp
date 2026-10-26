#include "BluetoothPairingAgent.h"
#include <QDBusVirtualObject>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusObjectPath>
#include <QRegularExpression>
#include <QUuid>
#include <algorithm>
#include <utility>

namespace {
const QString Bluez = QStringLiteral("org.bluez");
const QString Manager = QStringLiteral("org.bluez.AgentManager1");
const QString Agent = QStringLiteral("org.bluez.Agent1");
QString token() { return QUuid::createUuid().toString(QUuid::Id128); }
QDBusMessage method(const QString& owner, const QString& path, const QString& interface,
                    const QString& member, const QVariantList& arguments = {}) {
    auto message = QDBusMessage::createMethodCall(owner, path, interface, member);
    message.setArguments(arguments);
    message.setAutoStartService(false);
    return message;
}
bool validPin(const QString& value) {
    return !value.isEmpty() && value.size() <= 16 && std::all_of(value.begin(), value.end(),
        [](QChar character) { return character.unicode() >= 0x20 && character.unicode() <= 0x7e; });
}
}

class AgentEndpoint : public QDBusVirtualObject {
public:
    explicit AgentEndpoint(BluetoothPairingAgent* agent) : QDBusVirtualObject(agent), m_agent(agent) {}
    QString introspect(const QString&) const override {
        return QStringLiteral(R"XML(<interface name="org.bluez.Agent1">
<method name="Release"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="Cancel"/>
</interface>)XML");
    }
    bool handleMessage(const QDBusMessage& message, const QDBusConnection&) override {
        return m_agent->handle(message);
    }
private:
    BluetoothPairingAgent* m_agent; // Parent-owned; unexported before parent teardown.
};

BluetoothPairingAgent::BluetoothPairingAgent(QObject* parent)
    : BluetoothPairingAgent(QDBusConnection::systemBus(), parent) {}
BluetoothPairingAgent::BluetoothPairingAgent(QDBusConnection bus, QObject* parent)
    : QObject(parent), m_bus(std::move(bus)), m_endpoint(new AgentEndpoint(this)),
      m_objectPath("/org/at1ass/Shell/BluezAgent/a" + token()),
      m_operationTimer(this), m_retryTimer(this) {
    m_operationTimer.setSingleShot(true);
    m_operationTimer.setTimerType(Qt::PreciseTimer);
    m_retryTimer.setSingleShot(true);
    connect(&m_operationTimer, &QTimer::timeout, this, [this] { cancel("Pairing timed out"); });
    connect(&m_retryTimer, &QTimer::timeout, this, &BluetoothPairingAgent::registerAgent);
    m_bus.connect("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                  "NameOwnerChanged", this, SLOT(ownerChanged(QString,QString,QString)));
}
BluetoothPairingAgent::~BluetoothPairingAgent() {
    m_destroying = true;
    m_operationTimer.stop();
    m_retryTimer.stop();
    cancel("Pairing cancelled", true, false);
    unregisterAgent();
    if (m_exported) m_bus.unregisterObject(m_objectPath);
}
void BluetoothPairingAgent::setError(const QString& error) {
    const auto bounded = error.left(512);
    if (m_error == bounded) return;
    m_error = bounded;
    emit errorOccurred(m_error);
}
void BluetoothPairingAgent::sendNoReply(const QString& owner, const QString& path,
                                      const QString& interface, const QString& member,
                                      const QVariantList& arguments) {
    if (owner.isEmpty() || !m_bus.isConnected()) return;
    // NoBlock only sends; it never waits for a daemon or device response.
    m_bus.call(method(owner, path, interface, member, arguments), QDBus::NoBlock);
}
void BluetoothPairingAgent::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    ++m_epoch;
    if (m_ownerWatcher) { m_ownerWatcher->disconnect(this); m_ownerWatcher->deleteLater(); m_ownerWatcher = nullptr; }
    m_retries = 0;
    if (!enabled) {
        cancel("Pairing cancelled");
        unregisterAgent();
    } else if (!m_owner.isEmpty()) registerAgent();
    else queryOwner();
    emit controlChanged();
}
void BluetoothPairingAgent::setBlocked(bool blocked) {
    if (m_blocked == blocked) return;
    m_blocked = blocked;
    if (blocked) cancel("Pairing cancelled");
    emit controlChanged();
}
void BluetoothPairingAgent::setTimeoutMs(int milliseconds) {
    milliseconds = std::clamp(milliseconds, 1, 300000);
    if (m_timeoutMs == milliseconds) return;
    m_timeoutMs = milliseconds; // Existing operations retain their original deadline.
    emit controlChanged();
}
void BluetoothPairingAgent::queryOwner() {
    if (!m_enabled || m_ownerWatcher) return;
    if (!m_bus.isConnected()) { setError("Bluetooth bus unavailable"); return; }
    const auto epoch = m_epoch;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(method("org.freedesktop.DBus",
        "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", {Bluez}), 5000), this);
    m_ownerWatcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch] {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        if (m_ownerWatcher == watcher) m_ownerWatcher = nullptr;
        if (epoch != m_epoch || !m_enabled) return;
        if (!reply.isError()) updateOwner(reply.value());
    });
}
void BluetoothPairingAgent::ownerChanged(const QString& service, const QString&, const QString& owner) {
    if (service == Bluez) updateOwner(owner);
}
void BluetoothPairingAgent::updateOwner(const QString& owner) {
    if (m_owner == owner) return;
    if (m_ownerWatcher) { m_ownerWatcher->disconnect(this); m_ownerWatcher->deleteLater(); m_ownerWatcher = nullptr; }
    if (m_pairWatcher) { m_pairWatcher->disconnect(this); m_pairWatcher->deleteLater(); m_pairWatcher = nullptr; }
    cancel("Bluetooth service changed", false);
    unregisterAgent();
    ++m_epoch;
    m_owner = owner;
    m_retries = 0;
    if (m_enabled && !m_owner.isEmpty()) registerAgent();
}
void BluetoothPairingAgent::registerAgent() {
    if (!m_enabled || m_owner.isEmpty() || m_registered || m_registerWatcher) return;
    if (!m_exported) {
        m_exported = m_bus.registerVirtualObject(m_objectPath, m_endpoint, QDBusConnection::SingleNode);
        if (!m_exported) { setError("Could not export Bluetooth pairing agent"); return; }
    }
    const auto epoch = m_epoch;
    m_registerSent = true;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(method(m_owner, "/org/bluez", Manager,
        "RegisterAgent", {QVariant::fromValue(QDBusObjectPath(m_objectPath)), "KeyboardDisplay"}), 5000), this);
    m_registerWatcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch] {
        QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (m_registerWatcher == watcher) m_registerWatcher = nullptr;
        if (epoch != m_epoch || !m_enabled) return;
        if (reply.isError()) {
            if (reply.error().name() == "org.bluez.Error.AlreadyExists" && ++m_retries <= 10)
                m_retryTimer.start(200); // Only a bounded hot-reload handover retry.
            else setError("Bluetooth pairing agent unavailable");
        } else {
            m_registered = true;
            setError("");
            emit availabilityChanged();
        }
    });
}
void BluetoothPairingAgent::unregisterAgent() {
    m_retryTimer.stop();
    if (m_registerWatcher) { m_registerWatcher->disconnect(this); m_registerWatcher->deleteLater(); m_registerWatcher = nullptr; }
    if (m_registerSent) sendNoReply(m_owner, "/org/bluez", Manager, "UnregisterAgent",
                                   {QVariant::fromValue(QDBusObjectPath(m_objectPath))});
    m_registerSent = false;
    if (m_registered) { m_registered = false; if (!m_destroying) emit availabilityChanged(); }
}
bool BluetoothPairingAgent::arm(const QString& path, const QString& name, const QString& address) {
    static const QRegularExpression valid("^/org/bluez/hci[0-9]+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}$");
    if (!m_enabled || m_blocked || !m_registered || busy() || !m_bus.isConnected() || !valid.match(path).hasMatch()) return false;
    m_path = path;
    m_name = name.left(128);
    m_address = address.left(32);
    m_deadline = QDeadlineTimer(m_timeoutMs);
    m_operationTimer.start(m_timeoutMs);
    emit stateChanged();
    return true;
}
bool BluetoothPairingAgent::startPair() {
    if (!armed() || m_pairWatcher || !m_enabled || m_blocked || !m_registered) return false;
    const auto path = m_path;
    const auto epoch = m_epoch;
    // Qt's default D-Bus timeout is too short for interactive PIN entry.
    // Bound both the user deadline and this transport call; retain the watcher
    // after cancellation so a late Cancel cannot reach a replacement operation.
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(
        method(m_owner, path, "org.bluez.Device1", "Pair"), m_timeoutMs + 5000), this);
    m_pairWatcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, path, epoch] {
        QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (m_pairWatcher != watcher) return;
        m_pairWatcher = nullptr;
        if (epoch != m_epoch || m_path != path) { emit stateChanged(); return; }
        if (m_blocked || m_deadline.hasExpired()) {
            cancel(m_blocked ? "Pairing cancelled" : "Pairing timed out");
            return;
        }
        const auto error = reply.isError() ? reply.error().message().left(512) : QString();
        disarm();
        emit operationFinished(path, !reply.isError(), error);
    });
    emit stateChanged();
    return true;
}
void BluetoothPairingAgent::errorReply(const QDBusMessage& message, const QString& reason) const {
    m_bus.send(message.createErrorReply("org.bluez.Error.Rejected", reason));
}
void BluetoothPairingAgent::clearRequest() {
    if (m_hasReply) m_bus.send(m_reply.createErrorReply("org.bluez.Error.Canceled", "Pairing cancelled"));
    m_hasReply = false;
    m_reply = QDBusMessage();
    m_kind.clear(); m_token.clear(); m_code.clear(); m_uuid.clear(); m_validationError.clear();
    m_entered = 0;
}
void BluetoothPairingAgent::disarm() {
    clearRequest();
    m_operationTimer.stop();
    m_path.clear(); m_name.clear(); m_address.clear(); m_deadline = QDeadlineTimer();
    if (!m_destroying) emit stateChanged();
}
void BluetoothPairingAgent::cancel(const QString& reason, bool cancelTransport, bool notify) {
    const auto path = m_path;
    disarm();
    if (path.isEmpty()) return;
    if (cancelTransport) sendNoReply(m_owner, path, "org.bluez.Device1", "CancelPairing");
    if (notify) emit operationCancelled(path, reason);
}
void BluetoothPairingAgent::abort() { cancel("Pairing cancelled"); }
void BluetoothPairingAgent::deviceRemoved(const QString& path) {
    if (path == m_path) cancel("Device is no longer available");
}
bool BluetoothPairingAgent::reject(const QString& id) {
    if (id.isEmpty() || id != m_token) return false;
    cancel("Pairing cancelled");
    return true;
}
bool BluetoothPairingAgent::submit(const QString& id, const QString& value) {
    if (id.isEmpty() || id != m_token || !m_hasReply || m_blocked || !m_enabled) return false;
    if (m_deadline.hasExpired()) { cancel("Pairing timed out"); return false; }
    QVariantList arguments;
    if (m_kind == "pin") {
        if (!validPin(value)) { m_validationError = "Enter 1–16 printable characters"; emit stateChanged(); return false; }
        arguments << value;
    } else if (m_kind == "passkey") {
        static const QRegularExpression digits("^[0-9]{1,6}$");
        if (!digits.match(value).hasMatch()) { m_validationError = "Enter up to six digits"; emit stateChanged(); return false; }
        arguments << value.toUInt();
    } else if (m_kind != "confirm" && m_kind != "authorize" && m_kind != "service") return false;
    const auto reply = m_reply.createReply(arguments);
    m_hasReply = false;
    clearRequest();
    m_bus.send(reply);
    emit stateChanged();
    return true;
}
bool BluetoothPairingAgent::handle(const QDBusMessage& message) {
    if (message.interface() != Agent || message.type() != QDBusMessage::MethodCallMessage) return false;
    if (message.service() != m_owner || m_owner.isEmpty()) { errorReply(message, "Untrusted caller"); return true; }
    const auto member = message.member();
    const auto signature = message.signature();
    if (member == "Release" && signature.isEmpty()) {
        ++m_epoch;
        if (m_registerWatcher) {
            m_registerWatcher->disconnect(this);
            m_registerWatcher->deleteLater();
            m_registerWatcher = nullptr;
        }
        m_registerSent = false;
        if (m_registered) { m_registered = false; if (!m_destroying) emit availabilityChanged(); }
        cancel("Bluetooth pairing agent released", false);
        if (m_enabled && ++m_retries <= 10) m_retryTimer.start(200);
        m_bus.send(message.createReply());
        return true;
    }
    if (member == "Cancel" && signature.isEmpty()) {
        // BlueZ also sends Cancel after a displayed keyboard code is no longer
        // needed. The Pair reply, not this UI callback, owns operation completion.
        clearRequest();
        emit stateChanged();
        m_bus.send(message.createReply());
        return true;
    }
    QString kind;
    bool display = false;
    if (member == "RequestPinCode" && signature == "o") kind = "pin";
    else if (member == "RequestPasskey" && signature == "o") kind = "passkey";
    else if (member == "RequestConfirmation" && signature == "ou") kind = "confirm";
    else if (member == "RequestAuthorization" && signature == "o") kind = "authorize";
    else if (member == "AuthorizeService" && signature == "os") kind = "service";
    else if (member == "DisplayPinCode" && signature == "os") { kind = "display-pin"; display = true; }
    else if (member == "DisplayPasskey" && signature == "ouq") { kind = "display-passkey"; display = true; }
    else { errorReply(message, "Unsupported pairing request"); return true; }
    if (armed() && m_deadline.hasExpired()) cancel("Pairing timed out");
    const auto args = message.arguments();
    const auto path = qvariant_cast<QDBusObjectPath>(args[0]).path();
    if (!m_enabled || m_blocked || !m_registered || !armed() || path != m_path || m_hasReply) {
        errorReply(message, "No matching user-initiated pairing"); return true;
    }
    QString code, uuid;
    int entered = 0;
    if (kind == "confirm" || kind == "display-passkey") {
        const auto number = args[1].toUInt();
        if (number > 999999) { errorReply(message, "Invalid passkey"); return true; }
        code = QStringLiteral("%1").arg(number, 6, 10, QLatin1Char('0'));
        if (kind == "display-passkey") entered = std::min<int>(args[2].value<ushort>(), 6);
    } else if (kind == "display-pin") {
        code = args[1].toString();
        if (!validPin(code)) { errorReply(message, "Invalid PIN"); return true; }
    } else if (kind == "service") {
        uuid = args[1].toString();
        static const QRegularExpression validUuid("^[0-9a-fA-F-]{1,64}$");
        if (!validUuid.match(uuid).hasMatch()) { errorReply(message, "Invalid service identifier"); return true; }
    }
    if (m_kind != kind || m_token.isEmpty() || m_code != code || m_uuid != uuid) m_token = token();
    m_kind = kind; m_code = code; m_uuid = uuid; m_entered = entered; m_validationError.clear();
    if (display) m_bus.send(message.createReply());
    else { m_reply = message; m_hasReply = true; }
    emit stateChanged();
    return true;
}
