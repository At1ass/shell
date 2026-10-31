#pragma once
#include <QObject>
#include <QQmlEngine>
#include <QtDBus/QDBusConnection>
#include <optional>

// Surface-independent ScreenSaver inhibition; active means a confirmed cookie.
class SessionIdleInhibitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool pending READ pending NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString details READ details NOTIFY changed)
   public:
    explicit SessionIdleInhibitor(QObject* parent = nullptr);
    SessionIdleInhibitor(QDBusConnection bus, QObject* parent = nullptr);
    ~SessionIdleInhibitor() override;
    bool enabled() const { return m_enabled; }
    void setEnabled(bool value);
    bool active() const { return m_enabled && m_cookie.has_value(); }
    bool pending() const { return m_enabled && (m_lookupPending || m_pending); }
    bool available() const { return !m_owner.isEmpty(); }
    QString error() const { return m_error; }
    QString details() const { return m_details; }
    Q_INVOKABLE bool retry();
   signals:
    void changed();

   private:
    void lookupOwner();
    void setOwner(QString const& owner);
    void acquire();
    void release();
    QDBusConnection m_bus;
    QString m_owner;
    QString m_cookieOwner;
    std::optional<quint32> m_cookie;
    bool m_enabled = false;
    bool m_pending = false;
    bool m_lookupPending = false;
    quint64 m_generation = 0;
    quint64 m_inflightGeneration = 0;
    quint64 m_ownerEpoch = 0;
    QString m_error;
    QString m_details;
};
