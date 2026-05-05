#include "ReminderEngine.h"

#include <QtCore/QTimer>
#include <QtCore/QProcess>
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
        if (m.value(QStringLiteral("allDay")).toBool()) continue;
        const QDateTime start = m.value(QStringLiteral("start")).toDateTime();
        if (!start.isValid()) continue;

        // Use UID + ISO start as dedupe key so each occurrence is independent
        const QString key = m.value(QStringLiteral("uid")).toString()
                          + QLatin1Char('|')
                          + start.toString(Qt::ISODate);
        if (m_firedToday.contains(key)) continue;
        if (start <= now || start > windowEnd) continue;

        const QString title = m.value(QStringLiteral("title")).toString();
        const int minutesAway = int(now.secsTo(start) / 60);
        notify(title, start.toString(QStringLiteral("HH:mm")), minutesAway);
        m_firedToday.insert(key);
    }
}

void ReminderEngine::notify(const QString& title, const QString& time, int minutesAway) {
    QStringList args;
    args << QStringLiteral("--urgency=normal")
         << QStringLiteral("--app-name=Calendar")
         << QStringLiteral("--icon=calendar")
         << QStringLiteral("Upcoming: ") + title
         << QStringLiteral("Starting at %1 (in %2 min)").arg(time).arg(minutesAway);
    QProcess::startDetached(QStringLiteral("notify-send"), args);
}
