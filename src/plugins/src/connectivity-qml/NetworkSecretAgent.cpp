#include "NetworkSecretAgent.h"
#include <QDBusVirtualObject>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QtConcurrent>
#include <QUuid>
#include <algorithm>

namespace {
const QString Service = "org.freedesktop.NetworkManager";
const QString Agent = Service + ".SecretAgent";
const QString AgentPath = "/org/freedesktop/NetworkManager/SecretAgent";
const QString Manager = Service + ".AgentManager";
const QString ManagerPath = "/org/freedesktop/NetworkManager/AgentManager";
QString identifier() { return QUuid::createUuid().toString(QUuid::Id128); }
QDBusMessage call(const QString& owner, const QString& path, const QString& interface,
                  const QString& member, const QVariantList& arguments = {}) {
    auto message = QDBusMessage::createMethodCall(owner, path, interface, member);
    message.setArguments(arguments); message.setAutoStartService(false); return message;
}
}
struct NetworkSecretAgent::Request {
    QString id = identifier();
    QString method, path, setting;
    NetworkSettings connection;
    QStringList hints;
    quint32 flags = 0;
    QDeadlineTimer deadline;
    QDBusMessage success, cancelled;
    QMap<QString, QDBusMessage> errors;
    NetworkCredentials::Description description;
    QVariantMap values;
};
class NetworkAgentEndpoint : public QDBusVirtualObject {
public:
    explicit NetworkAgentEndpoint(NetworkSecretAgent* owner) : QDBusVirtualObject(owner), m_owner(owner) {}
    QString introspect(const QString&) const override {
        return QStringLiteral(R"XML(<interface name="org.freedesktop.NetworkManager.SecretAgent">
<method name="GetSecrets"><arg type="a{sa{sv}}" direction="in"/><arg type="o" direction="in"/><arg type="s" direction="in"/><arg type="as" direction="in"/><arg type="u" direction="in"/><arg type="a{sa{sv}}" direction="out"/></method>
<method name="CancelGetSecrets"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="SaveSecrets"><arg type="a{sa{sv}}" direction="in"/><arg type="o" direction="in"/></method>
<method name="DeleteSecrets"><arg type="a{sa{sv}}" direction="in"/><arg type="o" direction="in"/></method>
</interface>)XML");
    }
    bool handleMessage(const QDBusMessage& message, const QDBusConnection&) override { return m_owner->handle(message); }
private:
    NetworkSecretAgent* m_owner;
};
NetworkSecretAgent::NetworkSecretAgent(QObject* parent)
    : NetworkSecretAgent(QDBusConnection::connectToBus(QDBusConnection::SystemBus,
          "shell-nm-agent-" + identifier()), CredentialStore::execute, parent) {
    m_connectionId = m_bus.name();
}
NetworkSecretAgent::NetworkSecretAgent(QDBusConnection bus, Executor executor, QObject* parent)
    : QObject(parent), m_bus(std::move(bus)), m_endpoint(new NetworkAgentEndpoint(this)),
      m_deadlineTimer(this), m_executor(std::move(executor)) {
    qDBusRegisterMetaType<NetworkSettings>();
    qDBusRegisterMetaType<QMap<QString, QString>>();
    m_deadlineTimer.setSingleShot(true); m_deadlineTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_deadlineTimer, &QTimer::timeout, this, &NetworkSecretAgent::expireRequests);
    m_bus.connect("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                  "NameOwnerChanged", this, SLOT(ownerChanged(QString,QString,QString)));
}
NetworkSecretAgent::~NetworkSecretAgent() {
    m_destroying = true;
    clearRequest(false);
    unregisterAgent();
    if (m_exported) m_bus.unregisterObject(AgentPath);
    if (!m_connectionId.isEmpty()) QDBusConnection::disconnectFromBus(m_connectionId);
}
void NetworkSecretAgent::disposeWatcher(QPointer<QDBusPendingCallWatcher>& watcher) {
    if (!watcher) return;
    watcher->disconnect(this); watcher->deleteLater(); watcher = nullptr;
}
QString NetworkSecretAgent::section() const {
    if (!m_current) return "wifi";
    if (m_current->setting == "vpn") return "vpn";
    const auto type = m_current->connection.value("connection").value("type").toString();
    return type == "802-3-ethernet" || type == "pppoe" ? "ethernet" : "wifi";
}
void NetworkSecretAgent::setError(const QString& text) {
    if (m_error == text) return;
    m_error = text;
    if (!m_destroying) emit errorOccurred(m_error);
}
void NetworkSecretAgent::setTimeoutMs(int value) {
    value = std::clamp(value, 1, 300000);
    if (m_timeoutMs == value) return;
    m_timeoutMs = value; emit controlChanged();
}
void NetworkSecretAgent::setEnabled(bool value) {
    if (m_enabled == value) return;
    m_enabled = value; ++m_epoch;
    disposeWatcher(m_ownerWatcher);
    if (!value) { clearRequest(); unregisterAgent(); }
    else if (m_owner.isEmpty()) queryOwner();
    else registerAgent();
    emit controlChanged();
}
void NetworkSecretAgent::setBlocked(bool value) {
    if (m_blocked == value) return;
    m_blocked = value;
    if (value) clearRequest();
    emit controlChanged();
}
void NetworkSecretAgent::queryOwner() {
    if (!m_enabled || m_ownerWatcher) return;
    if (!m_bus.isConnected()) { setError("NetworkManager bus unavailable"); return; }
    const auto epoch = m_epoch;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(call("org.freedesktop.DBus",
        "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", {Service}), 5000), this);
    m_ownerWatcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch] {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        if (m_ownerWatcher == watcher) m_ownerWatcher = nullptr;
        if (epoch == m_epoch && m_enabled && !reply.isError()) updateOwner(reply.value());
    });
}
void NetworkSecretAgent::ownerChanged(const QString& service, const QString&, const QString& owner) {
    if (service == Service) updateOwner(owner);
}
void NetworkSecretAgent::updateOwner(const QString& owner) {
    if (owner == m_owner) return;
    disposeWatcher(m_ownerWatcher);
    clearRequest(); unregisterAgent(); ++m_epoch;
    m_owner = owner;
    if (m_enabled && !m_owner.isEmpty()) registerAgent();
}
void NetworkSecretAgent::registerAgent() {
    if (!m_enabled || m_owner.isEmpty() || m_registered || m_registerWatcher) return;
    if (!m_exported) {
        m_exported = m_bus.registerVirtualObject(AgentPath, m_endpoint, QDBusConnection::SingleNode);
        if (!m_exported) { setError("Could not export NetworkManager agent"); return; }
    }
    const auto epoch = m_epoch;
    const auto owner = m_owner;
    m_registerSent = true;
    auto* watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(call(m_owner, ManagerPath, Manager,
        "RegisterWithCapabilities", {"org.at1ass.shell.NetworkAgent.a" + identifier(), quint32(1)}), 5000), this);
    m_registerWatcher = watcher;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch, owner] {
        QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (m_registerWatcher == watcher) m_registerWatcher = nullptr;
        if (epoch != m_epoch || !m_enabled) {
            // Registration can complete after disable/owner replacement. Keep
            // its watcher alive until that reply, then release any late agent.
            if (!reply.isError()) m_bus.call(call(owner, ManagerPath, Manager, "Unregister"), QDBus::NoBlock);
            m_registerSent = false;
            if (m_enabled) registerAgent();
            return;
        }
        if (reply.isError()) setError("NetworkManager agent registration failed");
        else { m_registered = true; setError({}); emit availabilityChanged(); }
    });
}
void NetworkSecretAgent::unregisterAgent() {
    if (m_registerSent && !m_registerWatcher && !m_owner.isEmpty()) m_bus.call(call(m_owner, ManagerPath, Manager, "Unregister"), QDBus::NoBlock);
    m_registerSent = false;
    if (m_registered) { m_registered = false; if (!m_destroying) emit availabilityChanged(); }
}
void NetworkSecretAgent::replyError(const QDBusMessage& message, const QString& kind, const QString& text) const {
    m_bus.send(message.createErrorReply(Agent + "." + kind, text));
}
bool NetworkSecretAgent::handle(const QDBusMessage& message) {
    if (message.interface() != Agent || message.type() != QDBusMessage::MethodCallMessage) return false;
    if (m_owner.isEmpty() || message.service() != m_owner) {
        replyError(message, "PermissionDenied", "Untrusted caller"); return true;
    }
    const auto member = message.member();
    const auto args = message.arguments();
    if (member == "CancelGetSecrets" && message.signature() == "os") {
        const auto path = qvariant_cast<QDBusObjectPath>(args[0]).path();
        const auto setting = args[1].toString();
        for (qsizetype i = m_queue.size(); i-- > 0;) {
            const auto request = m_queue[i];
            if (request->method == "GetSecrets" && request->path == path && request->setting == setting) {
                m_bus.send(request->cancelled); m_queue.removeAt(i);
            }
        }
        if (m_current && m_current->method == "GetSecrets" && m_current->path == path && m_current->setting == setting) {
            CredentialStore::cancel(m_jobCancel);
            finishCurrent("AgentCanceled", "NetworkManager cancelled the request");
        }
        m_bus.send(message.createReply()); emit requestChanged(); updateDeadline(); return true;
    }
    const bool get = member == "GetSecrets" && message.signature() == "a{sa{sv}}osasu";
    const bool save = member == "SaveSecrets" && message.signature() == "a{sa{sv}}o";
    const bool del = member == "DeleteSecrets" && message.signature() == "a{sa{sv}}o";
    if (!get && !save && !del) { replyError(message, "InvalidConnection", "Unsupported request"); return true; }
    if (!m_enabled || !m_registered) { replyError(message, "NoSecrets", "Agent unavailable"); return true; }
    if (m_queue.size() + (m_current ? 1 : 0) >= 8) { replyError(message, "NoSecrets", "Agent request limit reached"); return true; }
    auto request = std::make_shared<Request>();
    request->method = member;
    request->connection = qdbus_cast<NetworkSettings>(args[0]);
    request->path = qvariant_cast<QDBusObjectPath>(args[1]).path();
    request->success = message.createReply();
    for (const auto* kind : {"AgentCanceled", "UserCanceled", "Failed", "NoSecrets", "InvalidConnection"})
        request->errors.insert(kind, message.createErrorReply(Agent + "." + kind, "Authentication request failed"));
    request->cancelled = request->errors.value("AgentCanceled");
    request->deadline = QDeadlineTimer(m_timeoutMs);
    if (get) {
        request->setting = args[2].toString();
        request->hints = qdbus_cast<QStringList>(args[3]);
        request->flags = args[4].toUInt();
    }
    if (m_blocked && (!get || (request->flags & 1u))) {
        replyError(message, "UserCanceled", "Session is locked"); return true;
    }
    const auto uuid = request->connection.value("connection").value("uuid").toString();
    if (QUuid(uuid).isNull() || request->connection.size() > 32 || request->hints.size() > 32) {
        replyError(message, "InvalidConnection", "Invalid connection metadata"); return true;
    }
    m_queue.append(request); emit requestChanged(); updateDeadline();
    QTimer::singleShot(0, this, &NetworkSecretAgent::processQueue);
    return true;
}
void NetworkSecretAgent::processQueue() {
    if (m_destroying || m_current || m_jobWatcher || m_queue.isEmpty()) return;
    m_current = m_queue.takeFirst();
    setError({});
    if (m_current->deadline.hasExpired()) { finishCurrent("UserCanceled", "Authentication timed out"); return; }
    if (m_current->method == "DeleteSecrets") {
        CredentialStore::Job job; job.operation = CredentialStore::Operation::Delete;
        job.uuid = m_current->connection.value("connection").value("uuid").toString();
        startJob(job, "delete"); return;
    }
    if (m_current->method == "SaveSecrets") {
        // Save every agent-owned setting in sequence, retaining the request
        // until all storage operations have acknowledged completion.
        for (auto it = m_current->connection.cbegin(); it != m_current->connection.cend(); ++it) {
            if (it.key() == "connection") continue;
            auto description = NetworkCredentials::saved(m_current->connection, it.key());
            if (!description.supported) continue;
            const auto values = NetworkCredentials::persistentValues(description, description.values);
            if (values.isEmpty()) continue;
            m_current->description = description;
            // Remove completed fields from the queued snapshot after each save.
            CredentialStore::Job job; job.operation = CredentialStore::Operation::Save;
            job.uuid = description.uuid; job.setting = description.setting;
            job.label = description.name; job.values = values;
            startJob(job, "save-external"); return;
        }
        finishCurrent(); return;
    }
    describeGet();
}
void NetworkSecretAgent::describeGet() {
    if (m_current->setting == "vpn") {
        CredentialStore::Job job; job.operation = CredentialStore::Operation::DescribeVpn;
        job.connection = m_current->connection; job.setting = "vpn"; job.hints = m_current->hints;
        job.uuid = m_current->connection.value("connection").value("uuid").toString();
        job.label = m_current->connection.value("connection").value("id").toString();
        job.allowInteraction = m_current->flags & 1u; job.requestNew = m_current->flags & 2u;
        startJob(job, "vpn"); return;
    }
    m_current->description = NetworkCredentials::describe(m_current->connection, m_current->setting, m_current->hints);
    if (!m_current->description.supported) { finishCurrent("NoSecrets", "Unsupported authentication setting"); return; }
    loadStored();
}
void NetworkSecretAgent::loadStored() {
    auto& request = *m_current;
    request.values = (request.flags & 2u) ? QVariantMap{} : request.description.values;
    if (request.description.values.contains("no-secret")) request.values.insert("no-secret", "true");
    CredentialStore::Job job;
    job.uuid = request.description.uuid; job.setting = request.setting;
    job.allowInteraction = request.flags & 1u;
    if (!(request.flags & 2u)) {
        for (const auto& field : request.description.fields) {
            const auto key = field.toMap().value("key").toString();
            const auto flags = request.description.secretFlags.value(key);
            if (!request.values.contains(key) && (flags & 1u) && !(flags & 2u)) job.keys.append(key);
        }
    }
    if (!job.keys.isEmpty()) startJob(job, "lookup");
    else showPrompt();
}
void NetworkSecretAgent::showPrompt() {
    auto& request = *m_current;
    m_fields.clear();
    for (const auto& field : request.description.fields) {
        const auto key = field.toMap().value("key").toString();
        if (!request.values.contains(key)) m_fields.append(field);
    }
    if (m_fields.isEmpty()) { finishGet(); return; }
    if (!(request.flags & 1u)) { finishCurrent("NoSecrets", "No stored credentials available"); return; }
    if (m_blocked) { finishCurrent("UserCanceled", "Session is locked"); return; }
    m_token = identifier(); m_name = request.description.name;
    m_requestNew = request.flags & 2u; m_message = request.description.message;
    m_validationError.clear(); emit requestChanged();
}
void NetworkSecretAgent::finishGet() {
    const auto secrets = NetworkCredentials::reply(m_current->description, m_current->values);
    m_current->success.setArguments({QVariant::fromValue(secrets)});
    finishCurrent();
}
bool NetworkSecretAgent::submit(const QString& token, const QVariantMap& answers) {
    if (token.isEmpty() || token != m_token || !m_current || m_blocked || m_jobWatcher) return false;
    if (m_current->deadline.hasExpired()) { expireRequests(); return false; }
    for (const auto& field : m_fields) {
        const auto key = field.toMap().value("key").toString();
        if (!NetworkCredentials::validate(m_current->description, key, answers.value(key).toString())) {
            m_validationError = "Enter valid credentials in every required field"; emit requestChanged(); return false;
        }
    }
    for (const auto& field : m_fields) {
        const auto key = field.toMap().value("key").toString();
        m_current->values.insert(key, answers.value(key).toString());
    }
    const auto values = NetworkCredentials::persistentValues(m_current->description, m_current->values);
    m_token.clear(); m_fields.clear(); m_validationError.clear(); emit requestChanged();
    if (values.isEmpty()) finishGet();
    else {
        CredentialStore::Job job; job.operation = CredentialStore::Operation::Save;
        job.uuid = m_current->description.uuid; job.setting = m_current->setting;
        job.label = m_current->description.name; job.values = values;
        startJob(job, "save-answer");
    }
    return true;
}
bool NetworkSecretAgent::reject(const QString& token) {
    if (token.isEmpty() || token != m_token || !m_current) return false;
    finishCurrent("UserCanceled", "User cancelled authentication"); return true;
}
void NetworkSecretAgent::cancel() { clearRequest(); }
void NetworkSecretAgent::clearRequest(bool notify) {
    CredentialStore::cancel(m_jobCancel);
    if (m_current) m_bus.send(m_current->errors.value("UserCanceled"));
    for (const auto& request : m_queue) m_bus.send(request->method == "GetSecrets" && (request->flags & 1u) ? request->errors.value("UserCanceled") : request->cancelled);
    m_current.reset(); m_queue.clear(); m_deadlineTimer.stop();
    m_token.clear(); m_fields.clear(); m_name.clear(); m_message.clear(); m_validationError.clear();
    if (notify && !m_destroying) emit requestChanged();
}
void NetworkSecretAgent::finishCurrent(const QString& error, const QString& text) {
    if (!m_current) return;
    if (error.isEmpty()) m_bus.send(m_current->success);
    else {
        auto reply = m_current->errors.value(error, m_current->errors.value("Failed"));
        reply.setArguments({text}); m_bus.send(reply);
    }
    m_current.reset(); m_token.clear(); m_fields.clear(); m_name.clear(); m_message.clear(); m_validationError.clear();
    if (!m_destroying) emit requestChanged();
    updateDeadline();
    QTimer::singleShot(0, this, &NetworkSecretAgent::processQueue);
}
void NetworkSecretAgent::startJob(CredentialStore::Job job, const QString& phase) {
    const auto id = m_current->id;
    m_jobCancel = CredentialStore::cancellation();
    const auto executor = m_executor; const auto cancellation = m_jobCancel;
    auto* watcher = new QFutureWatcher<CredentialStore::Result>(this);
    m_jobWatcher = watcher;
    connect(watcher, &QFutureWatcher<CredentialStore::Result>::finished, this, [this, watcher, id, phase] {
        const auto result = watcher->result(); watcher->deleteLater();
        if (m_jobWatcher != watcher) return;
        m_jobWatcher = nullptr; m_jobCancel.reset();
        if (m_current && m_current->id == id) jobFinished(id, phase, result);
        else { emit requestChanged(); processQueue(); }
    });
    watcher->setFuture(QtConcurrent::run([executor, job = std::move(job), cancellation] { return executor(job, cancellation); }));
}
void NetworkSecretAgent::jobFinished(const QString&, const QString& phase, CredentialStore::Result result) {
    if (m_current->deadline.hasExpired()) { expireRequests(); return; }
    if (!result.success) {
        if (phase == "lookup") { showPrompt(); return; }
        setError(result.error.isEmpty() ? "Credential operation failed" : result.error);
        finishCurrent("Failed", m_error); return;
    }
    if (phase == "lookup") {
        for (auto it = result.values.cbegin(); it != result.values.cend(); ++it) m_current->values.insert(it.key(), it.value());
        showPrompt();
    } else if (phase == "vpn") {
        m_current->description = result.description;
        if (!result.description.supported) finishCurrent("NoSecrets", "Unsupported VPN authentication");
        else loadStored();
    } else if (phase == "save-answer") finishGet();
    else if (phase == "save-external") {
        m_current->connection.remove(m_current->description.setting);
        auto request = m_current; m_current.reset(); m_queue.prepend(request); processQueue();
    } else finishCurrent();
}
void NetworkSecretAgent::updateDeadline() {
    qint64 remaining = m_current ? m_current->deadline.remainingTime() : -1;
    for (const auto& request : m_queue) {
        const auto time = request->deadline.remainingTime();
        if (remaining < 0 || time < remaining) remaining = time;
    }
    if (remaining < 0) m_deadlineTimer.stop();
    else m_deadlineTimer.start(static_cast<int>(std::max<qint64>(1, remaining)));
}
void NetworkSecretAgent::expireRequests() {
    for (qsizetype i = m_queue.size(); i-- > 0;) {
        if (m_queue[i]->deadline.hasExpired()) { m_bus.send(m_queue[i]->cancelled); m_queue.removeAt(i); }
    }
    if (m_current && m_current->deadline.hasExpired()) {
        CredentialStore::cancel(m_jobCancel); finishCurrent("UserCanceled", "Authentication timed out");
    }
    emit requestChanged();
    updateDeadline();
}
