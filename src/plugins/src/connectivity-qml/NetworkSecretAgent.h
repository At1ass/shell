#pragma once
#include "CredentialStore.h"
#include <QFutureWatcher>
#include <functional>
#include <QObject>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QPointer>
#include <QTimer>
#include <QDeadlineTimer>
#include <QtQml/qqmlregistration.h>

class QDBusPendingCallWatcher;
class NetworkAgentEndpoint;

// NetworkManager credential agent. Registration and requests are asynchronous;
// only authenticated daemon calls may create a bounded interactive request.
class NetworkSecretAgent : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY controlChanged)
    Q_PROPERTY(bool blocked READ blocked WRITE setBlocked NOTIFY controlChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY requestChanged)
    Q_PROPERTY(QString section READ section NOTIFY requestChanged)
    Q_PROPERTY(bool registered READ registered NOTIFY availabilityChanged)
    Q_PROPERTY(QString requestToken READ requestToken NOTIFY requestChanged)
    Q_PROPERTY(QString connectionName READ connectionName NOTIFY requestChanged)
    Q_PROPERTY(QString validationError READ validationError NOTIFY requestChanged)
    Q_PROPERTY(QVariantList fields READ fields NOTIFY requestChanged)
    Q_PROPERTY(QString message READ message NOTIFY requestChanged)
    Q_PROPERTY(int timeoutMs READ timeoutMs WRITE setTimeoutMs NOTIFY controlChanged)
    Q_PROPERTY(bool requestNew READ requestNew NOTIFY requestChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorOccurred)
public:
    explicit NetworkSecretAgent(QObject* parent = nullptr);
    using Executor = std::function<CredentialStore::Result(const CredentialStore::Job&, const CredentialStore::Cancellation&)>;
    explicit NetworkSecretAgent(QDBusConnection bus, Executor executor = CredentialStore::execute, QObject* parent = nullptr);
    ~NetworkSecretAgent() override;
    bool enabled() const { return m_enabled; }
    bool blocked() const { return m_blocked; }
    bool busy() const { return m_current || !m_queue.isEmpty() || m_jobWatcher; }
    QString section() const;
    bool registered() const { return m_registered; }
    QString requestToken() const { return m_token; }
    QString connectionName() const { return m_name; }
    QString validationError() const { return m_validationError; }
    QVariantList fields() const { return m_fields; }
    QString message() const { return m_message; }
    int timeoutMs() const { return m_timeoutMs; }
    void setTimeoutMs(int value);
    bool requestNew() const { return m_requestNew; }
    QString errorString() const { return m_error; }
    void setEnabled(bool value);
    void setBlocked(bool value);
    Q_INVOKABLE bool submit(const QString& token, const QVariantMap& answers);
    Q_INVOKABLE bool reject(const QString& token);
    Q_INVOKABLE void cancel();
signals:
    void controlChanged();
    void availabilityChanged();
    void requestChanged();
    void errorOccurred(const QString& message);
private slots:
    void ownerChanged(const QString&, const QString&, const QString& owner);
private:
    friend class NetworkAgentEndpoint;
    bool handle(const QDBusMessage& message);
    void queryOwner();
    void updateOwner(const QString& owner);
    void registerAgent();
    void unregisterAgent();
    struct Request;
    using RequestPtr = std::shared_ptr<Request>;
    void clearRequest(bool notify = true);
    void processQueue();
    void describeGet();
    void loadStored();
    void showPrompt();
    void finishGet();
    void finishCurrent(const QString& error = {}, const QString& text = {});
    void startJob(CredentialStore::Job job, const QString& phase);
    void jobFinished(const QString& id, const QString& phase, CredentialStore::Result result);
    void expireRequests();
    void updateDeadline();
    void replyError(const QDBusMessage& message, const QString& kind, const QString& text) const;
    void setError(const QString& text);
    void disposeWatcher(QPointer<QDBusPendingCallWatcher>& watcher);
    QDBusConnection m_bus;
    QString m_connectionId;
    NetworkAgentEndpoint* m_endpoint;
    QPointer<QDBusPendingCallWatcher> m_ownerWatcher, m_registerWatcher;
    QString m_owner;
    QTimer m_deadlineTimer;
    QDeadlineTimer m_deadline;
    quint64 m_epoch = 0;
    bool m_enabled = false, m_blocked = true, m_registered = false, m_exported = false;
    bool m_registerSent = false, m_requestNew = false;
    QString m_token, m_name, m_validationError, m_error, m_message;
    int m_timeoutMs = 120000;
    bool m_destroying = false;
    Executor m_executor;
    QList<RequestPtr> m_queue;
    RequestPtr m_current;
    QPointer<QFutureWatcher<CredentialStore::Result>> m_jobWatcher;
    CredentialStore::Cancellation m_jobCancel;
    QVariantList m_fields;

};
