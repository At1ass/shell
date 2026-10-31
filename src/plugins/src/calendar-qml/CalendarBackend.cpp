#include "CalendarBackend.h"
#include "CalendarStore.h"
#include "ReminderEngine.h"
#include "../common/WorkerLifetime.h"
#include <QtCore/QUuid>
#include <QtCore/QTimer>

CalendarBackend::CalendarBackend(QObject* parent)
    : QObject(parent)
    , m_store(new CalendarStore)        // no parent — moved to worker thread
    , m_reminders(new ReminderEngine(this))
{
    m_workerThread = WorkerLifetime::create(m_store);
    connect(m_store,&CalendarStore::searchReady,this,[this](const QString& id,const QVariantList& events,bool truncated){
        emit searchFinished(id,events,truncated,{});
    },Qt::QueuedConnection);

    connect(m_store, &CalendarStore::storeRefreshed,
            this,    &CalendarBackend::handleStoreRefreshed,    Qt::QueuedConnection);
    connect(m_store, &CalendarStore::rangeReady,
            this,    &CalendarBackend::handleRangeReady,        Qt::QueuedConnection);
    connect(m_store, &CalendarStore::dayReady,
            this,    &CalendarBackend::handleDayReady,          Qt::QueuedConnection);
    connect(m_store, &CalendarStore::reminderWindowReady,
            this,    &CalendarBackend::handleReminderWindowReady, Qt::QueuedConnection);
    connect(m_store, &CalendarStore::mutationDone,
            this,    &CalendarBackend::handleMutationDone,      Qt::QueuedConnection);

    connect(m_reminders, &ReminderEngine::windowRefreshNeeded,
            this,        &CalendarBackend::handleReminderWindowRefreshNeeded);

    m_workerThread->start();

    setLoading(true);
    QMetaObject::invokeMethod(m_store, "rescanAll", Qt::QueuedConnection);
}

CalendarBackend::~CalendarBackend() {
    WorkerLifetime::retire(m_workerThread);
    m_store = nullptr;
}

QString CalendarBackend::searchEvents(const QString& query,const QDate& from,const QDate& to) {
    const auto id=QUuid::createUuid().toString(QUuid::WithoutBraces);
    if(!from.isValid()||!to.isValid()||from.year()<1||to.year()>9999||from>to||from.daysTo(to)>365||query.size()>512) {
        QTimer::singleShot(0,this,[this,id]{emit searchFinished(id,{},false,QStringLiteral("Search needs a valid range of at most one year."));});
        return id;
    }
    QMetaObject::invokeMethod(m_store,"requestSearch",Qt::QueuedConnection,Q_ARG(QString,id),
        Q_ARG(QString,query),Q_ARG(QDate,from),Q_ARG(QDate,to));
    return id;
}

// ── Setters ───────────────────────────────────────────────────────────

void CalendarBackend::setRemindersEnabled(bool e) {
    if (m_remindersEnabled == e) return;
    m_remindersEnabled = e;
    if (m_reminders) m_reminders->setEnabled(e);
    emit remindersEnabledChanged();
}

void CalendarBackend::setReminderMinutes(int m) {
    if (m_reminderMinutes == m) return;
    m_reminderMinutes = m;
    if (m_reminders) m_reminders->setMinutesBefore(m);
    emit reminderMinutesChanged();
}

void CalendarBackend::setReminderLookaheadDays(int d) {
    if (m_reminderLookaheadDays == d) return;
    m_reminderLookaheadDays = d;
    emit reminderLookaheadDaysChanged();
    // Refresh the window with the new lookahead immediately.
    handleReminderWindowRefreshNeeded();
}

void CalendarBackend::setReminderAllDayTime(const QString& hhmm) {
    if (m_reminderAllDayTime == hhmm) return;
    m_reminderAllDayTime = hhmm;
    emit reminderAllDayTimeChanged();
    if (m_reminders) m_reminders->setAllDayTime(hhmm);
}

// ── QML-invokable ─────────────────────────────────────────────────────

void CalendarBackend::loadEventsForRange(const QDate& start, const QDate& end) {
    m_rangeStart = start;
    m_rangeEnd   = end;
    QMetaObject::invokeMethod(m_store, "requestRange", Qt::QueuedConnection,
                              Q_ARG(QDate, start), Q_ARG(QDate, end));
}

void CalendarBackend::loadEventsForDate(const QDate& date) {
    m_selectedDate = date;
    QMetaObject::invokeMethod(m_store, "requestDay", Qt::QueuedConnection,
                              Q_ARG(QDate, date));
}

