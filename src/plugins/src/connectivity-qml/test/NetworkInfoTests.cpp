#include "../NetworkInterfaceInfo.h"
#include <QtTest>
#include <QDBusVirtualObject>
#include <QDBusObjectPath>
#include <QDBusMetaType>
#include <QElapsedTimer>
#include <QUuid>

namespace {
const QString Service = "org.freedesktop.NetworkManager";
const QString Root = "/org/freedesktop/NetworkManager";
const QString Device = Service + ".Device";
const QString Properties = "org.freedesktop.DBus.Properties";
const QString Device1 = Root + "/Devices/1", Device2 = Root + "/Devices/2";
const QString Ip4 = Root + "/IP4Config/1", Ip6 = Root + "/IP6Config/1", Ip6Other = Root + "/IP6Config/2";
using AddressData = QList<QVariantMap>;
QVariantMap family(const QStringList& addresses, const QString& gateway, uint prefix = 64) {
    AddressData data;
    for (const auto& address : addresses) data.append({{"address", address}, {"prefix", prefix}});
    return {{"AddressData", QVariant::fromValue(data)}, {"Gateway", gateway}};
}
QVariantMap device(const QString& ipv4, const QString& ipv6, uint state = 100) {
    return {{"State", state}, {"Ip4Config", QVariant::fromValue(QDBusObjectPath(ipv4))},
            {"Ip6Config", QVariant::fromValue(QDBusObjectPath(ipv6))}};
}
class Manager : public QDBusVirtualObject {
public:
    QMap<QString, QVariantMap> properties;
    QDBusMessage held;
    QVariantList heldArguments;
    QString holdPath;
    int lookups = 0;
    explicit Manager(QObject* parent = nullptr) : QDBusVirtualObject(parent) {
        properties[Device1] = device("/", Ip6);
        properties[Device2] = device("/", Ip6Other);
        properties[Ip6] = family({"2001:db8::10", "fe80::10"}, "fe80::1");
        properties[Ip6Other] = family({"2001:db8:1::20"}, "fe80::2");
    }
    QString introspect(const QString&) const override { return {}; }
    bool handleMessage(const QDBusMessage& message, const QDBusConnection& bus) override {
        QVariantList reply;
        if (message.member() == "GetDeviceByIpIface") {
            ++lookups;
            const auto name = message.arguments().first().toString();
            if (name != "eth0" && name != "eth1") {
                bus.send(message.createErrorReply(Service + ".UnknownDevice", "Unknown device")); return true;
            }
            reply = {QVariant::fromValue(QDBusObjectPath(name == "eth0" ? Device1 : Device2))};
        } else if (message.member() == "GetAll" && properties.contains(message.path())) reply = {properties.value(message.path())};
        else { bus.send(message.createErrorReply(Service + ".UnknownObject", "Unknown object")); return true; }
        if (message.path() == holdPath) {
            held = message; heldArguments = reply; holdPath.clear(); return true;
        }
        bus.send(message.createReply(reply)); return true;
    }
};
struct Fixture {
    QDBusConnection server = QDBusConnection::sessionBus();
    QString id = QUuid::createUuid().toString(QUuid::Id128);
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id);
    Manager manager;
    std::unique_ptr<NetworkInterfaceInfo> info;
    Fixture() {
        if (!server.registerService(Service) || !server.registerVirtualObject(Root, &manager, QDBusConnection::SubPath)) qFatal("Private NM fixture failed");
        info = std::make_unique<NetworkInterfaceInfo>(client); info->setInterfaceName("eth0");
    }
    ~Fixture() {
        info.reset(); server.unregisterObject(Root, QDBusConnection::UnregisterTree); server.unregisterService(Service);
        QDBusConnection::disconnectFromBus(id); QTest::qWait(5);
    }
    void changed(const QString& path, const QString& interface) {
        auto signal = QDBusMessage::createSignal(path, Properties, "PropertiesChanged");
        signal.setArguments({interface, QVariantMap{}, QStringList{"AddressData"}});
        server.send(signal);
    }
    void release() { server.send(manager.held.createReply(manager.heldArguments)); manager.held = {}; }
};
}
class NetworkInfoTests : public QObject {
    Q_OBJECT
private slots:
    void ipv6Only() {
        Fixture f; QTRY_VERIFY(f.info->ready());
        QVERIFY(f.info->ipv4Addresses().isEmpty()); QVERIFY(f.info->ipv4Gateway().isEmpty());
        QCOMPARE(f.info->ipv6Addresses(), (QStringList{"2001:db8::10/64", "fe80::10/64"}));
        QCOMPARE(f.info->ipv6Gateway(), "fe80::1");
    }
    void dualStackAndAddressRemoval() {
        Fixture f; f.manager.properties[Device1] = device(Ip4, Ip6);
        f.manager.properties[Ip4] = family({"192.0.2.10", "192.0.2.11"}, "192.0.2.1", 24);
        QTRY_VERIFY(f.info->ready()); QCOMPARE(f.info->ipv4Addresses().size(), 2);
        f.manager.properties[Ip4] = family({}, "");
        f.changed(Ip4, Service + ".IP4Config");
        QTRY_VERIFY(f.info->ipv4Addresses().isEmpty()); QVERIFY(f.info->ipv4Gateway().isEmpty());
        QCOMPARE(f.info->ipv6Addresses().size(), 2); QVERIFY(f.info->ready());
        f.manager.properties[Ip6] = family({}, "");
        f.changed(Ip6, Service + ".IP6Config"); QTRY_VERIFY(f.info->ipv6Addresses().isEmpty());
        QVERIFY(f.info->ipv6Gateway().isEmpty()); QVERIFY(f.info->ready());
    }
    void replacedConfiguration() {
        Fixture f; QTRY_VERIFY(f.info->ready());
        f.manager.properties[Device1] = device("/", Ip6Other);
        f.changed(Device1, Device); QTRY_COMPARE(f.info->ipv6Gateway(), "fe80::2");
        const int count = f.manager.lookups;
        f.changed(Ip6, Service + ".IP6Config"); QTest::qWait(10); QCOMPARE(f.manager.lookups, count);
        f.manager.properties[Ip6Other] = family({"2001:db8:1::30"}, "fe80::3");
        f.changed(Ip6Other, Service + ".IP6Config"); QTRY_COMPARE(f.info->ipv6Gateway(), "fe80::3");
    }
    void lateReplyAfterInterfaceChange() {
        Fixture f; f.manager.holdPath = Ip6;
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        f.info->setInterfaceName("eth1"); QVERIFY(!f.info->ready()); QVERIFY(f.info->ipv6Addresses().isEmpty());
        f.release(); QTRY_VERIFY(f.info->ready());
        QCOMPARE(f.info->ipv6Addresses(), QStringList{"2001:db8:1::20/64"});
        f.info->setInterfaceName(""); QVERIFY(!f.info->ready()); QVERIFY(f.info->ipv6Addresses().isEmpty());
    }
    void daemonRestart() {
        Fixture f; QTRY_VERIFY(f.info->ready());
        f.manager.holdPath = Ip6; f.info->refresh();
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        f.server.unregisterService(Service); QTRY_VERIFY(!f.info->ready()); QVERIFY(f.info->ipv6Addresses().isEmpty());
        f.release(); QVERIFY(f.server.registerService(Service));
        f.manager.properties[Ip6] = family({"2001:db8::40"}, "fe80::4");
        QTRY_VERIFY(f.info->ready()); QCOMPARE(f.info->ipv6Gateway(), "fe80::4");
    }
    void unavailableAndDisconnected() {
        Fixture f; QTRY_VERIFY(f.info->ready());
        f.manager.properties.remove(Ip6); f.info->refresh();
        QTRY_VERIFY(f.info->ipv6Addresses().isEmpty()); QVERIFY(f.info->ipv6Gateway().isEmpty());
        f.manager.properties[Device1] = device("/", "/", 30);
        f.changed(Device1, Device); QTRY_VERIFY(!f.info->ready());
        f.info->setInterfaceName("missing"); QTest::qWait(10); QVERIFY(!f.info->ready());
    }
    void invalidAddressesAndPrefixes() {
        Fixture f;
        AddressData data = {{{"address", "invalid"}, {"prefix", 64u}}, {{"address", "192.0.2.1"}, {"prefix", 24u}},
                            {{"address", "2001:db8::1"}, {"prefix", 129u}}, {{"address", "2001:db8::2"}, {"prefix", 64u}},
                            {{"address", "2001:db8::2"}, {"prefix", 64u}}, {{"address", "2001:db8::3"}}};
        f.manager.properties[Ip6] = {{"AddressData", QVariant::fromValue(data)}, {"Gateway", "192.0.2.1"}};
        QTRY_VERIFY(f.info->ready()); QCOMPARE(f.info->ipv6Addresses(), QStringList{"2001:db8::2/64"});
        QVERIFY(f.info->ipv6Gateway().isEmpty());
    }
    void coalescingAndDestruction() {
        Fixture f; f.manager.holdPath = Ip6;
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        for (int i = 0; i < 100; ++i) f.info->refresh();
        QCOMPARE(f.manager.lookups, 1); f.release(); QTRY_VERIFY(f.info->ready());
        QCOMPARE(f.manager.lookups, 2);
        f.manager.holdPath = Ip6; f.info->refresh();
        QTRY_VERIFY(f.manager.held.type() == QDBusMessage::MethodCallMessage);
        QElapsedTimer timer; timer.start(); f.info.reset(); QVERIFY(timer.elapsed() < 100);
        f.release(); QTest::qWait(10);
    }
};
QTEST_GUILESS_MAIN(NetworkInfoTests)
#include "NetworkInfoTests.moc"
