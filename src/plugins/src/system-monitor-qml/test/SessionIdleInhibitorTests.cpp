#include <QProcess>
#include <QUuid>
#include <QtDBus/QDBusContext>
#include <QtDBus/QDBusMessage>
#include <QtTest>

#include "../SessionIdleInhibitor.h"

namespace {
QString const Service = QStringLiteral("org.freedesktop.ScreenSaver");
QString const Path = QStringLiteral("/org/freedesktop/ScreenSaver");
}  // namespace
class FakeScreenSaver : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.ScreenSaver")
   public:
    QString connectionName = QUuid::createUuid().toString();
    QDBusConnection bus;
    bool delay = false;
    bool reject = false;
    quint32 next = 0;  // Cookie zero is valid and must be released too.
    int calls = 0;
    QList<quint32> released;
    QList<QPair<QDBusMessage, quint32>> pending;
    explicit FakeScreenSaver(QString const& address)
        : bus(QDBusConnection::connectToBus(address, connectionName)) {}
    bool start() {
        return bus.registerObject(Path, this,
                                  QDBusConnection::ExportAllSlots) &&
               bus.registerService(Service);
    }
    void dropName() { bus.unregisterService(Service); }
    void flush() {
        auto const queue = pending;
        pending.clear();
        for (auto const& item : queue)
            bus.send(
                item.first.createReply({QVariant::fromValue(item.second)}));
    }
    ~FakeScreenSaver() override {
        bus.unregisterService(Service);
        bus.unregisterObject(Path);
        QDBusConnection::disconnectFromBus(connectionName);
    }
   public slots:
    quint32 Inhibit(QString const&, QString const&) {
        ++calls;
        if (reject) {
            sendErrorReply(QDBusError::Failed, "Test rejection");
            return 0;
        }
        auto const cookie = next++;
        if (delay) {
            setDelayedReply(true);
            pending.append({message(), cookie});
        }
        return cookie;
    }
    void UnInhibit(quint32 cookie) { released.append(cookie); }
};
class SessionIdleInhibitorTests : public QObject {
    Q_OBJECT
    QProcess daemon;
    QString address;
    QDBusConnection client{QStringLiteral("unused")};
   private slots:
    void initTestCase() {
        // No access to the user's real ScreenSaver service, even when this
        // binary is invoked directly without dbus-run-session.
        daemon.start("dbus-daemon",
                     {"--session", "--nofork", "--print-address=1"});
        QVERIFY(daemon.waitForStarted());
        QVERIFY(daemon.waitForReadyRead());
        address = QString::fromUtf8(daemon.readLine()).trimmed();
        QVERIFY(!address.isEmpty());
        client = QDBusConnection::connectToBus(address, "idle-test-client");
        QVERIFY(client.isConnected());
    }
    void cleanupTestCase() {
        QDBusConnection::disconnectFromBus("idle-test-client");
        daemon.terminate();
        QVERIFY(daemon.waitForFinished());
    }
    void confirmedCookieAndRelease() {
        FakeScreenSaver server(address);
        QVERIFY(server.start());
        SessionIdleInhibitor controller(client);
        controller.setEnabled(true);
        QTRY_VERIFY(controller.active());
        QVERIFY(!controller.pending());
        QCOMPARE(server.calls, 1);
        controller.setEnabled(true);
        QCOMPARE(server.calls, 1);
        controller.setEnabled(false);
        QTRY_COMPARE(server.released.size(), 1);
        QCOMPARE(server.released[0], quint32(0));
        QVERIFY(!controller.active());
    }
    void lateCookieAfterDisableAndDestroy() {
        FakeScreenSaver server(address);
        server.delay = true;
        QVERIFY(server.start());
        auto* controller = new SessionIdleInhibitor(client);
        controller->setEnabled(true);
        QTRY_COMPARE(server.pending.size(), 1);
        controller->setEnabled(false);
        server.flush();
        QTRY_COMPARE(server.released.size(), 1);
        controller->setEnabled(true);
        QTRY_COMPARE(server.pending.size(), 1);
        delete controller;
        server.flush();
        QTRY_COMPARE(server.released.size(), 2);
    }
    void rapidToggleCoalescesPendingRequests() {
        FakeScreenSaver server(address);
        server.delay = true;
        QVERIFY(server.start());
        SessionIdleInhibitor controller(client);
        controller.setEnabled(true);
        QTRY_COMPARE(server.pending.size(), 1);
        for (int i = 0; i < 20; ++i) {
            controller.setEnabled(false);
            controller.setEnabled(true);
        }
        QCOMPARE(server.calls, 1);
        server.flush();
        QTRY_COMPARE(server.pending.size(), 1);
        QCOMPARE(server.calls, 2);
        server.flush();
        QTRY_VERIFY(controller.active());
        controller.setEnabled(false);
        QTRY_COMPARE(server.released.size(), 2);
    }
    void ownerRestartCannotReleaseReusedCookie() {
        FakeScreenSaver oldOwner(address);
        oldOwner.delay = true;
        QVERIFY(oldOwner.start());
        SessionIdleInhibitor controller(client);
        controller.setEnabled(true);
        QTRY_COMPARE(oldOwner.pending.size(), 1);
        oldOwner.dropName();
        FakeScreenSaver newOwner(address);
        QVERIFY(newOwner.start());
        QTRY_VERIFY(controller.active());
        QCOMPARE(newOwner.calls, 1);
        oldOwner.flush();
        QTRY_COMPARE(oldOwner.released.size(), 1);
        QCOMPARE(newOwner.released.size(), 0);
        QVERIFY(controller.active());
        controller.setEnabled(false);
        QTRY_COMPARE(newOwner.released.size(), 1);
    }
    void serviceFailureAndRecovery() {
        FakeScreenSaver server(address);
        server.reject = true;
        QVERIFY(server.start());
        SessionIdleInhibitor controller(client);
        controller.setEnabled(true);
        QTRY_VERIFY(!controller.error().isEmpty());
        QVERIFY(!controller.active());
        QVERIFY(!controller.pending());
        server.reject = false;
        QVERIFY(controller.retry());
        QTRY_VERIFY(controller.active());
        QVERIFY(controller.error().isEmpty());
        controller.setEnabled(false);
        QTRY_COMPARE(server.released.size(), 1);
    }
};
QTEST_GUILESS_MAIN(SessionIdleInhibitorTests)
#include "SessionIdleInhibitorTests.moc"
