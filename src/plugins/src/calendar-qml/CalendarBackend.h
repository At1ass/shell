#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QDate>
#include <QtCore/QDateTime>
#include <QtCore/QThread>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtQml/QQmlEngine>

class CalendarStore;
class ReminderEngine;

// QML singleton facade. Owns a worker QThread that hosts CalendarStore
// (where every libical call lives). All commands cross thread via
// QMetaObject::invokeMethod with Qt::QueuedConnection; results return
// via signals connected with Qt::QueuedConnection. The backend itself
// stays on the main thread and exposes cached property views to QML.

class CalendarBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList events       READ events       NOTIFY eventsChanged)
    Q_PROPERTY(QVariantList dayEvents    READ dayEvents    NOTIFY dayEventsChanged)
    Q_PROPERTY(QStringList  calendars    READ calendars    NOTIFY calendarsChanged)
    Q_PROPERTY(QVariantMap  eventsByDate READ eventsByDate NOTIFY eventsByDateChanged)
    Q_PROPERTY(bool         loading      READ loading      NOTIFY loadingChanged)
    Q_PROPERTY(QString      lastError    READ lastError    NOTIFY lastErrorChanged)

    Q_PROPERTY(bool remindersEnabled        READ remindersEnabled        WRITE setRemindersEnabled        NOTIFY remindersEnabledChanged)
    Q_PROPERTY(int  reminderMinutes         READ reminderMinutes         WRITE setReminderMinutes         NOTIFY reminderMinutesChanged)
    Q_PROPERTY(int  reminderLookaheadDays   READ reminderLookaheadDays   WRITE setReminderLookaheadDays   NOTIFY reminderLookaheadDaysChanged)

public:
    explicit CalendarBackend(QObject* parent = nullptr);
    ~CalendarBackend() override;

    QVariantList events()       const { return m_events; }
    QVariantList dayEvents()    const { return m_dayEvents; }
    QStringList  calendars()    const { return m_calendars; }
    QVariantMap  eventsByDate() const { return m_eventsByDate; }
    bool         loading()      const { return m_loading; }
    QString      lastError()    const { return m_lastError; }

    bool remindersEnabled()      const { return m_remindersEnabled; }
    int  reminderMinutes()       const { return m_reminderMinutes; }
    int  reminderLookaheadDays() const { return m_reminderLookaheadDays; }
    void setRemindersEnabled(bool e);
    void setReminderMinutes(int m);
    void setReminderLookaheadDays(int d);

    Q_INVOKABLE void loadEventsForRange(const QDate& start, const QDate& end);
    Q_INVOKABLE void loadEventsForDate(const QDate& date);
    Q_INVOKABLE void addEvent(const QVariantMap& fields);
    // recurrenceId addresses an OVERRIDE (moved occurrence) — pass the
    // value the event map exposes as `recurrenceId` when `isOverride` is
    // true. Without it, uid alone resolves to the master series.
    Q_INVOKABLE void editEvent(const QString& uid, const QVariantMap& fields,
                               const QString& scope = QStringLiteral("all"),
                               const QDateTime& occurrenceStart = QDateTime(),
                               const QDateTime& recurrenceId = QDateTime());
    Q_INVOKABLE void deleteEvent(const QString& uid,
                                 const QString& scope = QStringLiteral("all"),
                                 const QDateTime& occurrenceStart = QDateTime(),
                                 const QDateTime& recurrenceId = QDateTime());
    Q_INVOKABLE void refresh();

signals:
    void eventsChanged();
    void dayEventsChanged();
    void calendarsChanged();
    void eventsByDateChanged();
    void loadingChanged();
    void lastErrorChanged();
    void errorOccurred(QString message);
    void remindersEnabledChanged();
    void reminderMinutesChanged();
    void reminderLookaheadDaysChanged();

private slots:
    void handleStoreRefreshed(QStringList calendars);
    void handleRangeReady(QDate from, QDate to,
                          QVariantList events, QVariantMap eventsByDate);
    void handleDayReady(QDate date, QVariantList dayEvents);
    void handleReminderWindowReady(QVariantList window);
    void handleMutationDone(bool success, QString error);
    void handleReminderWindowRefreshNeeded();

private:
    void requestRefreshAfterStoreUpdate();
    void setLoading(bool v);
    void setLastError(const QString& s);

    QThread         m_workerThread;
    CalendarStore*  m_store    = nullptr;     // owned by worker thread (deleted via deleteLater on thread finish)
    ReminderEngine* m_reminders = nullptr;    // main thread

    QVariantList m_events;
    QVariantList m_dayEvents;
    QStringList  m_calendars;
    QVariantMap  m_eventsByDate;

    QString m_lastError;
    bool    m_loading = false;

    QDate m_rangeStart;
    QDate m_rangeEnd;
    QDate m_selectedDate;

    bool m_remindersEnabled       = true;
    int  m_reminderMinutes        = 15;
    int  m_reminderLookaheadDays  = 2;
};
