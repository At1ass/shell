#include "ReminderEngine.h"

#include <QtCore/QTimer>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusPendingCall>
#include <QtCore/QDateTime>
#include <QtCore/QVariantMap>

ReminderEngine::ReminderEngine(QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_windowTimer(new QTimer(this))
{
    m_timer->setInterval(60 * 1000);
    m_timer->setSingleShot(false);
    connect(m_timer, &QTimer::timeout, this, &ReminderEngine::tick);

    // 30-min cadence: nudge the backend to refetch events. The window
    // tick fires immediately on enable so the engine starts populated.
    m_windowTimer->setInterval(30 * 60 * 1000);
    m_windowTimer->setSingleShot(false);
    connect(m_windowTimer, &QTimer::timeout, this, &ReminderEngine::windowRefreshNeeded);

    if (m_enabled) {
        m_timer->start();
        m_windowTimer->start();
    }
}

ReminderEngine::~ReminderEngine() = default;

void ReminderEngine::setEnabled(bool e) {
    if (m_enabled == e) return;
    m_enabled = e;
    if (e) {
        m_timer->start();
        m_windowTimer->start();
        emit windowRefreshNeeded();
    } else {
        m_timer->stop();
        m_windowTimer->stop();
    }
}

void ReminderEngine::setMinutesBefore(int m) {
    m_minutesBefore = m > 0 ? m : 15;
}

void ReminderEngine::setAllDayTime(const QString& hhmm) {
    const QTime t = QTime::fromString(hhmm, QStringLiteral("HH:mm"));
    // Reject garbage rather than silently reminding at midnight.
    m_allDayTime = t.isValid() ? t : QTime(9, 0);
}

void ReminderEngine::setEvents(const QVariantList& events) {
    m_events = events;
    if (m_enabled) tick();   // re-evaluate immediately after refresh
}

void ReminderEngine::tick() {
    if (!m_enabled) return;
    const QDateTime now = QDateTime::currentDateTime();
    const QDate today = now.date();
    if (today != m_lastDate) {
        m_firedToday.clear();
        m_lastDate = today;
    }
    const QDateTime windowEnd = now.addSecs(qint64(m_minutesBefore) * 60);

    for (const auto& v : m_events) {
        const QVariantMap m = v.toMap();
        const QDateTime start = m.value(QStringLiteral("start")).toDateTime();
        if (!start.isValid()) continue;

        // Use UID + ISO start as dedupe key so each occurrence is independent
        const QString key = m.value(QStringLiteral("uid")).toString()
                          + QLatin1Char('|')
                          + start.toString(Qt::ISODate);
        if (m_firedToday.contains(key)) continue;

        const QString title = m.value(QStringLiteral("title")).toString();

        if (m.value(QStringLiteral("allDay")).toBool()) {
            // An all-day event has no start time to count down to, so
            // "N minutes before" is meaningless. Remind once on the day
            // itself, at the configured hour, and only after that hour has
            // passed — never retroactively for a day already gone.
            if (start.date() != today) continue;
            if (now.time() < m_allDayTime) continue;
            notifyAllDay(title);
            m_firedToday.insert(key);
            continue;
        }

        if (start <= now || start > windowEnd) continue;
        const int minutesAway = int(now.secsTo(start) / 60);
        notifyTimed(title, start.toString(QStringLiteral("HH:mm")), minutesAway);
        m_firedToday.insert(key);
    }
}

void ReminderEngine::notifyTimed(const QString& title, const QString& time,
                                int minutesAway) {
    raise_(QStringLiteral("Upcoming: ") + title,
           QStringLiteral("Starting at %1 (in %2 min)").arg(time).arg(minutesAway));
}

void ReminderEngine::notifyAllDay(const QString& title) {
    raise_(QStringLiteral("Today: ") + title, QString());
}

void ReminderEngine::raise_(const QString& summary, const QString& body) {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("/org/freedesktop/Notifications"),
        QStringLiteral("org.freedesktop.Notifications"),
        QStringLiteral("Notify"));
    msg << QStringLiteral("Calendar")          // app_name
        << quint32(0)                          // replaces_id
        << QStringLiteral("calendar")          // app_icon
        << summary
        << body
        << QStringList()                       // actions
        << QVariantMap()                       // hints
        << qint32(-1);                         // expire_timeout: server default
    // Fire-and-forget: a reminder is not worth blocking the tick on, and the
    // server is this same shell.
    QDBusConnection::sessionBus().asyncCall(msg);
}
