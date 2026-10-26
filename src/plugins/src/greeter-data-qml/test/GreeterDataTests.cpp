#include "GreeterDataTests.h"
#include "../Catalog.h"
#include "../GreeterDataBackend.h"
#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QThreadPool>
#ifndef Q_MOC_RUN
#pragma push_macro("signals")
#undef signals
#include <glib.h>
#pragma pop_macro("signals")
#endif

namespace {
void write(const QString& path, const QByteArray& data) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size()) qFatal("Fixture write failed");
}
QByteArray desktop(const QString& command, const QString& name = "Session") {
    GKeyFile* key = g_key_file_new();
    g_key_file_set_string(key, "Desktop Entry", "Type", "Application");
    g_key_file_set_string(key, "Desktop Entry", "Name", name.toUtf8().constData());
    g_key_file_set_string(key, "Desktop Entry", "Exec", command.toUtf8().constData());
    gsize length = 0;
    gchar* text = g_key_file_to_data(key, &length, nullptr);
    const QByteArray result(text, length);
    g_free(text);
    g_key_file_unref(key);
    return result;
}
struct Fixture {
    QTemporaryDir directory;
    GreeterCatalog::Input input;
    QString binary;
    Fixture() {
        binary = directory.path() + "/bin/session";
        write(binary, "#!/bin/sh\nexit 0\n");
        QFile::setPermissions(binary, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
        input.dataDirectories = {directory.path() + "/local", directory.path() + "/system"};
        input.executablePaths = {directory.path() + "/bin"};
        input.locale = "C";
        input.passwdPath = directory.path() + "/passwd";
        write(input.passwdPath, "alice:x:1000:1000:Alice,,,:/home/alice:/bin/sh\n");
    }
    QVariantMap parse(const QByteArray& data, QString* error) const {
        return GreeterCatalog::parseSession(data, directory.path() + "/sample.desktop", "wayland", input, error);
    }
};
}

