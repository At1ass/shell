#pragma once
#include <QObject>
#include <QDBusContext>
#include <QDBusObjectPath>
#include <QDBusMessage>

class FakeManager : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.AgentManager1")
public:
    QString path, client, capability;
    int defaults = 0, registrations = 0;
    bool rejectOnce = false, holdRegistration = false;
    QDBusMessage registrationRequest;
public slots:
    void RegisterAgent(const QDBusObjectPath& agent, const QString& caps);
    void UnregisterAgent(const QDBusObjectPath& agent);
    void RequestDefaultAgent(const QDBusObjectPath&) { ++defaults; }
};
class FakeDevice : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Device1")
public:
    int pairs = 0, cancels = 0;
    QDBusMessage pairRequest;
    void finish(bool success);
public slots:
    void Pair();
    void CancelPairing();
};
class BluetoothAgentTests : public QObject {
    Q_OBJECT
private slots:
    void inputAndConfirmation();
    void authorizationAndDisplay();
    void rejectUnsolicited();
    void cancellation();
    void transportCompletion();
    void daemonRestartAndReload();
    void staleRegistrationReply();
    void timedOutTransport();
};
