#pragma once

#include <QtQml/qqmlregistration.h>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QFutureWatcher>
#include <QObject>
#include <QUrl>
#include <functional>

// Read-only AccountsService metadata shared by the shell and the login screen.
class AccountProfile : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY usernameChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QUrl iconSource READ iconSource NOTIFY changed)
  public:
    explicit AccountProfile(QObject *parent = nullptr);
    explicit AccountProfile(QDBusConnection bus, QStringList iconRoots, QObject *parent = nullptr);
    QString username() const { return m_username; }
    void setUsername(QString const &value);
    bool active() const { return m_active; }
    void setActive(bool value);
    bool ready() const { return m_ready; }
    QString displayName() const { return m_displayName; }
    QUrl iconSource() const { return m_iconSource; }
  signals:
    void usernameChanged();
    void activeChanged();
    void changed();
  private slots:
    void ownerChanged(QString const &, QString const &, QString const &owner);
    void userChanged(QDBusMessage const &message);
    void propertiesChanged(QString const &interface, QVariantMap const &, QStringList const &,
                           QDBusMessage const &message);

  private:
    void clear();
    void invalidate();
    void refresh();
    void start();
    void finish();
    bool current(quint64 generation) const;
    void request(QString const &destination, QString const &path, QString const &interface, QString const &method,
                 QVariantList const &args, std::function<void(QDBusMessage const &)> callback);
    QDBusConnection m_bus;
    QStringList m_iconRoots;
    QString m_username, m_owner, m_userPath, m_displayName, m_nextDisplayName;
    QUrl m_iconSource;
    QFutureWatcher<QString> m_fileWatcher;
    quint64 m_generation = 0, m_fileGeneration = 0, m_revision = 0;
    bool m_active = true, m_ready = false, m_running = false, m_dirty = false, m_scheduled = false;
};
