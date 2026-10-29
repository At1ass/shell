#include "AccountProfile.h"

#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QFileInfo>
#include <QTimer>
#include <QUrlQuery>
#include <QtConcurrent>

namespace {
QString const Service = QStringLiteral("org.freedesktop.Accounts");
QString const Root = QStringLiteral("/org/freedesktop/Accounts");
QString const User = Service + QStringLiteral(".User");
QString const Properties = QStringLiteral("org.freedesktop.DBus.Properties");

QString sharedIcon(QString const &path, QStringList const &roots) {
    if (path.size() > 4096 || !QDir::isAbsolutePath(path))
        return {};
    auto const cleaned = QDir::cleanPath(path);
    // Reject home paths before touching the filesystem, even if IconFile names
    // one. AccountsService SetIconFile normally copies icons into its own
    // store.
    bool allowed = false;
    for (auto const &root : roots)
        allowed |= cleaned.startsWith(root + QLatin1Char('/'));
    if (!allowed)
        return {};
    QFileInfo const info(cleaned);
    auto const canonical = info.canonicalFilePath();
    if (!info.isFile() || !info.isReadable())
        return {};
    for (auto const &root : roots) {
        if (canonical.startsWith(root + QLatin1Char('/')))
            return canonical;
    }
    return {};
}
} // namespace

AccountProfile::AccountProfile(QObject *parent)
    : AccountProfile(QDBusConnection::systemBus(),
                     {QStringLiteral("/var/lib/AccountsService/icons"), QStringLiteral("/usr/share"),
                      QStringLiteral("/usr/local/share")},
                     parent) {}

AccountProfile::AccountProfile(QDBusConnection bus, QStringList iconRoots, QObject *parent)
    : QObject(parent), m_bus(std::move(bus)), m_iconRoots(std::move(iconRoots)), m_fileWatcher(this) {
    auto *watcher = new QDBusServiceWatcher(Service, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &AccountProfile::ownerChanged);
    m_bus.connect(Service, {}, User, QStringLiteral("Changed"), this, SLOT(userChanged(QDBusMessage)));
    m_bus.connect(Service, {}, Properties, QStringLiteral("PropertiesChanged"), this,
                  SLOT(propertiesChanged(QString, QVariantMap, QStringList, QDBusMessage)));
    connect(&m_fileWatcher, &QFutureWatcher<QString>::finished, this, [this] {
        if (current(m_fileGeneration)) {
            auto const path = m_fileWatcher.result();
            QUrl icon;
            if (!path.isEmpty()) {
                icon = QUrl::fromLocalFile(path);
                QUrlQuery query;
                query.addQueryItem(QStringLiteral("revision"), QString::number(++m_revision));
                icon.setQuery(query);
            }
            m_displayName = m_nextDisplayName;
            m_iconSource = icon;
            m_ready = true;
            emit changed();
        }
        finish();
    });
}
void AccountProfile::setUsername(QString const &value) {
    auto const name = value.size() <= 256 && !value.contains(QChar::Null) ? value : QString();
    if (m_username == name)
        return;
    m_username = name;
    invalidate();
    emit usernameChanged();
}
void AccountProfile::setActive(bool value) {
    if (m_active == value)
        return;
    m_active = value;
    invalidate();
    emit activeChanged();
}
void AccountProfile::clear() {
    if (!m_ready && m_displayName.isEmpty() && m_iconSource.isEmpty())
        return;
    m_ready = false;
    m_displayName.clear();
    m_iconSource.clear();
    emit changed();
}
void AccountProfile::invalidate() {
    ++m_generation;
    m_userPath.clear();
    clear();
    refresh();
}
void AccountProfile::ownerChanged(QString const &, QString const &, QString const &owner) {
    m_owner = owner;
    invalidate();
}
void AccountProfile::userChanged(QDBusMessage const &message) {
    if (message.service() == m_owner && message.path() == m_userPath)
        refresh();
}
void AccountProfile::propertiesChanged(QString const &interface, QVariantMap const &, QStringList const &,
                                       QDBusMessage const &message) {
    if (interface == User)
        userChanged(message);
}
bool AccountProfile::current(quint64 generation) const {
    return generation == m_generation && !m_dirty && m_active && !m_username.isEmpty();
}
void AccountProfile::refresh() {
    m_dirty = true;
    if (m_scheduled || m_running)
        return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this] {
        m_scheduled = false;
        start();
    });
}
void AccountProfile::finish() {
    m_running = false;
    if (m_dirty)
        refresh();
}
void AccountProfile::request(QString const &destination, QString const &path, QString const &interface,
                             QString const &method, QVariantList const &args,
                             std::function<void(QDBusMessage const &)> callback) {
    auto message = QDBusMessage::createMethodCall(destination, path, interface, method);
    message.setArguments(args);
    auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 5000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [watcher, callback = std::move(callback)] {
        auto const reply = watcher->reply();
        watcher->deleteLater();
        callback(reply);
    });
}
void AccountProfile::start() {
    if (m_running || !m_active || m_username.isEmpty())
        return;
    m_running = true;
    m_dirty = false;
    auto const generation = m_generation;
    // The well-known destination allows normal D-Bus activation when installed.
    // Resolve the unique owner through the bus before reading user properties.
    request(Service, Root, Service, QStringLiteral("FindUserByName"), {m_username},
            [this, generation](QDBusMessage const &message) {
                QDBusPendingReply<QDBusObjectPath> reply(message);
                if (!current(generation)) {
                    finish();
                    return;
                }
                if (reply.isError() || !reply.value().path().startsWith(Root + QStringLiteral("/User"))) {
                    clear();
                    finish();
                    return;
                }
                m_userPath = reply.value().path();
                request(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
                        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("GetNameOwner"), {Service},
                        [this, generation](QDBusMessage const &ownerMessage) {
                            QDBusPendingReply<QString> ownerReply(ownerMessage);
                            if (!current(generation)) {
                                finish();
                                return;
                            }
                            if (ownerReply.isError() || !ownerReply.value().startsWith(QLatin1Char(':'))) {
                                clear();
                                finish();
                                return;
                            }
                            m_owner = ownerReply.value();
                            request(m_owner, m_userPath, Properties, QStringLiteral("GetAll"), {User},
                                    [this, generation](QDBusMessage const &response) {
                                        QDBusPendingReply<QVariantMap> properties(response);
                                        if (!current(generation)) {
                                            finish();
                                            return;
                                        }
                                        if (properties.isError() ||
                                            properties.value().value(QStringLiteral("UserName")).toString() !=
                                                m_username) {
                                            clear();
                                            finish();
                                            return;
                                        }
                                        auto const data = properties.value();
                                        m_nextDisplayName =
                                            data.value(QStringLiteral("RealName")).toString().left(256).simplified();
                                        auto const path = data.value(QStringLiteral("IconFile")).toString();
                                        m_fileGeneration = generation;
                                        // No facade/application pointers in the worker;
                                        // destroying the profile never waits for filesystem
                                        // work in the UI thread.
                                        m_fileWatcher.setFuture(QtConcurrent::run(
                                            [path, roots = m_iconRoots] { return sharedIcon(path, roots); }));
                                    });
                        });
            });
}
