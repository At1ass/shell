#include "CalendarBackend.h"
#include "CalendarStore.h"
#include "ReminderEngine.h"

CalendarBackend::CalendarBackend(QObject* parent)
    : QObject(parent)
    , m_store(new CalendarStore)        // no parent — moved to worker thread
    , m_reminders(new ReminderEngine(this))
{
    m_store->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_store, &QObject::deleteLater);

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

    m_workerThread.start();

    setLoading(true);
    QMetaObject::invokeMethod(m_store, "rescanAll", Qt::QueuedConnection);
}

CalendarBackend::~CalendarBackend() {
    m_workerThread.quit();
    m_workerThread.wait();
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

void CalendarBackend::addEvent(const QVariantMap& fields) {
    setLoading(true);
    QString cal = fields.value(QStringLiteral("calendar")).toString();
    if (cal.isEmpty() && !m_calendars.isEmpty()) cal = m_calendars.first();
    QMetaObject::invokeMethod(m_store, "addEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, cal),
                              Q_ARG(QVariantMap, fields));
}

void CalendarBackend::editEvent(const QString& uid, const QVariantMap& fields,
                                const QString& scope, const QDateTime& occurrenceStart)
{
    setLoading(true);
    QMetaObject::invokeMethod(m_store, "editEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, uid),
                              Q_ARG(QVariantMap, fields),
                              Q_ARG(QString, scope),
                              Q_ARG(QDateTime, occurrenceStart));
}

void CalendarBackend::deleteEvent(const QString& uid, const QString& scope,
                                  const QDateTime& occurrenceStart)
{
    setLoading(true);
    QMetaObject::invokeMethod(m_store, "deleteEventCmd", Qt::QueuedConnection,
                              Q_ARG(QString, uid),
                              Q_ARG(QString, scope),
                              Q_ARG(QDateTime, occurrenceStart));
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
    if (!success) {
        setLastError(error);
        emit errorOccurred(error);
    }
    // setLoading(false) happens via storeRefreshed after rescan
    if (!success) setLoading(false);
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
