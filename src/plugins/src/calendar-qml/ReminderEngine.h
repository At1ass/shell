#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtCore/QDate>
#include <QtCore/QVariantList>

class QTimer;

// Polls cached events every 60s and fires `notify-send` for events that
// are within the configured lookahead window. Dedupe via firedToday set
// (cleared on date rollover). Runs entirely in C++ to remove the
// per-minute QML polling and the Object.assign() leak the old service had.

class ReminderEngine : public QObject {
    Q_OBJECT
public:
    explicit ReminderEngine(QObject* parent = nullptr);
    ~ReminderEngine() override;

    void setEnabled(bool e);
    void setMinutesBefore(int m);

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
    void notify(const QString& title, const QString& time, int minutesAway);

    QTimer* m_timer         = nullptr;
    QTimer* m_windowTimer   = nullptr;   // 30-min refresh nudge
    QVariantList m_events;
    QSet<QString> m_firedToday;
    QDate m_lastDate;
    bool  m_enabled = true;
    int   m_minutesBefore = 15;
};
