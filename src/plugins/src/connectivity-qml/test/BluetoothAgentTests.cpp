#include "BluetoothAgentTests.h"
#include "../BluetoothPairingAgent.h"
#include <QtTest>
#include <QDBusPendingCall>
#include <QDBusPendingReply>
#include <QDBusConnection>
#include <QUuid>
#include <memory>

void FakeManager::RegisterAgent(const QDBusObjectPath& agent, const QString& caps) {
    ++registrations;
    if (rejectOnce || (!path.isEmpty() && client == message().service())) {
        rejectOnce = false;
        sendErrorReply("org.bluez.Error.AlreadyExists", "Agent already registered");
        return;
    }
    path = agent.path(); client = message().service(); capability = caps;
    if (holdRegistration) { setDelayedReply(true); registrationRequest = message(); }
}
void FakeManager::UnregisterAgent(const QDBusObjectPath& agent) {
    if (agent.path() == path && client == message().service()) { path.clear(); client.clear(); }
}
void FakeDevice::Pair() { ++pairs; setDelayedReply(true); pairRequest = message(); }
void FakeDevice::CancelPairing() { ++cancels; }
void FakeDevice::finish(bool success) {
    if (pairRequest.type() != QDBusMessage::MethodCallMessage) return;
    QDBusConnection::sessionBus().send(success ? pairRequest.createReply()
        : pairRequest.createErrorReply("org.bluez.Error.AuthenticationFailed", "Authentication failed"));
    pairRequest = QDBusMessage();
}
namespace {
const QString Device = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF";
const QVariant Object = QVariant::fromValue(QDBusObjectPath(Device));
struct Fixture {
    QString id = QUuid::createUuid().toString(QUuid::Id128);
    QDBusConnection server = QDBusConnection::sessionBus();
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id);
    QDBusConnection outsider = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id + "other");
    FakeManager manager;
    FakeDevice device;
    std::unique_ptr<BluetoothPairingAgent> agent;
    Fixture() {
        if (!server.registerService("org.bluez") || !server.registerObject("/org/bluez", &manager, QDBusConnection::ExportAllSlots)
            || !server.registerObject(Device, &device, QDBusConnection::ExportAllSlots)) qFatal("Private BlueZ fixture failed");
        agent = std::make_unique<BluetoothPairingAgent>(client);
        agent->setBlocked(false); agent->setEnabled(true);
    }
    ~Fixture() {
        agent.reset();
        QTest::qWait(10);
        server.unregisterObject(Device); server.unregisterObject("/org/bluez"); server.unregisterService("org.bluez");
        QDBusConnection::disconnectFromBus(id); QDBusConnection::disconnectFromBus(id + "other");
    }
    QDBusPendingCall request(const QString& member, const QVariantList& args = {}, bool intruder = false) {
        auto call = QDBusMessage::createMethodCall(client.baseService(), agent->objectPath(), "org.bluez.Agent1", member);
        call.setArguments(args);
        return (intruder ? outsider : server).asyncCall(call, 2000);
    }
    void arm() { if (!agent->arm(Device, "Keyboard", "AA:BB:CC:DD:EE:FF")) qFatal("Could not arm fixture"); }
};
}
void BluetoothAgentTests::inputAndConfirmation() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); QCOMPARE(f.manager.capability, "KeyboardDisplay"); QCOMPARE(f.manager.defaults, 0);
    f.arm(); auto pin = f.request("RequestPinCode", {Object});
    QTRY_COMPARE(f.agent->requestKind(), "pin"); QVERIFY(!pin.isFinished());
    const auto token = f.agent->requestToken();
    QVERIFY(!f.agent->submit(token, "")); QVERIFY(!f.agent->validationError().isEmpty());
    QVERIFY(!f.agent->submit("old", "1234")); QVERIFY(f.agent->submit(token, "0012"));
    QTRY_VERIFY(pin.isFinished()); QDBusPendingReply<QString> pinReply(pin); QCOMPARE(pinReply.value(), "0012");
    auto passkey = f.request("RequestPasskey", {Object}); QTRY_COMPARE(f.agent->requestKind(), "passkey");
    QVERIFY(!f.agent->submit(f.agent->requestToken(), "1234567"));
    QVERIFY(!f.agent->submit(f.agent->requestToken(), "-1"));
    QVERIFY(f.agent->submit(f.agent->requestToken(), "000012"));
    QTRY_VERIFY(passkey.isFinished()); QDBusPendingReply<quint32> passReply(passkey); QCOMPARE(passReply.value(), 12u);
    auto confirmation = f.request("RequestConfirmation", {Object, quint32(7)});
    QTRY_COMPARE(f.agent->code(), "000007"); QVERIFY(!confirmation.isFinished());
    QVERIFY(f.agent->submit(f.agent->requestToken(), "")); QTRY_VERIFY(confirmation.isFinished());
    QVERIFY(!confirmation.isError());
}
void BluetoothAgentTests::authorizationAndDisplay() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.arm();
    auto auth = f.request("RequestAuthorization", {Object}); QTRY_COMPARE(f.agent->requestKind(), "authorize");
    QVERIFY(!auth.isFinished()); QVERIFY(f.agent->submit(f.agent->requestToken(), "")); QTRY_VERIFY(auth.isFinished());
    auto service = f.request("AuthorizeService", {Object, "0000110b-0000-1000-8000-00805f9b34fb"});
    QTRY_COMPARE(f.agent->requestKind(), "service"); QVERIFY(!service.isFinished());
    QVERIFY(f.agent->submit(f.agent->requestToken(), "")); QTRY_VERIFY(service.isFinished());
    auto display = f.request("DisplayPasskey", {Object, quint32(42), QVariant::fromValue(quint16(2))});
    QTRY_VERIFY(display.isFinished()); QVERIFY2(!display.isError(), qPrintable(QDBusPendingReply<>(display).error().message())); QCOMPARE(f.agent->code(), "000042");
    QCOMPARE(f.agent->entered(), 2); const auto token = f.agent->requestToken();
    auto progress = f.request("DisplayPasskey", {Object, quint32(42), QVariant::fromValue(quint16(3))});
    QTRY_VERIFY(progress.isFinished()); QCOMPARE(f.agent->entered(), 3); QCOMPARE(f.agent->requestToken(), token);
    QVERIFY(!f.agent->submit(token, ""));
    auto cancelDisplay = f.request("Cancel"); QTRY_VERIFY(cancelDisplay.isFinished());
    QVERIFY(f.agent->requestToken().isEmpty()); QVERIFY(f.agent->armed()); QCOMPARE(f.device.cancels, 0);
    auto pin = f.request("DisplayPinCode", {Object, "012345"}); QTRY_VERIFY(pin.isFinished());
    QCOMPARE(f.agent->code(), "012345"); QCOMPARE(f.agent->requestKind(), "display-pin");
}
void BluetoothAgentTests::rejectUnsolicited() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    auto idle = f.request("RequestPinCode", {Object}); QTRY_VERIFY(idle.isFinished()); QVERIFY(idle.isError());
    QVERIFY(!f.agent->arm("/tmp/device", "", "")); f.arm();
    auto bad = f.request("RequestPinCode", {Object}, true); QTRY_VERIFY(bad.isFinished()); QVERIFY(bad.isError());
    auto wrong = f.request("RequestPinCode", {QVariant::fromValue(QDBusObjectPath("/org/bluez/hci1/dev_AA_BB_CC_DD_EE_FF"))});
    QTRY_VERIFY(wrong.isFinished()); QVERIFY(wrong.isError());
    auto malformed = f.request("RequestConfirmation", {Object, quint32(1000000)}); QTRY_VERIFY(malformed.isFinished()); QVERIFY(malformed.isError());
    auto pin = f.request("RequestPinCode", {Object}); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    const auto token = f.agent->requestToken();
    auto overlap = f.request("RequestAuthorization", {Object}); QTRY_VERIFY(overlap.isFinished()); QVERIFY(overlap.isError());
    QCOMPARE(f.agent->requestToken(), token); QVERIFY(f.agent->reject(token)); QTRY_VERIFY(pin.isFinished()); QVERIFY(pin.isError());
}
void BluetoothAgentTests::cancellation() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.arm();
    QSignalSpy cancelled(f.agent.get(), &BluetoothPairingAgent::operationCancelled);
    auto request = f.request("RequestPinCode", {Object}); QTRY_VERIFY(!f.agent->requestToken().isEmpty());
    const auto old = f.agent->requestToken(); f.agent->setBlocked(true);
    QTRY_VERIFY(request.isFinished()); QVERIFY(request.isError()); QTRY_COMPARE(f.device.cancels, 1);
    QCOMPARE(cancelled.size(), 1); QVERIFY(!f.agent->armed()); QVERIFY(!f.agent->submit(old, "1234"));
    QVERIFY(!f.agent->arm(Device, "", "")); f.agent->setBlocked(false);
    f.agent->setTimeoutMs(30); f.arm(); QTRY_VERIFY(!f.agent->armed()); QTRY_COMPARE(f.device.cancels, 2);
    f.agent->setTimeoutMs(10000); f.arm(); f.agent->deviceRemoved(Device);
    QTRY_COMPARE(f.device.cancels, 3); QVERIFY(!f.agent->armed());
    f.arm(); f.agent->setEnabled(false); QVERIFY(!f.agent->registered()); QVERIFY(!f.agent->armed());
    f.agent->setEnabled(true); QTRY_VERIFY(f.agent->registered()); QCOMPARE(f.manager.defaults, 0);
}
void BluetoothAgentTests::transportCompletion() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.arm();
    QSignalSpy finished(f.agent.get(), &BluetoothPairingAgent::operationFinished);
    QVERIFY(f.agent->startPair()); QVERIFY(!f.agent->startPair()); QTRY_COMPARE(f.device.pairs, 1);
    f.device.finish(true); QTRY_COMPARE(finished.size(), 1); QCOMPARE(finished[0][1].toBool(), true); QVERIFY(!f.agent->busy());
    f.arm(); QVERIFY(f.agent->startPair()); QTRY_COMPARE(f.device.pairs, 2);
    f.device.finish(false); QTRY_COMPARE(finished.size(), 2); QCOMPARE(finished[1][1].toBool(), false);
    QCOMPARE(finished[1][2].toString(), "Authentication failed");
    f.arm(); QVERIFY(f.agent->startPair()); QTRY_COMPARE(f.device.pairs, 3);
    f.agent->abort(); QVERIFY(f.agent->busy()); QVERIFY(!f.agent->arm(Device, "", ""));
    f.device.finish(false); QTRY_VERIFY(!f.agent->busy()); QCOMPARE(finished.size(), 2);
    f.arm(); QVERIFY(f.agent->startPair()); QTRY_COMPARE(f.device.pairs, 4);
    QSignalSpy state(f.agent.get(), &BluetoothPairingAgent::stateChanged);
    f.agent.reset(); QCOMPARE(state.size(), 0); QTRY_COMPARE(f.device.cancels, 2); f.device.finish(false);
}
void BluetoothAgentTests::daemonRestartAndReload() {
    Fixture f; QTRY_VERIFY(f.agent->registered()); f.arm();
    f.server.unregisterService("org.bluez"); QTRY_VERIFY(!f.agent->registered()); QVERIFY(!f.agent->armed());
    f.manager.path.clear(); f.manager.client.clear(); f.manager.rejectOnce = true;
    QVERIFY(f.server.registerService("org.bluez")); QTRY_VERIFY(f.agent->registered()); QVERIFY(f.manager.registrations >= 3);
    const auto oldPath = f.agent->objectPath(); f.agent.reset();
    f.agent = std::make_unique<BluetoothPairingAgent>(f.client); f.agent->setBlocked(false); f.agent->setEnabled(true);
    QTRY_VERIFY(f.agent->registered()); QVERIFY(oldPath != f.agent->objectPath()); QCOMPARE(f.manager.defaults, 0);
    for (int i = 0; i < 3; ++i) { f.agent->setEnabled(false); f.agent->setEnabled(true); }
    QTRY_VERIFY(f.agent->registered());
}
void BluetoothAgentTests::staleRegistrationReply() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    f.agent->setEnabled(false); QTRY_VERIFY(f.manager.path.isEmpty());
    f.manager.holdRegistration = true;
    f.agent->setEnabled(true);
    QTRY_COMPARE(f.manager.registrationRequest.type(), QDBusMessage::MethodCallMessage);
    f.server.unregisterService("org.bluez"); QTest::qWait(10);
    QVERIFY(!f.agent->registered());
    f.manager.path.clear(); f.manager.client.clear(); f.manager.holdRegistration = false;
    QVERIFY(f.server.registerService("org.bluez")); QTRY_VERIFY(f.agent->registered());
    f.server.send(f.manager.registrationRequest.createReply()); QTest::qWait(10);
    QVERIFY(f.agent->registered()); f.arm(); QVERIFY(f.agent->armed());
}
void BluetoothAgentTests::timedOutTransport() {
    Fixture f; QTRY_VERIFY(f.agent->registered());
    f.agent->setTimeoutMs(50); f.arm(); QVERIFY(f.agent->startPair());
    QSignalSpy finished(f.agent.get(), &BluetoothPairingAgent::operationFinished);
    QTRY_COMPARE(f.device.pairs, 1); QTRY_VERIFY(!f.agent->armed());
    QVERIFY(f.agent->busy()); QTRY_COMPARE(f.device.cancels, 1);
    f.device.finish(true); QTRY_VERIFY(!f.agent->busy()); QCOMPARE(finished.size(), 0);
    f.agent->setTimeoutMs(10000); f.arm();
    auto display = f.request("DisplayPinCode", {Object, "000123"}); QTRY_VERIFY(display.isFinished());
    f.manager.path.clear(); f.manager.client.clear();
    auto release = f.request("Release"); QTRY_VERIFY(release.isFinished());
    QVERIFY(!f.agent->armed()); QTRY_VERIFY(f.agent->registered()); QCOMPARE(f.manager.defaults, 0);
}
QTEST_GUILESS_MAIN(BluetoothAgentTests)
