#pragma once
#include <QObject>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QHash>
#include <QDBusObjectPath>
#include <QVariantList>
#include <functional>
#include <memory>
#include <QtQml/qqmlregistration.h>

class QDBusPendingCallWatcher;
class QDBusServiceWatcher;

// Read-only NM profile/state snapshots. Actions stay UUID-based in VPNService;
// settings are fetched without GetSecrets and only public metadata reaches QML.
class VpnProfiles : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY changed)
    Q_PROPERTY(QStringList names READ names NOTIFY changed)
    Q_PROPERTY(QStringList activeUuids READ activeUuids NOTIFY changed)
    Q_PROPERTY(QString activeNames READ activeNames NOTIFY changed)
    Q_PROPERTY(QString errorString READ errorString NOTIFY changed)
public:
    explicit VpnProfiles(QObject* parent = nullptr);
    explicit VpnProfiles(QDBusConnection bus, QObject* parent = nullptr);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool ready() const { return m_ready; }
    QVariantList profiles() const { return m_profiles; }
    QStringList names() const { return m_names; }
    QStringList activeUuids() const { return m_activeUuids; }
    QString activeNames() const { return m_activeNames.join(", "); }
    QString errorString() const { return m_error; }
    Q_INVOKABLE QVariantMap profile(const QString& uuid) const;
    Q_INVOKABLE void refresh();
signals:
    void enabledChanged();
    void changed();
private slots:
    void ownerChanged(const QString&, const QString&, const QString& owner);
    void topologyChanged();
    void topologyAdded(const QDBusObjectPath&);
    void activeStateChanged(uint, uint);
    void propertiesChanged(const QString& interface, const QVariantMap& changed, const QStringList& invalidated);
private:
    struct Snapshot;
    void setOwner(const QString& owner);
    void start();
    void readNext(const std::shared_ptr<Snapshot>& snapshot);
    void finish(const std::shared_ptr<Snapshot>& snapshot, const QString& error = {});
    bool current(const std::shared_ptr<Snapshot>& snapshot) const;
    void request(const std::shared_ptr<Snapshot>& snapshot, const QString& path, const QString& interface,
                 const QString& method, const QVariantList& args, std::function<void(const QDBusMessage&)> callback);
    void clear();
    QDBusConnection m_bus;
    QDBusServiceWatcher* m_serviceWatcher;
    QString m_owner, m_error;
    QVariantList m_profiles;
    QStringList m_names, m_activeNames, m_activeUuids;
    QHash<QString, QVariantMap> m_index;
    quint64 m_generation = 0, m_ownerGeneration = 0;
    bool m_ownerResolved = false, m_enabled = false, m_ready = false, m_running = false, m_dirty = false, m_scheduled = false;
};
