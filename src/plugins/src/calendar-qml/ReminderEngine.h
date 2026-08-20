#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtCore/QDate>
#include <QtCore/QTime>
#include <QtCore/QVariantList>

class QTimer;

// Polls cached events every 60s and raises a desktop notification for those
// entering the configured window. Dedupe via firedToday set (cleared on date
// rollover). Runs entirely in C++ to remove the per-minute QML polling and the
// Object.assign() leak the old service had.
//
// TWO kinds of reminder, because they are not the same question:
//   * timed events  — "starts in N minutes", N = minutesBefore
//   * all-day events — "today", raised once at allDayTime on the day itself.
//     These used to be skipped outright, so a birthday could never remind.

class ReminderEngine : public QObject {
    Q_OBJECT
public:
    explicit ReminderEngine(QObject* parent = nullptr);
    ~ReminderEngine() override;

    void setEnabled(bool e);
    void setMinutesBefore(int m);
    void setAllDayTime(const QString& hhmm);

public slots:
    // Provide the latest expanded events list (covering at least the
    // next 24 hours). Called from CalendarBackend on each refresh.
    void setEvents(const QVariantList& events);

signals:
    // Fired periodically (every 30 min) to ask the backend for a fresh
    // events window. Without this, events more than ~48h away never
    // entered the engine if the user kept the shell idle.
    void windowRefreshNeeded();

private slots:
    void tick();

private:
    void notifyTimed(const QString& title, const QString& time, int minutesAway);
    void notifyAllDay(const QString& title);
    // Raises the notification over D-Bus. This used to spawn `notify-send`
    // per reminder; the D-Bus destination is the SAME server either way —
    // this shell's own NotificationService — so DND, history and grouping
    // apply exactly as before, minus a process spawn.
    void raise_(const QString& summary, const QString& body);

    QTimer* m_timer         = nullptr;
    QTimer* m_windowTimer   = nullptr;   // 30-min refresh nudge
    QVariantList m_events;
    QSet<QString> m_firedToday;
    QDate m_lastDate;
    bool  m_enabled = true;
    int   m_minutesBefore = 15;
    QTime m_allDayTime = QTime(9, 0);
};
