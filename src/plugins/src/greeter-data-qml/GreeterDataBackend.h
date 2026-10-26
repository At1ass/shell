#pragma once

#include "Catalog.h"
#include <QObject>
#include <QFutureWatcher>
#include <QtQml/qqmlregistration.h>

class GreeterDataBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(QVariantList users READ users NOTIFY usersChanged)
    Q_PROPERTY(QStringList sessionNames READ sessionNames NOTIFY sessionsChanged)
    Q_PROPERTY(QStringList userNames READ userNames NOTIFY usersChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorOccurred)
public:
    explicit GreeterDataBackend(QObject* parent = nullptr);
    // Also used by native tests with an isolated filesystem and executable path.
    explicit GreeterDataBackend(GreeterCatalog::Input input, QObject* parent = nullptr);
    QVariantList sessions() const { return m_result.sessions; }
    QVariantList users() const { return m_result.users; }
    QStringList sessionNames() const;
    QStringList userNames() const;
    bool loading() const { return m_loading; }
    bool ready() const { return m_ready; }
    QString errorString() const { return m_result.errors.join("; "); }
    Q_INVOKABLE void reload();
    Q_INVOKABLE int sessionIndex(const QString& preferred) const;
    Q_INVOKABLE int userIndex(const QString& username) const;
signals:
    void sessionsChanged();
    void usersChanged();
    void loadingChanged();
    void readyChanged();
    void errorOccurred(const QString& message);
private:
    GreeterCatalog::Input m_input;
    GreeterCatalog::Result m_result;
    QFutureWatcher<GreeterCatalog::Result> m_watcher;
    bool m_loading = false;
    bool m_ready = false;
};
