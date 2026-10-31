#include "SessionIdleInhibitor.h"

#include <QCoreApplication>
#include <QPointer>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusPendingCallWatcher>
#include <QtDBus/QDBusPendingReply>
#include <QtDBus/QDBusServiceWatcher>

namespace {
QString const Service = QStringLiteral("org.freedesktop.ScreenSaver");
QString const Path = QStringLiteral("/org/freedesktop/ScreenSaver");
void releaseCookie(QDBusConnection const& bus, QString const& owner,
                   quint32 cookie) {
    // A unique owner prevents a reused cookie from reaching a restarted daemon.
    if (owner.isEmpty()) return;
    auto message = QDBusMessage::createMethodCall(owner, Path, Service,
                                                  QStringLiteral("UnInhibit"));
    message << cookie;
    bus.asyncCall(message, 3000);
}
}  // namespace
SessionIdleInhibitor::SessionIdleInhibitor(QObject* parent)
    : SessionIdleInhibitor(QDBusConnection::sessionBus(), parent) {}
SessionIdleInhibitor::SessionIdleInhibitor(QDBusConnection bus, QObject* parent)
    : QObject(parent), m_bus(std::move(bus)) {
    auto* watcher = new QDBusServiceWatcher(
        Service, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this,
            [this](QString const&, QString const&, QString const& owner) {
                ++m_ownerEpoch;
                m_lookupPending = false;
                setOwner(owner);
            });
    lookupOwner();
}
SessionIdleInhibitor::~SessionIdleInhibitor() { release(); }
void SessionIdleInhibitor::release() {
    if (m_cookie) releaseCookie(m_bus, m_cookieOwner, *m_cookie);
    m_cookie.reset();
    m_cookieOwner.clear();
}
void SessionIdleInhibitor::setEnabled(bool value) {
    if (value == m_enabled) return;
    m_enabled = value;
    ++m_generation;
    if (!value) {
        release();
        m_error.clear();
        m_details.clear();
    } else if (m_owner.isEmpty())
        lookupOwner();
    else
        acquire();
    emit changed();
}
void SessionIdleInhibitor::lookupOwner() {
    if (m_lookupPending) return;
    m_lookupPending = true;
    auto const epoch = ++m_ownerEpoch;
    auto message = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("/org/freedesktop/DBus"),
        QStringLiteral("org.freedesktop.DBus"), QStringLiteral("GetNameOwner"));
    message << Service;
    auto* watcher =
        new QDBusPendingCallWatcher(m_bus.asyncCall(message, 3000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher, epoch] {
                QDBusPendingReply<QString> const reply = *watcher;
                watcher->deleteLater();
                if (epoch != m_ownerEpoch) return;
                m_lookupPending = false;
                setOwner(reply.isError() ? QString() : reply.value());
            });
    emit changed();
}
void SessionIdleInhibitor::setOwner(QString const& owner) {
    if (m_owner != owner) {
        ++m_generation;
        m_pending = false;
        release();
        m_owner = owner;
    }
    if (m_enabled && owner.isEmpty()) {
        m_error = QStringLiteral(
            "Idle service is unavailable. Start hypridle and retry.");
        m_details = QStringLiteral("org.freedesktop.ScreenSaver has no owner");
    } else if (m_enabled)
        acquire();
    emit changed();
}
void SessionIdleInhibitor::acquire() {
    if (!m_enabled || m_pending || m_cookie || m_owner.isEmpty()) return;
    m_pending = true;
    auto const generation = m_generation;
    m_inflightGeneration = generation;
    auto const owner = m_owner;
    auto const bus = m_bus;
    auto message = QDBusMessage::createMethodCall(owner, Path, Service,
                                                  QStringLiteral("Inhibit"));
    message << QStringLiteral("at1ass-shell") << QStringLiteral("Caffeine");
    // A late successful reply must be released even if its QML owner died.
    // These watchers are app-owned and hold only a weak controller reference.
    QPointer<SessionIdleInhibitor> const self(this);
    auto* watcher = new QDBusPendingCallWatcher(bus.asyncCall(message, 5000),
                                                QCoreApplication::instance());
    connect(
        watcher, &QDBusPendingCallWatcher::finished,
        QCoreApplication::instance(), [self, watcher, generation, owner, bus] {
            QDBusPendingReply<quint32> const reply = *watcher;
            watcher->deleteLater();
            if (!self || !self->m_enabled || self->m_generation != generation ||
                self->m_owner != owner) {
                if (!reply.isError()) releaseCookie(bus, owner, reply.value());
                if (self && self->m_inflightGeneration == generation) {
                    self->m_pending = false;
                    self->acquire();
                    emit self->changed();
                }
                return;
            }
            self->m_pending = false;
            if (reply.isError()) {
                self->m_error = QStringLiteral(
                    "Caffeine could not inhibit automatic idle actions. Retry "
                    "or check the idle service.");
                self->m_details = reply.error().message();
            } else {
                self->m_cookie = reply.value();
                self->m_cookieOwner = owner;
                self->m_error.clear();
                self->m_details.clear();
            }
            emit self->changed();
        });
    emit changed();
}
bool SessionIdleInhibitor::retry() {
    if (!m_enabled || pending() || active()) return false;
    if (m_owner.isEmpty())
        lookupOwner();
    else
        acquire();
    return true;
}