void GreeterDataTests::quotedArgumentsAndEscapes() {
        Fixture f;
        QString error;
        auto result = f.parse(desktop(R"(session "two words" "" "quote\"inside" "back\\slash" "$HOME" "`touch sentinel`")"), &error);
        QVERIFY2(!result.isEmpty(), qPrintable(error));
        QCOMPARE(result.value("argv").toStringList(), QStringList({f.binary, "two words", "", "quote\"inside", "back\\slash", "$HOME", "`touch sentinel`"}));
        QVERIFY(!QFileInfo::exists(f.directory.path() + "/sentinel"));
    }
void GreeterDataTests::shellSyntaxIsNeverExecuted() {
        Fixture f;
        QString error;
        const QString marker = f.directory.path() + "/should-not-exist";
        const auto result = f.parse(desktop("session \"$(touch " + marker + ")\" \"; reboot\" \"*.desktop\""), &error);
        QVERIFY2(!result.isEmpty(), qPrintable(error));
        QCOMPARE(result.value("argv").toStringList()[1], "$(touch " + marker + ")");
        QVERIFY(!QFileInfo::exists(marker));
    }
void GreeterDataTests::fieldCodesAndOnePassExpansion() {
        Fixture f;
        QString error;
        auto data = desktop("session %c %k %% %i %f %F %u %U %d %D %n %N %v %m", "Name %c");
        data += "Icon=session-icon\n";
        const auto result = f.parse(data, &error);
        QVERIFY2(!result.isEmpty(), qPrintable(error));
        QCOMPARE(result.value("argv").toStringList(), QStringList({f.binary, "Name %c", f.directory.path() + "/sample.desktop", "%", "--icon", "session-icon"}));
    }
void GreeterDataTests::invalidCommands_data() {
        QTest::addColumn<QString>("command");
        QTest::newRow("unclosed") << "session \"unfinished";
        QTest::newRow("unknown-field") << "session %z";
        QTest::newRow("trailing-field") << "session end%";
        QTest::newRow("embedded-file") << "session prefix%F";
        QTest::newRow("assignment") << "BAD=value session";
    }
void GreeterDataTests::invalidCommands() {
        QFETCH(QString, command);
        Fixture f;
        QString error;
        QVERIFY(f.parse(desktop(command), &error).isEmpty());
        QVERIFY(!error.isEmpty());
    }
void GreeterDataTests::filtersAndTryExec() {
        Fixture f;
        QString error;
        for (const auto& field : {"Hidden=true\n", "NoDisplay=true\n", "TryExec=missing-binary\n", "Terminal=true\n"}) {
            QVERIFY(f.parse(desktop("session") + field, &error).isEmpty());
        }
        QVERIFY(!f.parse(desktop("session") + "TryExec=session\n", &error).isEmpty());
        QVERIFY(f.parse(desktop("missing-binary"), &error).isEmpty());
    }
void GreeterDataTests::localeAndGroupIsolation() {
        Fixture f;
        f.input.locale = "ru_RU";
        QString error;
        auto data = desktop("session") + "Name[ru]=Название\nComment[ru]=Описание\n[Desktop Action other]\nName=Wrong\nExec=missing\n";
        const auto result = f.parse(data, &error);
        QCOMPARE(result.value("name").toString(), QString::fromUtf8("Название"));
        QCOMPARE(result.value("comment").toString(), QString::fromUtf8("Описание"));
        QCOMPARE(result.value("argv").toStringList(), QStringList({f.binary}));
    }
void GreeterDataTests::duplicateEntryAndMasking() {
        Fixture f;
        write(f.input.dataDirectories[0] + "/wayland-sessions/shared.desktop", desktop("session") + "Hidden=true\n");
        write(f.input.dataDirectories[1] + "/wayland-sessions/shared.desktop", desktop("session"));
        write(f.input.dataDirectories[1] + "/wayland-sessions/valid.desktop", desktop("session", "Valid"));
        write(f.input.dataDirectories[1] + "/xsessions/valid.desktop", desktop("session", "X11"));
        const auto result = GreeterCatalog::collect(f.input);
        QCOMPARE(result.sessions.size(), 2);
        QCOMPARE(result.sessions[0].toMap().value("id").toString(), "wayland/valid.desktop");
        QCOMPARE(result.sessions[1].toMap().value("type").toString(), "x11");
    }
void GreeterDataTests::malformedAndBoundedFiles() {
        Fixture f;
        QString error;
        QVERIFY(f.parse("[Other]\nName=No\nExec=session\n", &error).isEmpty());
        QVERIFY(!error.isEmpty());
        QVERIFY(f.parse(QByteArray(128 * 1024 + 1, 'x'), &error).isEmpty());
        QVERIFY(f.parse(desktop("session", QString(257, 'x')), &error).isEmpty());
        QVERIFY(f.parse(QByteArray("[Desktop Entry]\0Exec=session", 29), &error).isEmpty());
        write(f.input.dataDirectories[0] + "/wayland-sessions/bad.desktop", "broken");
        write(f.input.dataDirectories[0] + "/wayland-sessions/good.desktop", desktop("session"));
        const auto result = GreeterCatalog::collect(f.input);
        QCOMPARE(result.sessions.size(), 1);
        QVERIFY(!result.errors.isEmpty());
    }
void GreeterDataTests::localUsers() {
        const auto users = GreeterCatalog::parseUsers(
            "root:x:0:0:Root:/root:/bin/sh\n"
            "zeta:x:1001:1001::/home/zeta:/bin/sh\n"
            "alice:x:1000:1000:Alice,Office:/home/alice:/bin/sh\n"
            "alice:x:1002:1002:Duplicate:/home/a:/bin/sh\n"
            "daemon:x:1003:1003:Daemon:/home/d:/usr/bin/nologin\n"
            "disabled:x:1004:1004:Disabled:/home/d:/bin/false\n"
            "invalid:x:NaN:1004:Invalid:/home/d:/bin/sh\n"
            "nobody:x:65534:65534:Nobody:/home/n:/bin/sh\n");
        QCOMPARE(users.size(), 2);
        const auto alice = users[0].toMap();
        QCOMPARE(alice.value("username").toString(), "alice");
        QCOMPARE(alice.value("displayName").toString(), "Alice");
        QVERIFY(!alice.contains("home"));
        QVERIFY(!alice.contains("facePath"));
    }
void GreeterDataTests::asynchronousPublicationAndReload() {
        Fixture f;
        write(f.input.dataDirectories[0] + "/wayland-sessions/test.desktop", desktop("session", "Test"));
        GreeterDataBackend backend(f.input);
        QSignalSpy ready(&backend, &GreeterDataBackend::readyChanged);
        QSignalSpy sessions(&backend, &GreeterDataBackend::sessionsChanged);
        QVERIFY(backend.loading());
        for (int i = 0; i < 20; ++i) backend.reload();
        QTRY_VERIFY(backend.ready());
        QVERIFY(!backend.loading());
        QCOMPARE(ready.count(), 1);
        QCOMPARE(sessions.count(), 1);
        QCOMPARE(backend.sessionIndex("Test"), 0);
        QCOMPARE(backend.sessionIndex("wayland/test.desktop"), 0);
        QCOMPARE(backend.userIndex("alice"), 0);
        QCOMPARE(backend.sessionNames(), QStringList({"Test"}));
        backend.reload();
        QTRY_VERIFY(!backend.loading());
        QCOMPARE(sessions.count(), 1);
        QCOMPARE(ready.count(), 1);
    }
void GreeterDataTests::facadeMayDieWhileWorkerFinishes() {
        Fixture f;
        for (int i = 0; i < 50; ++i) delete new GreeterDataBackend(f.input);
        QVERIFY(QThreadPool::globalInstance()->waitForDone(5000));
    }
QTEST_GUILESS_MAIN(GreeterDataTests)
