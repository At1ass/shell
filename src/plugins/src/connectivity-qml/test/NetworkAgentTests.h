#pragma once
#include <QObject>
#include <QDBusContext>

class NetworkManagerFixture : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.NetworkManager.AgentManager")
public:
    QString client;
    quint32 capabilities = 0;
    int registrationDelay = 0;
public slots:
    void RegisterWithCapabilities(const QString& identifier, quint32 capabilities);
    void Unregister() { client.clear(); }
};
class NetworkAgentTests : public QObject {
    Q_OBJECT
private slots:
    void requestNewAndStaleTokens();
    void storedAndNotSaved();
    void cancellationAndQueue();
    void lockedAndUntrusted();
    void saveAndDelete();
    void storeFailureAndTimeout();
    void daemonRestart();
    void lateRegistration();
    void destructionDuringJob();
    void credentialShapes();
    void vpnDescriptionProtocol();
    void vpnRequests();
    void installedVpnHelper();
    void nativeKeyringReadOnly();
    void privateKeyringRoundTrip();
};
