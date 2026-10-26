#pragma once
#include <QObject>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QPointer>
#include <QStringList>
#include <functional>
#include <memory>
#include <QtQml/qqmlregistration.h>

class QDBusPendingCallWatcher;
class QDBusServiceWatcher;

// Read-only, single-flight NetworkManager IP configuration. Neither link state
// nor internet reachability is inferred from the presence of an IPv4 address.
class NetworkInterfaceInfo : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString interfaceName READ interfaceName WRITE setInterfaceName NOTIFY interfaceNameChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(QStringList ipv4Addresses READ ipv4Addresses NOTIFY changed)
    Q_PROPERTY(QStringList ipv6Addresses READ ipv6Addresses NOTIFY changed)
    Q_PROPERTY(QString ipv4Gateway READ ipv4Gateway NOTIFY changed)
    Q_PROPERTY(QString ipv6Gateway READ ipv6Gateway NOTIFY changed)
public:
    explicit NetworkInterfaceInfo(QObject* parent = nullptr);
    explicit NetworkInterfaceInfo(QDBusConnection bus, QObject* parent = nullptr);
    QString interfaceName() const { return m_interface; }
    void setInterfaceName(const QString& value);
    bool ready() const { return m_ready; }
    QStringList ipv4Addresses() const { return m_ipv4; }
    QStringList ipv6Addresses() const { return m_ipv6; }
    QString ipv4Gateway() const { return m_gateway4; }
    QString ipv6Gateway() const { return m_gateway6; }
    Q_INVOKABLE void refresh();
signals:
    void interfaceNameChanged();
    void changed();
private slots:
    void ownerChanged(const QString&, const QString&, const QString& owner);
    void propertiesChanged(const QString& interface, const QVariantMap&, const QStringList&, const QDBusMessage& message);
private:
    struct Snapshot;
    void setOwner(const QString& owner);
    void clear();
    void start();
    void finish(const std::shared_ptr<Snapshot>& snapshot);
    bool current(const std::shared_ptr<Snapshot>& snapshot) const;
    void readDevice(const std::shared_ptr<Snapshot>& snapshot);
    void readFamily(const std::shared_ptr<Snapshot>& snapshot, bool ipv6);
    void request(const QString& path, const QString& interface, const QString& method,
                 const QVariantList& args, std::function<void(const QDBusMessage&)> callback);
    QDBusConnection m_bus;
    QDBusServiceWatcher* m_serviceWatcher;
    QPointer<QDBusPendingCallWatcher> m_watcher;
    QString m_interface, m_owner, m_devicePath, m_ip4Path, m_ip6Path;
    QStringList m_ipv4, m_ipv6;
    QString m_gateway4, m_gateway6;
    quint64 m_generation = 0, m_ownerGeneration = 0;
    bool m_ready = false, m_running = false, m_dirty = false, m_scheduled = false;
};
