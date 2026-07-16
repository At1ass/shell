#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QDate>
#include <QtCore/QDateTime>
#include <QtCore/QHash>
#include <QtCore/QSet>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>

#include <vector>

#include "IcalParser.h"
#include "EventTypes.h"

class QFileSystemWatcher;
class QTimer;

// CalendarStore owns the on-disk vdir layout. All public methods are
// **slots** that must be called via QMetaObject::invokeMethod with
// Qt::QueuedConnection — the store lives in the dedicated worker
// QThread that CalendarBackend creates. libical is not thread-safe;
// confining all libical calls to this object's thread guarantees
// serialised access.

class CalendarStore : public QObject {
    Q_OBJECT
public:
    struct CalendarInfo {
        QString name;       // logical, e.g. "google/main"
        QString path;       // absolute filesystem path
    };

    explicit CalendarStore(QObject* parent = nullptr);
    ~CalendarStore() override;

public slots:
    // Re-read khal config + parse every .ics. Emits storeRefreshed().
    void rescanAll();

    // Compute the events (incl. expanded RRULE occurrences) for the
    // given grid range, plus a date→events map. Emits rangeReady.
    void requestRange(QDate from, QDate to);

    // Compute events that overlap a single calendar day. Emits dayReady.
    void requestDay(QDate date);

    // Compute the reminder lookahead window. Emits reminderWindowReady.
    void requestReminderWindow(int days);

    // Mutations. Each emits mutationDone(success, error) and, on
    // success, also storeRefreshed (after the FSW debounce window).
    void addEventCmd(QString calendarName, QVariantMap fields);
    void editEventCmd(QString uid, QVariantMap fields,
                      QString scopeStr, QDateTime occurrenceStart,
                      QDateTime recurrenceId);
    void deleteEventCmd(QString uid, QString scopeStr, QDateTime occurrenceStart,
                        QDateTime recurrenceId);

signals:
    void storeRefreshed(QStringList calendars);
    void rangeReady(QDate from, QDate to,
                    QVariantList events, QVariantMap eventsByDate);
    void dayReady(QDate date, QVariantList dayEvents);
    void reminderWindowReady(QVariantList window);
    void mutationDone(bool success, QString error);

private slots:
    void handleFsEvent(const QString& path);
    void debouncedRescan();

private:
    // Read helpers — synchronous, called only from this thread.
    QStringList calendarNamesInternal() const;
    QVariantList eventsInRange(const QDate& from, const QDate& to) const;
    QVariantList eventsOnDate(const QDate& d) const;
    QVariantMap  eventsByDate(const QDate& from, const QDate& to) const;

    // Find master VEVENT by UID. nullptr if not found.
    const Event* findMaster(const QString& uid) const;

    // Find an override VEVENT by (UID, RECURRENCE-ID). nullptr if not found.
    const Event* findOverride(const QString& uid, const QDateTime& recurrenceId) const;

    QString calendarPath(const QString& name) const;
    QString newIcsPath(const QString& calendarName, const QString& uid) const;

    // Edit "all" branch — load file, mutate VEVENT in place, atomic
    // write. Preserves VALARM, X-properties, complex RRULE clauses.
    bool editAllInPlace(const Event& master, const QVariantMap& fields,
                        QString* errorOut);

    // Edit "this instance" branch — add EXDATE to master, write
    // override file with RECURRENCE-ID. Both atomic.
    bool editSingleOverride(const Event& master, const QVariantMap& fields,
                            const QDateTime& occurrenceStart,
                            QString* errorOut);

    // Delete helpers — return false on error; errorOut populated.
    bool deleteWholeSeries(const Event& master, QString* errorOut);
    bool deleteSingleOccurrence(const Event& master,
                                const QDateTime& occurrenceStart,
                                QString* errorOut);

    // Override primitives: the target VEVENT is addressed by
    // (UID, RECURRENCE-ID) inside the override's own file.
    bool editOverrideInPlace(const Event& override_, const QVariantMap& fields,
                             QString* errorOut);
    bool deleteOverride(const Event& override_, QString* errorOut);

    // Remove every VEVENT of `uid` from `path`; deletes the file when no
    // VEVENT remains. Used for series deletion incl. orphaned overrides.
    bool removeUidFromFile(const QString& path, const QString& uid, QString* errorOut);

    static std::vector<CalendarInfo> discoverCalendars();

    void rebuildWatchPaths();

    // Replace DTSTART/DTEND preserving the event's authoring zone.
    static void setDtInAuthoringZone(icalcomponent* ve, int propKind,
                                     const QDateTime& dt, bool asDate,
                                     const EventTimezone& tz,
                                     icalcomponent* vcal);

    std::vector<CalendarInfo> m_calendars;
    std::vector<Event>        m_events;
    QHash<QString, QString>   m_calendarPaths;

    QFileSystemWatcher* m_watcher = nullptr;
    QTimer*             m_debounce = nullptr;
};