QString CalendarBackend::addEvent(const QVariantMap& fields) {
    const auto requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_mutations.enqueue(requestId);
    setLoading(true);
    QString cal = fields.value(QStringLiteral("calendar")).toString();
    if (cal.isEmpty() && !m_calendars.isEmpty()) cal = m_calendars.first();
    QMetaObject::invokeMethod(m_store, "addEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, cal),
                              Q_ARG(QVariantMap, fields));
    return requestId;
}

QString CalendarBackend::editEvent(const QString& uid, const QVariantMap& fields,
                                const QString& scope, const QDateTime& occurrenceStart,
                                const QDateTime& recurrenceId)
{
    const auto requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_mutations.enqueue(requestId);
    setLoading(true);
    QMetaObject::invokeMethod(m_store, "editEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, uid),
                              Q_ARG(QVariantMap, fields),
                              Q_ARG(QString, scope),
                              Q_ARG(QDateTime, occurrenceStart),
                              Q_ARG(QDateTime, recurrenceId));
    return requestId;
}

QString CalendarBackend::deleteEvent(const QString& uid, const QString& scope,
                                  const QDateTime& occurrenceStart,
                                  const QDateTime& recurrenceId)
{
    const auto requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_mutations.enqueue(requestId);
    setLoading(true);
    QMetaObject::invokeMethod(m_store, "deleteEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, uid),
                              Q_ARG(QString, scope),
                              Q_ARG(QDateTime, occurrenceStart),
                              Q_ARG(QDateTime, recurrenceId));
    return requestId;
}

void CalendarBackend::refresh() {
    setLoading(true);
    QMetaObject::invokeMethod(m_store, "rescanAll", Qt::QueuedConnection);
}

// ── Signal handlers (main thread) ─────────────────────────────────────

void CalendarBackend::handleStoreRefreshed(QStringList calendars) {
    if (calendars != m_calendars) {
        m_calendars = std::move(calendars);
        emit calendarsChanged();
    }
    requestRefreshAfterStoreUpdate();
    setLoading(false);
}

void CalendarBackend::handleRangeReady(QDate from, QDate to,
                                       QVariantList events, QVariantMap eventsByDate)
{
    Q_UNUSED(from); Q_UNUSED(to);
    m_events       = std::move(events);
    m_eventsByDate = std::move(eventsByDate);
    emit eventsChanged();
    emit eventsByDateChanged();
}

void CalendarBackend::handleDayReady(QDate date, QVariantList dayEvents) {
    Q_UNUSED(date);
    m_dayEvents = std::move(dayEvents);
    emit dayEventsChanged();
}

void CalendarBackend::handleReminderWindowReady(QVariantList window) {
    if (m_reminders) m_reminders->setEvents(window);
}

void CalendarBackend::handleMutationDone(bool success, QString error) {
    const QString requestId = m_mutations.isEmpty() ? QString() : m_mutations.dequeue();
    setLastError(success ? QString() : error);
    if (!success) emit errorOccurred(error);
    // setLoading(false) happens via storeRefreshed after rescan
    if (!success) setLoading(false);
    emit mutationFinished(requestId, success, error);
}

void CalendarBackend::handleReminderWindowRefreshNeeded() {
    QMetaObject::invokeMethod(m_store, "requestReminderWindow", Qt::QueuedConnection,
                              Q_ARG(int, m_reminderLookaheadDays));
}

// ── Helpers ───────────────────────────────────────────────────────────

void CalendarBackend::requestRefreshAfterStoreUpdate() {
    if (m_rangeStart.isValid() && m_rangeEnd.isValid()) {
        QMetaObject::invokeMethod(m_store, "requestRange", Qt::QueuedConnection,
                                  Q_ARG(QDate, m_rangeStart), Q_ARG(QDate, m_rangeEnd));
    }
    if (m_selectedDate.isValid()) {
        QMetaObject::invokeMethod(m_store, "requestDay", Qt::QueuedConnection,
                                  Q_ARG(QDate, m_selectedDate));
    }
    QMetaObject::invokeMethod(m_store, "requestReminderWindow", Qt::QueuedConnection,
                              Q_ARG(int, m_reminderLookaheadDays));
}

void CalendarBackend::setLoading(bool v) {
    if (m_loading == v) return;
    m_loading = v;
    emit loadingChanged();
}

void CalendarBackend::setLastError(const QString& s) {
    if (m_lastError == s) return;
    m_lastError = s;
    emit lastErrorChanged();
}
