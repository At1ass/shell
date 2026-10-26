#include "NetworkAgentTests.h"
#include "../NetworkSecretAgent.h"
#include "../VpnUiHelper.h"
#include <QtTest>
#include <QDBusPendingReply>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QDBusConnectionInterface>
#include <QUuid>
#include <atomic>
#include <mutex>
#include <memory>

void NetworkManagerFixture::RegisterWithCapabilities(const QString& identifier, quint32 value) {
    if (!identifier.startsWith("org.at1ass.shell.NetworkAgent.")) {
        sendErrorReply("org.freedesktop.NetworkManager.AgentManager.InvalidIdentifier", "Invalid identifier"); return;
    }
    client = message().service(); capabilities = value;
    if (registrationDelay) {
        const auto request = message();
        const auto bus = QDBusContext::connection();
        setDelayedReply(true);
        QTimer::singleShot(registrationDelay, this, [request, bus] { bus.send(request.createReply()); });
    }
}
namespace {
const QString Agent = "org.freedesktop.NetworkManager.SecretAgent";
const QString Path = "/org/freedesktop/NetworkManager/SecretAgent";
const QString Setting = "802-11-wireless-security";
const QString ConnectionPath = "/org/freedesktop/NetworkManager/Settings/1";
const QString Uuid = "3630bbf6-a548-41de-9f58-07eafde18739";
NetworkSettings connection(quint32 flags = 0, const QString& value = {}) {
    QVariantMap security{{"key-mgmt", "wpa-psk"}, {"psk-flags", flags}};
    if (!value.isNull()) security.insert("psk", value);
    return {{"connection", {{"uuid", Uuid}, {"id", "Test network"}, {"type", "802-11-wireless"}}},
            {"802-11-wireless", {{"ssid", QByteArray("Test network")}}}, {Setting, security}};
}
struct Store {
    std::mutex mutex;
    QVariantMap values;
    int lookups = 0, saves = 0, deletes = 0;
    bool failSave = false;
    QByteArray vpnUi;
    std::atomic_bool waitForCancel{false}, entered{false};
    CredentialStore::Result execute(const CredentialStore::Job& job, const CredentialStore::Cancellation& token) {
        entered = true;
        if (waitForCancel) {
            while (!CredentialStore::isCancelled(token)) QThread::msleep(1);
            return {false, true, {}, "Cancelled", {}};
        }
        std::lock_guard<std::mutex> lock(mutex);
        if (job.operation == CredentialStore::Operation::DescribeVpn) {
            const auto description = VpnUiHelper::parse(vpnUi, job.connection);
            return {description.supported, false, {}, {}, description};
        }
        if (job.operation == CredentialStore::Operation::Lookup) { ++lookups; return {true, false, values, {}, {}}; }
        if (job.operation == CredentialStore::Operation::Save) {
            ++saves;
            if (failSave) return {false, false, {}, "Password store unavailable", {}};
            for (auto it = job.values.cbegin(); it != job.values.cend(); ++it) values.insert(it.key(), it.value());
        } else if (job.operation == CredentialStore::Operation::Delete) { ++deletes; values.clear(); }
        return {true, false, {}, {}, {}};
    }
};
struct Fixture {
    QString id = QUuid::createUuid().toString(QUuid::Id128);
    QDBusConnection server = QDBusConnection::sessionBus();
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id);
    QDBusConnection other = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id + "other");
    NetworkManagerFixture manager;
    std::shared_ptr<Store> store = std::make_shared<Store>();
    std::unique_ptr<NetworkSecretAgent> agent;
    Fixture() {
        if (!server.registerService("org.freedesktop.NetworkManager") || !server.registerObject(
            "/org/freedesktop/NetworkManager/AgentManager", &manager, QDBusConnection::ExportAllSlots)) qFatal("Private NM fixture failed");
        agent = std::make_unique<NetworkSecretAgent>(client, [state = store](const auto& job, const auto& token) { return state->execute(job, token); });
        agent->setBlocked(false); agent->setEnabled(true);
    }
    ~Fixture() {
        agent.reset(); QTest::qWait(10);
        server.unregisterObject("/org/freedesktop/NetworkManager/AgentManager"); server.unregisterService("org.freedesktop.NetworkManager");
        QDBusConnection::disconnectFromBus(id); QDBusConnection::disconnectFromBus(id + "other");
    }
    QDBusPendingCall call(const QString& member, const QVariantList& args, bool outsider = false) {
        auto message = QDBusMessage::createMethodCall(client.baseService(), Path, Agent, member);
        message.setArguments(args);
        return (outsider ? other : server).asyncCall(message, 3000);
    }
    QDBusPendingCall get(const NetworkSettings& settings = connection(), quint32 flags = 3, const QString& path = ConnectionPath) {
        return call("GetSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(path)),
            Setting, QStringList{}, flags});
    }
};
NetworkSettings result(const QDBusPendingCall& call) { QDBusPendingReply<NetworkSettings> reply(call); return reply.value(); }
QString errorName(const QDBusPendingCall& call) { return QDBusPendingReply<>(call).error().name(); }
}
void NetworkAgentTests::requestNewAndStaleTokens() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); QCOMPARE(f.manager.capabilities, 1u);
    auto first = f.get(); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    const auto token = f.agent->requestToken();
    QVERIFY(!first.isFinished()); QVERIFY(f.agent->requestNew());
    QCOMPARE(f.agent->fields().size(), 1);
    QVERIFY(!f.agent->submit(token, {{"psk", "short"}})); QVERIFY(!f.agent->validationError().isEmpty());
    QVERIFY(!f.agent->submit("old", {{"psk", "valid-password"}}));
    QVERIFY(f.agent->submit(token, {{"psk", "valid-password"}}));
    QTRY_VERIFY(first.isFinished()); QVERIFY(!first.isError()); QCOMPARE(result(first)[Setting]["psk"].toString(), "valid-password");
    auto retry = f.get(); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    QVERIFY(token != f.agent->requestToken()); QVERIFY(!f.agent->reject(token));
    QVERIFY(f.agent->reject(f.agent->requestToken())); QTRY_VERIFY(retry.isFinished());
    QCOMPARE(errorName(retry), Agent + ".UserCanceled");
}
void NetworkAgentTests::storedAndNotSaved() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.store->values.insert("psk", "stored-password");
    auto stored = f.get(connection(1), 0); QTRY_VERIFY(stored.isFinished());
    QVERIFY(!stored.isError()); QCOMPARE(result(stored)[Setting]["psk"].toString(), "stored-password");
    QVERIFY(f.agent->requestToken().isEmpty()); QCOMPARE(f.store->lookups, 1);
    auto fresh = f.get(connection(1), 3); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    QCOMPARE(f.store->lookups, 1); QVERIFY(f.agent->submit(f.agent->requestToken(), {{"psk", "fresh-password"}}));
    QTRY_VERIFY(fresh.isFinished()); QCOMPARE(f.store->saves, 1); QCOMPARE(f.store->values["psk"].toString(), "fresh-password");
    auto ephemeral = f.get(connection(3), 3); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    QVERIFY(f.agent->submit(f.agent->requestToken(), {{"psk", "one-time-password"}}));
    QTRY_VERIFY(ephemeral.isFinished()); QCOMPARE(f.store->saves, 1);
    QCOMPARE(f.store->values["psk"].toString(), "fresh-password");
    auto supplied = f.get(connection(0, "system-password"), 0); QTRY_VERIFY(supplied.isFinished());
    QCOMPARE(result(supplied)[Setting]["psk"].toString(), "system-password");
    auto silent = f.get(connection(2), 0); QTRY_VERIFY(silent.isFinished());
    QCOMPARE(errorName(silent), Agent + ".NoSecrets"); QVERIFY(f.agent->requestToken().isEmpty());
}
void NetworkAgentTests::cancellationAndQueue() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto first = f.get(); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    const auto old = f.agent->requestToken();
    auto second = f.get(connection(), 3, "/org/freedesktop/NetworkManager/Settings/2");
    auto wrong = f.call("CancelGetSecrets", {QVariant::fromValue(QDBusObjectPath("/wrong")), Setting});
    QTRY_VERIFY(wrong.isFinished()); QVERIFY(!first.isFinished()); QCOMPARE(f.agent->requestToken(), old);
    auto cancel = f.call("CancelGetSecrets", {QVariant::fromValue(QDBusObjectPath(ConnectionPath)), Setting});
    QTRY_VERIFY(cancel.isFinished()); QTRY_VERIFY(first.isFinished()); QCOMPARE(errorName(first), Agent + ".AgentCanceled");
    QTRY_VERIFY(!f.agent->requestToken().isEmpty() && f.agent->requestToken() != old);
    QVERIFY(f.agent->submit(f.agent->requestToken(), {{"psk", "second-password"}})); QTRY_VERIFY(second.isFinished()); QVERIFY(!second.isError());
}
void NetworkAgentTests::lockedAndUntrusted() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto outsider = f.call("GetSecrets", {QVariant::fromValue(connection()), QVariant::fromValue(QDBusObjectPath(ConnectionPath)), Setting, QStringList{}, quint32(3)}, true);
    QTRY_VERIFY(outsider.isFinished()); QCOMPARE(errorName(outsider), Agent + ".PermissionDenied");
    auto invalid = f.call("GetSecrets", {"not a connection"}); QTRY_VERIFY(invalid.isFinished());
    QCOMPARE(errorName(invalid), Agent + ".InvalidConnection");
    auto request = f.get(); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    f.agent->setBlocked(true); QTRY_VERIFY(request.isFinished()); QCOMPARE(errorName(request), Agent + ".UserCanceled");
    auto blocked = f.get(); QTRY_VERIFY(blocked.isFinished()); QCOMPARE(errorName(blocked), Agent + ".UserCanceled");
    QVERIFY(f.agent->requestToken().isEmpty());
    auto stored = f.get(connection(0, "system-password"), 0); QTRY_VERIFY(stored.isFinished()); QVERIFY(!stored.isError());
}
void NetworkAgentTests::saveAndDelete() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto settings = connection(1, "saved-password");
    auto save = f.call("SaveSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(ConnectionPath))});
    QTRY_VERIFY(save.isFinished()); QVERIFY(!save.isError()); QCOMPARE(f.store->saves, 1);
    QCOMPARE(f.store->values["psk"].toString(), "saved-password");
    settings[Setting]["psk-flags"] = quint32(3);
    auto notSaved = f.call("SaveSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(ConnectionPath))});
    QTRY_VERIFY(notSaved.isFinished()); QCOMPARE(f.store->saves, 1);
    auto del = f.call("DeleteSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(ConnectionPath))});
    QTRY_VERIFY(del.isFinished()); QVERIFY(!del.isError()); QCOMPARE(f.store->deletes, 1); QVERIFY(f.store->values.isEmpty());
}
void NetworkAgentTests::storeFailureAndTimeout() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.store->failSave = true;
    auto request = f.get(connection(1)); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    QVERIFY(f.agent->submit(f.agent->requestToken(), {{"psk", "password-to-save"}}));
    QTRY_VERIFY(request.isFinished()); QCOMPARE(errorName(request), Agent + ".Failed");
    QVERIFY(!f.agent->errorString().isEmpty());
    f.agent->setTimeoutMs(50); auto expired = f.get(); QTRY_VERIFY(expired.isFinished());
    QCOMPARE(errorName(expired), Agent + ".UserCanceled"); QVERIFY(f.agent->requestToken().isEmpty());
}
void NetworkAgentTests::daemonRestart() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto request = f.get(); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    f.server.unregisterService("org.freedesktop.NetworkManager"); QTRY_VERIFY(!f.agent->registered());
    QVERIFY(f.agent->requestToken().isEmpty());
    QVERIFY(f.server.registerService("org.freedesktop.NetworkManager")); QTRY_VERIFY(f.agent->registered());
    f.agent->setEnabled(false); QVERIFY(!f.agent->registered()); f.agent->setEnabled(true); QTRY_VERIFY(f.agent->registered());
}
void NetworkAgentTests::lateRegistration() {
    Fixture f;
    f.manager.registrationDelay = 50;
    QTRY_VERIFY(!f.manager.client.isEmpty());
    f.agent->setEnabled(false);
    QTRY_VERIFY(f.manager.client.isEmpty());
    QVERIFY(!f.agent->registered());
    f.agent->setEnabled(true);
    QTRY_VERIFY(f.agent->registered());
    f.agent->setEnabled(false); f.agent->setEnabled(true);
    QTRY_VERIFY(f.agent->registered());
}
void NetworkAgentTests::destructionDuringJob() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.store->waitForCancel = true;
    auto request = f.get(connection(1), 1); QTRY_VERIFY(f.store->entered.load());
    QSignalSpy stateSpy(f.agent.get(), &NetworkSecretAgent::requestChanged);
    QElapsedTimer timer; timer.start(); f.agent.reset(); QVERIFY(timer.elapsed() < 100);
    QCOMPARE(stateSpy.size(), 0); QTRY_VERIFY(request.isFinished());
}
void NetworkAgentTests::credentialShapes() {
    auto settings = connection();
    QVERIFY(!NetworkCredentials::validate(NetworkCredentials::describe(settings, Setting, {}), "psk", "short"));
    settings[Setting]["key-mgmt"] = "sae";
    QVERIFY(NetworkCredentials::validate(NetworkCredentials::describe(settings, Setting, {}), "psk", "x"));
    settings["802-1x"] = {{"eap", QStringList{"tls"}}, {"private-key-password", "certificate-pass"}, {"private-key-password-flags", 1u}};
    auto tls = NetworkCredentials::describe(settings, "802-1x", {}); QVERIFY(tls.supported);
    QCOMPARE(tls.fields.first().toMap()["key"].toString(), "private-key-password");
    QCOMPARE(NetworkCredentials::persistentValues(tls, tls.values).value("private-key-password").toString(), "certificate-pass");
    auto unknown = NetworkCredentials::describe(settings, "802-1x", {"unknown-secret"}); QVERIFY(!unknown.supported);
    settings["vpn"] = {{"data", QVariantMap{{"password-flags", "1"}}}, {"secrets", QVariantMap{{"password", "vpn-pass"}}}};
    const auto vpn = NetworkCredentials::saved(settings, "vpn"); QVERIFY(vpn.supported);
    QCOMPARE(NetworkCredentials::persistentValues(vpn, vpn.values)["password"].toString(), "vpn-pass");
}
void NetworkAgentTests::vpnDescriptionProtocol() {
    auto settings = connection();
    settings["vpn"] = {{"data", QVariantMap{{"connection-type", "password-tls"}, {"password-flags", "1"}, {"key", "line1\nDONE\nline3"}}},
                       {"service-type", "org.freedesktop.NetworkManager.openvpn"}};
    const auto payload = VpnUiHelper::input(settings);
    QVERIFY(payload.contains("line1\n=DONE\n=line3"));
    QVERIFY(payload.contains("SECRET_VAL=shell-field-description"));
    const QByteArray output = "[VPN Plugin UI]\nVersion=2\nDescription=VPN login\n[password]\nLabel=Password\nShouldAsk=true\nIsSecret=true\nValue=ignored\n[x-dynamic-challenge:challenge-response]\nLabel=OTP\nShouldAsk=true\nForceEcho=true\n";
    const auto description = VpnUiHelper::parse(output, settings);
    QVERIFY(description.supported); QCOMPARE(description.fields.size(), 2);
    QCOMPARE(description.secretFlags.value("password"), 1u);
    QCOMPARE(description.secretFlags.value("x-dynamic-challenge:challenge-response"), 2u);
    QVERIFY(!description.values.contains("password"));
    QVERIFY(!description.fields[1].toMap()["secret"].toBool());
    QVERIFY(!VpnUiHelper::parse("[VPN Plugin UI]\nVersion=99", settings).supported);
}
void NetworkAgentTests::vpnRequests() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto settings = connection();
    settings["connection"]["type"] = "vpn";
    settings["vpn"] = {{"data", QVariant::fromValue(QMap<QString, QString>{{"password-flags", "1"}})}, {"service-type", "org.freedesktop.NetworkManager.openvpn"}};
    f.store->vpnUi = "[VPN Plugin UI]\nVersion=2\n[password]\nLabel=VPN password\nShouldAsk=true\n[x-dynamic-challenge:challenge-response]\nLabel=OTP\nShouldAsk=true\n";
    auto request = f.call("GetSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(ConnectionPath)), QString("vpn"), QStringList{}, quint32(3)});
    QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    QCOMPARE(f.agent->section(), "vpn"); QCOMPARE(f.agent->fields().size(), 2);
    for (const auto& field : f.agent->fields()) QVERIFY(!field.toMap().contains("value"));
    QVERIFY(f.agent->submit(f.agent->requestToken(), {{"password", "vpn-password"}, {"x-dynamic-challenge:challenge-response", "012345"}}));
    QTRY_VERIFY(request.isFinished()); QVERIFY(!request.isError());
    const auto secrets = NetworkCredentials::stringMap(result(request)["vpn"]["secrets"]);
    QCOMPARE(secrets.value("x-dynamic-challenge:challenge-response"), "012345");
    QCOMPARE(f.store->values.value("password").toString(), "vpn-password");
    QVERIFY(!f.store->values.contains("x-dynamic-challenge:challenge-response"));
    f.store->vpnUi = "[VPN Plugin UI]\nVersion=2\n[no-secret]\nValue=true\n";
    auto none = f.call("GetSecrets", {QVariant::fromValue(settings), QVariant::fromValue(QDBusObjectPath(ConnectionPath)), QString("vpn"), QStringList{}, quint32(3)});
    QTRY_VERIFY(none.isFinished()); QVERIFY(!none.isError());
    QCOMPARE(NetworkCredentials::stringMap(result(none)["vpn"]["secrets"]).value("no-secret"), "true");
    QVERIFY(f.agent->requestToken().isEmpty());
}
void NetworkAgentTests::installedVpnHelper() {
    if (!QFileInfo::exists("/usr/lib/nm-openvpn-auth-dialog")) QSKIP("Optional OpenVPN helper is not installed");
    CredentialStore::Job job;
    job.operation = CredentialStore::Operation::DescribeVpn;
    job.uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    job.label = "Isolated field description";
    job.connection = {{"connection", {{"uuid", job.uuid}, {"id", job.label}}},
        {"vpn", {{"service-type", "org.freedesktop.NetworkManager.openvpn"},
                 {"data", QVariantMap{{"connection-type", "password"}, {"password-flags", "2"}}}}}};
    job.allowInteraction = true; job.requestNew = true;
    const auto result = CredentialStore::execute(job, CredentialStore::cancellation());
    QVERIFY2(result.success, qPrintable(result.error));
    QVERIFY(result.description.supported);
    QVERIFY(!result.description.fields.isEmpty());
    QCOMPARE(result.description.fields.first().toMap().value("key").toString(), "password");
    QVERIFY(result.description.values.isEmpty());
}
void NetworkAgentTests::nativeKeyringReadOnly() {
    if (!qEnvironmentVariableIsSet("SHELL_TEST_NATIVE_KEYRING")) QSKIP("Explicit opt-in: unmatched UUID lookup, no unlock/write");
    CredentialStore::Job job; job.uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    job.setting = Setting; job.keys = {"psk"}; job.allowInteraction = false;
    const auto response = CredentialStore::execute(job, CredentialStore::cancellation());
    QVERIFY(response.success); QVERIFY(response.values.isEmpty());
}
void NetworkAgentTests::privateKeyringRoundTrip() {
    if (!qEnvironmentVariableIsSet("SHELL_TEST_PRIVATE_KEYRING")) QSKIP("Requires the isolated keyring harness");
    const auto directory = qgetenv("XDG_DATA_HOME");
    QVERIFY(directory.startsWith("/tmp/shell-private-keyring-"));
    const auto pid = QDBusConnection::sessionBus().interface()->servicePid("org.freedesktop.secrets");
    QVERIFY(pid.isValid());
    QFile environment(QString("/proc/%1/environ").arg(pid.value()));
    QVERIFY(environment.open(QIODevice::ReadOnly));
    QVERIFY(environment.readAll().split('\0').contains("XDG_DATA_HOME=" + directory));
    CredentialStore::Job job; job.uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    job.setting = Setting; job.label = "Isolated shell credential test"; job.keys = {"psk"};
    auto token = CredentialStore::cancellation();
    auto response = CredentialStore::execute(job, token);
    QVERIFY2(response.success, qPrintable(response.error)); QVERIFY(response.values.isEmpty());
    job.operation = CredentialStore::Operation::Save; job.values = {{"psk", "fixture-password-only"}};
    response = CredentialStore::execute(job, token); QVERIFY2(response.success, qPrintable(response.error));
    job.operation = CredentialStore::Operation::Lookup;
    response = CredentialStore::execute(job, token); QVERIFY2(response.success, qPrintable(response.error));
    QCOMPARE(response.values["psk"].toString(), "fixture-password-only");
    job.operation = CredentialStore::Operation::Delete;
    response = CredentialStore::execute(job, token); QVERIFY2(response.success, qPrintable(response.error));
    job.operation = CredentialStore::Operation::Lookup;
    response = CredentialStore::execute(job, token); QVERIFY(response.success); QVERIFY(response.values.isEmpty());
    CredentialStore::cancel(token);
    response = CredentialStore::execute(job, token); QVERIFY(!response.success); QVERIFY(response.cancelled);
}
QTEST_GUILESS_MAIN(NetworkAgentTests)
