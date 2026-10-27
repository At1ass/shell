#include "../VpnProfiles.h"
#include "../NetworkSettings.h"
#include <QtTest>
#include <QDBusVirtualObject>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QUuid>

namespace {
const QString Service = "org.freedesktop.NetworkManager", Root = "/org/freedesktop/NetworkManager";
const QString Settings = Service + ".Settings", Connection = Settings + ".Connection", Active = Service + ".Connection.Active";
const QString Uuid1 = "3630bbf6-a548-41de-9f58-07eafde18739", Uuid2 = "4630bbf6-a548-41de-9f58-07eafde18739";
const QString Path1 = Root + "/Settings/1", Path2 = Root + "/Settings/2", Active1 = Root + "/ActiveConnection/1", Active2 = Root + "/ActiveConnection/2";
using Paths = QList<QDBusObjectPath>;
NetworkSettings profile(const QString& uuid, const QString& name, const QString& type = "vpn") {
    return {{"connection", {{"uuid", uuid}, {"id", name}, {"type", type}}}};
}
QVariantMap active(const QString& uuid, const QString& name, uint state) {
    return {{"Uuid", uuid}, {"Id", name}, {"Type", "vpn"}, {"State", state}};
}
class Manager : public QDBusVirtualObject {
public:
    QMap<QString, NetworkSettings> profiles{{Path1, profile(Uuid1, "Work: VPN\\One\nSecond line")}, {Path2, profile(Uuid2, "Work: VPN\\One\nSecond line")}};
    QMap<QString, QVariantMap> activeConnections;
    bool listError = false;
    QString holdPath;
    QDBusMessage held;
    QVariantList heldArguments;
    int lists = 0, secrets = 0;
    QString introspect(const QString&) const override { return {}; }
    bool handleMessage(const QDBusMessage& message, const QDBusConnection& bus) override {
        QVariantList reply;
        if (message.member() == "GetSecrets") { ++secrets; return false; }
        if (message.member() == "ListConnections" && !listError) {
            ++lists; Paths paths;
            for (const auto& path : profiles.keys()) paths.append(QDBusObjectPath(path));
            reply = {QVariant::fromValue(paths)};
        } else if (message.member() == "GetSettings" && profiles.contains(message.path())) reply = {QVariant::fromValue(profiles.value(message.path()))};
        else if (message.member() == "GetAll" && message.path() == Root) {
            Paths paths; for (const auto& path : activeConnections.keys()) paths.append(QDBusObjectPath(path));
            reply = {QVariantMap{{"ActiveConnections", QVariant::fromValue(paths)}}};
        } else if (message.member() == "GetAll" && activeConnections.contains(message.path())) reply = {activeConnections.value(message.path())};
        else { bus.send(message.createErrorReply(Service + ".Unavailable", "Fixture failure")); return true; }
        if (holdPath == message.path()) { held = message; heldArguments = reply; holdPath.clear(); return true; }
        bus.send(message.createReply(reply)); return true;
    }
};
struct Fixture {
    QDBusConnection server = QDBusConnection::sessionBus();
    QString id = QUuid::createUuid().toString(QUuid::Id128);
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id);
    Manager manager;
    std::unique_ptr<VpnProfiles> model;
    Fixture() {
        if (!server.registerService(Service) || !server.registerVirtualObject(Root, &manager, QDBusConnection::SubPath)) qFatal("Private NM fixture failed");
        model = std::make_unique<VpnProfiles>(client); model->setEnabled(true);
    }
    ~Fixture() {
        model.reset(); server.unregisterObject(Root, QDBusConnection::UnregisterTree); server.unregisterService(Service);
        QDBusConnection::disconnectFromBus(id); QTest::qWait(5);
    }
    void signal(const QString& path, const QString& interface, const QString& name, const QVariantList& args = {}) {
        auto message = QDBusMessage::createSignal(path, interface, name); message.setArguments(args); server.send(message);
    }
    void release() { server.send(manager.held.createReply(manager.heldArguments)); manager.held = {}; }
};
}
class VpnProfilesTests : public QObject {
    Q_OBJECT
private slots:
    void metadataAndDuplicateNames() {
        Fixture f;
        f.manager.profiles[Root + "/Settings/3"] = profile("5630bbf6-a548-41de-9f58-07eafde18739", "Ethernet", "802-3-ethernet");
        f.manager.profiles[Root + "/Settings/4"] = profile("invalid", "Invalid");
        QTRY_VERIFY(f.model->ready()); QCOMPARE(f.model->profiles().size(), 2);
        QCOMPARE(f.model->profile(Uuid1).value("name").toString(), "Work: VPN\\One\nSecond line");
        QVERIFY(f.model->profile(Uuid1) != f.model->profile(Uuid2));
        QVERIFY(f.model->profile("unknown").isEmpty()); QCOMPARE(f.manager.secrets, 0);
    }
    void profileSignalsAndStates() {
        Fixture f; QTRY_VERIFY(f.model->ready());
        f.manager.profiles[Path1] = profile(Uuid1, "Renamed");
        f.signal(Path1, Connection, "Updated");
        QTRY_COMPARE(f.model->profile(Uuid1).value("name").toString(), "Renamed");
        const auto third = Root + "/Settings/3";
        f.manager.profiles[third] = profile("5630bbf6-a548-41de-9f58-07eafde18739", "Added");
        f.signal(Root + "/Settings", Settings, "NewConnection", {QVariant::fromValue(QDBusObjectPath(third))});
        QTRY_COMPARE(f.model->profiles().size(), 3);
        f.manager.activeConnections = {{Active1, active(Uuid1, "Renamed", 1)}, {Active2, active(Uuid2, "Second", 2)}};
        f.signal(Root, "org.freedesktop.DBus.Properties", "PropertiesChanged", {Service, QVariantMap{}, QStringList{"ActiveConnections"}});
        QTRY_VERIFY(f.model->profile(Uuid1).value("busy").toBool());
        QVERIFY(f.model->profile(Uuid2).value("connected").toBool());
        f.manager.activeConnections[Active1]["State"] = 2u;
        f.signal(Active1, Active, "StateChanged", {2u, 0u});
        QTRY_VERIFY(f.model->profile(Uuid1).value("connected").toBool());
        QVERIFY(f.model->profile(Uuid2).value("connected").toBool());
        QCOMPARE(f.model->activeUuids().size(), 2); QCOMPARE(f.model->names().size(), 3);
        QVERIFY(f.model->activeNames().contains("Renamed"));
        f.manager.activeConnections.clear(); f.manager.profiles.remove(Path2);
        f.signal(Path2, Connection, "Removed");
        QTRY_VERIFY(f.model->profile(Uuid2).isEmpty());
        QVERIFY(!f.model->profile(Uuid1).value("connected").toBool());
    }
    void dirtyReplyCannotPublishOldName() {
        Fixture f; f.manager.holdPath = Path1;
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        f.manager.profiles[Path1] = profile(Uuid1, "Latest");
        f.signal(Path1, Connection, "Updated"); QTest::qWait(10);
        f.release(); QTRY_VERIFY(f.model->ready());
        QCOMPARE(f.model->profile(Uuid1).value("name").toString(), "Latest");
    }
    void disableAndRestart() {
        Fixture f; f.manager.holdPath = Path1;
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        f.model->setEnabled(false); f.release(); QTest::qWait(20);
        QVERIFY(!f.model->ready()); QVERIFY(f.model->profiles().isEmpty());
        const auto count = f.manager.lists;
        f.signal(Path1, Connection, "Updated"); QTest::qWait(10); QCOMPARE(f.manager.lists, count);
        f.model->setEnabled(true); QTRY_VERIFY(f.model->ready());
        f.server.unregisterService(Service); QTRY_VERIFY(!f.model->ready()); QVERIFY(f.model->profiles().isEmpty());
        QVERIFY(f.server.registerService(Service)); QTRY_VERIFY(f.model->ready());
    }
    void refreshFailureRetainsWorkingSnapshot() {
        Fixture f; QTRY_VERIFY(f.model->ready());
        const auto before = f.model->profiles();
        f.manager.listError = true; f.model->refresh(); QTRY_VERIFY(!f.model->errorString().isEmpty());
        QCOMPARE(f.model->profiles(), before);
        f.manager.listError = false; f.model->refresh(); QTRY_VERIFY(f.model->errorString().isEmpty());
        QCOMPARE(f.model->profiles(), before);
    }
    void coalescingAndPendingDestruction() {
        Fixture f; f.manager.holdPath = Path1;
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        for (int i = 0; i < 100; ++i) f.model->refresh();
        QCOMPARE(f.manager.lists, 1); f.release(); QTRY_VERIFY(f.model->ready()); QCOMPARE(f.manager.lists, 2);
        f.manager.holdPath = Path1; f.model->refresh();
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        QElapsedTimer timer; timer.start(); f.model.reset(); QVERIFY(timer.elapsed() < 100);
        f.release(); QTest::qWait(10);
    }
};
QTEST_GUILESS_MAIN(VpnProfilesTests)
#include "VpnProfilesTests.moc"
