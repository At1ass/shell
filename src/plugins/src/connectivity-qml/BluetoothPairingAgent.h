#pragma once
#include <QObject>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QPointer>
#include <QTimer>
#include <QDeadlineTimer>
#include <QtQml/qqmlregistration.h>

class QDBusPendingCallWatcher;
class AgentEndpoint;

// Application-scoped BlueZ agent. It never requests default-agent ownership.
class BluetoothPairingAgent : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY controlChanged)
    Q_PROPERTY(bool blocked READ blocked WRITE setBlocked NOTIFY controlChanged)
    Q_PROPERTY(int timeoutMs READ timeoutMs WRITE setTimeoutMs NOTIFY controlChanged)
    Q_PROPERTY(bool registered READ registered NOTIFY availabilityChanged)
    Q_PROPERTY(bool armed READ armed NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(QString operationPath READ operationPath NOTIFY stateChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY stateChanged)
    Q_PROPERTY(QString deviceAddress READ deviceAddress NOTIFY stateChanged)
    Q_PROPERTY(QString requestKind READ requestKind NOTIFY stateChanged)
    Q_PROPERTY(QString requestToken READ requestToken NOTIFY stateChanged)
    Q_PROPERTY(QString code READ code NOTIFY stateChanged)
    Q_PROPERTY(QString serviceUuid READ serviceUuid NOTIFY stateChanged)
    Q_PROPERTY(int entered READ entered NOTIFY stateChanged)
    Q_PROPERTY(QString validationError READ validationError NOTIFY stateChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorOccurred)
public:
    explicit BluetoothPairingAgent(QObject* parent = nullptr);
    explicit BluetoothPairingAgent(QDBusConnection bus, QObject* parent = nullptr);
    ~BluetoothPairingAgent() override;
    bool enabled() const { return m_enabled; }
    bool blocked() const { return m_blocked; }
    int timeoutMs() const { return m_timeoutMs; }
    bool registered() const { return m_registered; }
    bool armed() const { return !m_path.isEmpty(); }
    bool busy() const { return armed() || m_pairWatcher; }
    QString operationPath() const { return m_path; }
    QString deviceName() const { return m_name; }
    QString deviceAddress() const { return m_address; }
    QString requestKind() const { return m_kind; }
    QString requestToken() const { return m_token; }
    QString code() const { return m_code; }
    QString serviceUuid() const { return m_uuid; }
    int entered() const { return m_entered; }
    QString validationError() const { return m_validationError; }
    QString errorString() const { return m_error; }
    QString objectPath() const { return m_objectPath; }
    void setEnabled(bool enabled);
    void setBlocked(bool blocked);
    void setTimeoutMs(int milliseconds);
    Q_INVOKABLE bool arm(const QString& path, const QString& name, const QString& address);
    Q_INVOKABLE bool startPair();
    Q_INVOKABLE void disarm();
    Q_INVOKABLE void abort();
    Q_INVOKABLE void deviceRemoved(const QString& path);
    Q_INVOKABLE bool submit(const QString& token, const QString& value);
    Q_INVOKABLE bool reject(const QString& token);
signals:
    void controlChanged();
    void availabilityChanged();
    void stateChanged();
    void errorOccurred(const QString& message);
    void operationCancelled(const QString& path, const QString& reason);
    void operationFinished(const QString& path, bool success, const QString& error);
private slots:
    void ownerChanged(const QString& service, const QString& oldOwner, const QString& newOwner);
private:
    friend class AgentEndpoint;
    bool handle(const QDBusMessage& message);
    void queryOwner();
    void updateOwner(const QString& owner);
    void registerAgent();
    void unregisterAgent();
    void clearRequest();
    void cancel(const QString& reason, bool cancelTransport = true, bool notify = true);
    void sendNoReply(const QString& owner, const QString& path, const QString& interface,
                     const QString& member, const QVariantList& arguments = {});
    void setError(const QString& message);
    void errorReply(const QDBusMessage& request, const QString& reason) const;
    QDBusConnection m_bus;
    AgentEndpoint* m_endpoint;
    QString m_objectPath;
    QString m_owner;
    QPointer<QDBusPendingCallWatcher> m_ownerWatcher;
    QPointer<QDBusPendingCallWatcher> m_registerWatcher;
    QPointer<QDBusPendingCallWatcher> m_pairWatcher;
    QTimer m_operationTimer;
    QTimer m_retryTimer;
    quint64 m_epoch = 0;
    int m_retries = 0;
    bool m_enabled = false;
    bool m_blocked = true;
    bool m_exported = false;
    bool m_registered = false;
    bool m_registerSent = false;
    int m_timeoutMs = 120000;
    QDeadlineTimer m_deadline;
    bool m_destroying = false;
    QString m_path, m_name, m_address, m_kind, m_token, m_code, m_uuid;
    QString m_error, m_validationError;
    int m_entered = 0;
    bool m_hasReply = false;
    QDBusMessage m_reply;
};
