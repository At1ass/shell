#include <QDBusObjectPath>
#include <QDBusVirtualObject>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QUuid>
#include <QtTest>
#include <memory>

#include "../AccountProfile.h"

namespace {
QString const Service = QStringLiteral("org.freedesktop.Accounts");
QString const Root = QStringLiteral("/org/freedesktop/Accounts");
QString const Alice = Root + QStringLiteral("/User1000"), Bob = Root + QStringLiteral("/User1001");
class Accounts : public QDBusVirtualObject {
  public:
    QMap<QString, QVariantMap> users;
    QDBusMessage held;
    QVariantList heldArguments;
    QString holdPath;
    int lookups = 0;
    QString introspect(QString const &) const override { return {}; }
    bool handleMessage(QDBusMessage const &message, QDBusConnection const &bus) override {
        QVariantList args;
        if (message.member() == QStringLiteral("FindUserByName")) {
            ++lookups;
            auto const name = message.arguments().value(0).toString();
            QString path;
            for (auto it = users.cbegin(); it != users.cend(); ++it)
                if (it.value().value("UserName").toString() == name)
                    path = it.key();
            if (path.isEmpty()) {
                bus.send(message.createErrorReply(Service + ".Error.Failed", "Unknown"));
                return true;
            }
            args = {QVariant::fromValue(QDBusObjectPath(path))};
        } else if (message.member() == QStringLiteral("GetAll") && users.contains(message.path())) {
            args = {users.value(message.path())};
        } else {
            bus.send(message.createErrorReply(Service + ".Error.Failed", "Unknown"));
            return true;
        }
        if (message.path() == holdPath) {
            held = message;
            heldArguments = args;
            holdPath.clear();
            return true;
        }
        bus.send(message.createReply(args));
        return true;
    }
};
struct Fixture {
    QTemporaryDir dir;
    QDBusConnection server = QDBusConnection::sessionBus();
    QString id = QUuid::createUuid().toString();
    QDBusConnection client = QDBusConnection::connectToBus(QDBusConnection::SessionBus, id);
    Accounts accounts;
    std::unique_ptr<AccountProfile> profile;
    QString shared() const { return dir.path() + "/shared"; }
    QString icon() const { return shared() + "/alice.png"; }
    Fixture() {
        QDir().mkpath(shared());
        QFile file(icon());
        if (!file.open(QIODevice::WriteOnly))
            qFatal("Icon fixture failed");
        file.write("fixture");
        file.close();
        accounts.users[Alice] = {{"UserName", "alice"}, {"RealName", "Alice"}, {"IconFile", icon()}};
        accounts.users[Bob] = {{"UserName", "bob"}, {"RealName", "Bob"}, {"IconFile", ""}};
        if (!server.registerService(Service) ||
            !server.registerVirtualObject(Root, &accounts, QDBusConnection::SubPath))
            qFatal("Private Accounts fixture failed");
        profile = std::make_unique<AccountProfile>(client, QStringList{shared()});
    }
    ~Fixture() {
        profile.reset();
        server.unregisterObject(Root, QDBusConnection::UnregisterTree);
        server.unregisterService(Service);
        QDBusConnection::disconnectFromBus(id);
    }
    void changed(QString const &path) { server.send(QDBusMessage::createSignal(path, Service + ".User", "Changed")); }
    void release() {
        server.send(accounts.held.createReply(accounts.heldArguments));
        accounts.held = {};
        accounts.heldArguments.clear();
    }
};
} // namespace
class AccountProfileTests : public QObject {
    Q_OBJECT
  private slots:
    void refreshAndSamePathReplacement() {
        Fixture f;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.profile->ready());
        QCOMPARE(f.profile->displayName(), "Alice");
        QCOMPARE(f.profile->iconSource().toLocalFile(), f.icon());
        auto const first = f.profile->iconSource();
        f.accounts.users[Alice]["RealName"] = "Alice Updated";
        f.changed(Alice);
        QTRY_COMPARE(f.profile->displayName(), "Alice Updated");
        QVERIFY(first != f.profile->iconSource());
    }
    void delayedResponseCannotReplaceSelectedUser() {
        Fixture f;
        f.accounts.holdPath = Alice;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.accounts.held.type() == QDBusMessage::MethodCallMessage);
        f.profile->setUsername("bob");
        QVERIFY(!f.profile->ready());
        QVERIFY(f.profile->iconSource().isEmpty());
        f.release();
        QTRY_VERIFY(f.profile->ready());
        QCOMPARE(f.profile->displayName(), "Bob");
        QVERIFY(f.profile->iconSource().isEmpty());
    }
    void disabledAndMissingUsersHaveNoStaleAvatar() {
        Fixture f;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.profile->ready());
        f.profile->setActive(false);
        QVERIFY(!f.profile->ready());
        QVERIFY(f.profile->iconSource().isEmpty());
        f.profile->setUsername("bob");
        QTest::qWait(20);
        int const lookups = f.accounts.lookups;
        QTest::qWait(20);
        QCOMPARE(f.accounts.lookups, lookups);
        f.profile->setActive(true);
        QTRY_VERIFY(f.profile->ready());
        QCOMPARE(f.profile->displayName(), "Bob");
        f.profile->setUsername("unknown");
        QTRY_VERIFY(f.accounts.lookups > lookups + 1);
        QVERIFY(!f.profile->ready());
        QVERIFY(f.profile->displayName().isEmpty());
    }
    void privateAndEscapingIconPathsAreRejected() {
        Fixture f;
        QString const privateFile = f.dir.path() + "/private.png";
        QFile file(privateFile);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("private");
        file.close();
        f.accounts.users[Alice]["IconFile"] = privateFile;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.profile->ready());
        QVERIFY(f.profile->iconSource().isEmpty());
        auto const link = f.shared() + "/escape.png";
        QVERIFY(QFile::link(privateFile, link));
        f.accounts.users[Alice]["IconFile"] = link;
        auto const before = f.accounts.lookups;
        f.changed(Alice);
        QTRY_VERIFY(f.accounts.lookups > before);
        QTest::qWait(20);
        QVERIFY(f.profile->iconSource().isEmpty());
    }
    void ownerLossClearsAndRestartRecovers() {
        Fixture f;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.profile->ready());
        QVERIFY(f.server.unregisterService(Service));
        QTRY_VERIFY(!f.profile->ready());
        QVERIFY(f.profile->iconSource().isEmpty());
        f.accounts.users[Alice]["RealName"] = "After restart";
        QVERIFY(f.server.registerService(Service));
        QTRY_VERIFY(f.profile->ready());
        QCOMPARE(f.profile->displayName(), "After restart");
    }
    void destructionWithPendingReply() {
        Fixture f;
        f.accounts.holdPath = Alice;
        f.profile->setUsername("alice");
        QTRY_VERIFY(f.accounts.held.type() == QDBusMessage::MethodCallMessage);
        f.profile.reset();
        f.release();
        QTest::qWait(20);
    }
};
QTEST_GUILESS_MAIN(AccountProfileTests)
#include "AccountProfileTests.moc"
