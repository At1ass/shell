// Unit tests for the calendar plugin's pure-C++ layer (IcalParser).
// CalendarStore is excluded — it touches QFileSystemWatcher and disk,
// which would require a temp-dir harness; the parser/expander layer
// is where all the subtle logic lives.

#include <QtTest>
#include <QtCore/QTemporaryFile>
#include <QtCore/QTextStream>
#include <QtCore/QTimeZone>
#include <QtCore/QRegularExpression>

#include "../IcalParser.h"
#include "../EventTypes.h"
#include "../CalendarStore.h"
#include "Fixtures.h"

#include <QtCore/QTemporaryDir>
#include <QtTest/QSignalSpy>

class CalendarTests : public QObject {
    Q_OBJECT

private:
    // Helper: write fixture text to a temp file, return parsed Events.
    std::vector<Event> parseFixture(const QByteArray& text,
                                    const QString& calendar = QStringLiteral("test")) {
        QTemporaryFile f;
        f.setAutoRemove(true);
        if (!f.open()) return {};
        f.write(text);
        f.flush();
        const QString path = f.fileName();
        f.close();
        return IcalParser::parseFile(path, calendar);
    }

    // Helper: write raw bytes to an exact path.
    void writeFile(const QString& path, const QByteArray& text) {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
        f.write(text);
        f.close();
    }

    // Helper: count occurrences in a date range.
    int countInRange(const std::vector<Event>& events, QDate from, QDate to) {
        return IcalParser::expandRange(events, from, to).size();
    }

private slots:

    // ── IcalParser ─────────────────────────────────────────────────

    void parseSimple() {
        auto events = parseFixture(fixtures::simple());
        QCOMPARE(events.size(), size_t(1));
        const Event& ev = events[0];
        QCOMPARE(ev.uid, QStringLiteral("simple@test"));
        QCOMPARE(ev.title, QStringLiteral("Simple event"));
        QCOMPARE(ev.description, QStringLiteral("Hello"));
        QCOMPARE(ev.location, QStringLiteral("Earth"));
        QCOMPARE(ev.categories.size(), 2);
        QVERIFY(ev.categories.contains(QStringLiteral("work")));
        QVERIFY(ev.categories.contains(QStringLiteral("urgent")));
        QVERIFY(!ev.allDay);
        QVERIFY(ev.recurrence == Recurrence::None);
    }

    void parseAllDay() {
        auto events = parseFixture(fixtures::allday());
        QCOMPARE(events.size(), size_t(1));
        QVERIFY(events[0].allDay);
        QCOMPARE(events[0].start.date(), QDate(2026, 3, 15));
    }

    void parseRecurrenceWeekly() {
        auto events = parseFixture(fixtures::weekly());
        QCOMPARE(events.size(), size_t(1));
        QVERIFY(events[0].recurrence == Recurrence::Weekly);
        QVERIFY(!events[0].rruleRaw.isEmpty());
    }

    void parseRecurrenceComplex() {
        // Complex RRULE survives parse: rruleRaw preserves full clause.
        auto events = parseFixture(fixtures::complexRrule());
        QCOMPARE(events.size(), size_t(1));
        QVERIFY(events[0].recurrence == Recurrence::Weekly);
        QVERIFY(events[0].rruleRaw.contains(QStringLiteral("INTERVAL=2")));
        QVERIFY(events[0].rruleRaw.contains(QStringLiteral("BYDAY=TU,TH")));
    }

    void parseTimezone() {
        auto events = parseFixture(fixtures::crossTz());
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].timezone.tzid, QStringLiteral("America/New_York"));
        QVERIFY(!events[0].timezone.isUtc);
        QVERIFY(!events[0].timezone.isFloating);
    }

    void parseExdate() {
        auto events = parseFixture(fixtures::weeklyExdate());
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].exdates.size(), size_t(1));
    }

    void parseOverride() {
        // Two VEVENTs: master + override
        auto events = parseFixture(fixtures::weeklyOverrideNoExdate());
        QCOMPARE(events.size(), size_t(2));
        bool sawMaster = false, sawOverride = false;
        for (const auto& ev : events) {
            if (ev.isOverride()) sawOverride = true;
            else if (ev.isMaster()) sawMaster = true;
        }
        QVERIFY(sawMaster);
        QVERIFY(sawOverride);
    }

    // ── expandRange ────────────────────────────────────────────────

    void expandWeeklySimple() {
        // Range covers 5 weeks → 5 occurrences
        auto events = parseFixture(fixtures::weekly());
        const int n = countInRange(events, QDate(2026, 5, 4), QDate(2026, 6, 1));
        QCOMPARE(n, 5);
    }

    void expandYearlyAllDayKeepsItsDate() {
        // Reported 2026-08: a birthday authored as 20 Oct showed on 19 Oct.
        // A VALUE=DATE is floating; the expander built its dtstart from
        // ev.start.toUTC(), so in any zone east of Greenwich (MSK = UTC+3)
        // 20 Oct 00:00 became 19 Oct 21:00 UTC and every yearly occurrence
        // landed a day early. Pinned to a positive-offset zone on purpose —
        // in UTC or anywhere west of it the bug is invisible.
        const QTimeZone saved = QTimeZone::systemTimeZone();
        qputenv("TZ", "Europe/Moscow");
        ::tzset();

        auto events = parseFixture(fixtures::yearlyAllDay());
        QCOMPARE(int(events.size()), 1);
        QVERIFY(events[0].allDay);

        const QVariantList list = IcalParser::expandRange(events,
                                                          QDate(2026, 10, 1),
                                                          QDate(2026, 10, 31));
        QCOMPARE(list.size(), 1);
        const QDate got = list[0].toMap()
            .value(QStringLiteral("start")).toDateTime().date();
        QCOMPARE(got, QDate(2026, 10, 20));

        qputenv("TZ", saved.id());
        ::tzset();
    }

    void expandDailyAllDaySurvivesSafetyCap() {
        // A DAILY all-day series that started in 2005 is ~7900 occurrences by
        // 2026 — past the expander's 5000-iteration safety cap. Fast-forward
        // is skipped for all-day events, so the series replays from DTSTART
        // and the cap cuts it off before reaching the requested range.
        auto events = parseFixture(fixtures::dailyAllDayOld());
        QCOMPARE(int(events.size()), 1);
        const int n = countInRange(events, QDate(2026, 10, 1), QDate(2026, 10, 7));
        QCOMPARE(n, 7);
    }

    void allDayEndingAtRangeStartIsNotInRange() {
        // DTEND is EXCLUSIVE. An all-day event on 15 Mar has DTEND 16 Mar and
        // does NOT occur on the 16th, so a query for the 16th must return
        // nothing. Checks the range filter's boundary, independent of any
        // recurrence handling.
        auto events = parseFixture(fixtures::allday());   // 2026-03-15 → 03-16
        QCOMPARE(int(events.size()), 1);
        QCOMPARE(countInRange(events, QDate(2026, 3, 15), QDate(2026, 3, 15)), 1);
        QCOMPARE(countInRange(events, QDate(2026, 3, 16), QDate(2026, 3, 16)), 0);
    }

    void durationPropertyIsHonoured() {
        // DTEND and DURATION are alternatives; only DTEND was ever read, so a
        // DURATION-only event collapsed to zero length (end == start).
        auto events = parseFixture(fixtures::timedWithDuration());
        QCOMPARE(int(events.size()), 1);
        QCOMPARE(events[0].start.secsTo(events[0].end), qint64(90 * 60));
    }

    void allDayWithoutEndLastsOneDay() {
        // RFC 5545: DATE-valued DTSTART with no DTEND/DURATION lasts one day.
        // It used to get end == start, i.e. zero length.
        auto events = parseFixture(fixtures::allDayNoEnd());
        QCOMPARE(int(events.size()), 1);
        QVERIFY(events[0].allDay);
        QCOMPARE(events[0].start.date(), QDate(2026, 3, 15));
        QCOMPARE(events[0].end.date(),   QDate(2026, 3, 16));
        // and it must appear on the 15th, not the 16th
        QCOMPARE(countInRange(events, QDate(2026, 3, 15), QDate(2026, 3, 15)), 1);
        QCOMPARE(countInRange(events, QDate(2026, 3, 16), QDate(2026, 3, 16)), 0);
    }

    void expandSubDailyFrequency() {
        // FREQ=HOURLY;COUNT=5 → 5 occurrences on the same day. The expander
        // gated on `Recurrence` (an editor-facing enum with no HOURLY), so
        // the whole series collapsed to the single master occurrence.
        auto events = parseFixture(fixtures::hourly());
        QCOMPARE(int(events.size()), 1);
        QCOMPARE(countInRange(events, QDate(2026, 3, 15), QDate(2026, 3, 15)), 5);
    }

    void brokenRruleStillShowsOnce() {
        // An RRULE libical cannot parse must degrade to a single event, not
        // make it disappear.
        auto events = parseFixture(fixtures::brokenRrule());
        QCOMPARE(int(events.size()), 1);
        QCOMPARE(countInRange(events, QDate(2026, 3, 15), QDate(2026, 3, 15)), 1);
    }

    void rdateAddsOccurrences() {
        // 3 weekly (May 4, 11, 18) + 1 RDATE (May 7) = 4 in the window.
        auto events = parseFixture(fixtures::weeklyWithRdate());
        QCOMPARE(countInRange(events, QDate(2026, 5, 4), QDate(2026, 5, 20)), 4);
        // and the RDATE one really lands on the 7th
        const QVariantList l = IcalParser::expandRange(events,
                                                       QDate(2026, 5, 7), QDate(2026, 5, 7));
        QCOMPARE(l.size(), 1);
    }

    void rdateWithoutRruleExpands() {
        // DTSTART + 2 RDATEs = 3 occurrences.
        auto events = parseFixture(fixtures::rdateOnly());
        QCOMPARE(countInRange(events, QDate(2026, 5, 4), QDate(2026, 5, 10)), 3);
    }

    void expandWeeklyExdate() {
        // 5-week window, 1 EXDATE → 4 occurrences
        auto events = parseFixture(fixtures::weeklyExdate());
        const int n = countInRange(events, QDate(2026, 5, 4), QDate(2026, 6, 1));
        QCOMPARE(n, 4);
    }

    void expandWeeklyOverrideNoExdate() {
        // Master+override in same UID. Bug #4: override without
        // EXDATE used to leave master visible at original date.
        // Expected: 5 occurrences total (1 moved to 05-12, 4 master at
        // 05-04, 05-18, 05-25, 06-01). Original 05-11 master suppressed.
        auto events = parseFixture(fixtures::weeklyOverrideNoExdate());
        QVariantList list = IcalParser::expandRange(events,
                                                    QDate(2026, 5, 4),
                                                    QDate(2026, 6, 1));
        QCOMPARE(list.size(), 5);
        // Check the moved occurrence is on 05-12, not 05-11.
        bool foundMoved = false;
        bool foundOriginal = false;
        for (const QVariant& v : list) {
            QVariantMap m = v.toMap();
            QDateTime st = m.value(QStringLiteral("start")).toDateTime();
            if (st.date() == QDate(2026, 5, 12)) foundMoved = true;
            if (st.date() == QDate(2026, 5, 11)) foundOriginal = true;
        }
        QVERIFY(foundMoved);
        QVERIFY(!foundOriginal);
    }

    void expandComplexRrule() {
        // FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH starting 06-02 Tue
        // 4 weeks = 2 cycles × 2 days = 4 occurrences (Jun 2,4 / Jun 16,18)
        auto events = parseFixture(fixtures::complexRrule());
        const int n = countInRange(events, QDate(2026, 6, 1), QDate(2026, 6, 28));
        QCOMPARE(n, 4);
    }

    void expandMultiday() {
        // 3-day event, range covers all 3 days → 1 occurrence
        auto events = parseFixture(fixtures::multiday());
        const int n = countInRange(events, QDate(2026, 4, 14), QDate(2026, 4, 19));
        QCOMPARE(n, 1);
    }

    void expandCrossTz() {
        // Master is NY 09:00. In viewer's local TZ, the time should
        // shift by the NY-local offset. The exact local hour depends
        // on the test machine's TZ — we assert the range produces
        // occurrences and the start hour is NOT 09 (unless the test
        // machine is in NY).
        auto events = parseFixture(fixtures::crossTz());
        QVariantList list = IcalParser::expandRange(events,
                                                    QDate(2026, 7, 20),
                                                    QDate(2026, 7, 27));
        QVERIFY(list.size() >= 1);
        // For machine in Europe/Moscow (UTC+3), NY 09:00 EDT (UTC-4)
        // = 13:00 UTC = 16:00 Moscow. Skip strict check if running in NY.
        const QString sysTz = QString::fromUtf8(QTimeZone::systemTimeZoneId());
        if (!sysTz.contains(QStringLiteral("New_York"))) {
            QVariantMap m = list.first().toMap();
            QDateTime st = m.value(QStringLiteral("start")).toDateTime();
            QVERIFY2(st.time().hour() != 9,
                     "Cross-TZ event should not appear at 09:00 in viewer's local TZ");
        }
    }

    // ── buildIcsString round-trip ──────────────────────────────────

    void untilMatchesDtstartValueType() {
        // RFC 5545 §3.3.10: "If the value specified by UNTIL is synchronized
        // with the specified recurrence, this DATE or DATE-TIME becomes the
        // last instance of the recurrence" — and the value type MUST match
        // DTSTART's. A timed event was written with a DATE-valued UNTIL,
        // which is a spec violation other clients may reject.
        QVariantMap timed;
        timed.insert(QStringLiteral("title"), QStringLiteral("Timed series"));
        timed.insert(QStringLiteral("start"), QDateTime(QDate(2026, 8, 1), QTime(10, 0)));
        timed.insert(QStringLiteral("end"),   QDateTime(QDate(2026, 8, 1), QTime(11, 0)));
        timed.insert(QStringLiteral("allDay"), false);
        timed.insert(QStringLiteral("recurrence"), QStringLiteral("weekly"));
        timed.insert(QStringLiteral("recurrenceUntil"), QDate(2026, 9, 1));
        const QString t = IcalParser::buildIcsString(timed);
        QVERIFY(t.contains(QStringLiteral("RRULE")));
        // DATE-TIME in UTC → has a T and a trailing Z inside the UNTIL token.
        QVERIFY2(t.contains(QRegularExpression(
            QStringLiteral("UNTIL=[0-9]{8}T[0-9]{6}Z"))),
            qPrintable(QStringLiteral("timed UNTIL is not a UTC DATE-TIME: ") + t));

        // An all-day series keeps a DATE-valued UNTIL.
        QVariantMap allday = timed;
        allday.insert(QStringLiteral("allDay"), true);
        const QString a = IcalParser::buildIcsString(allday);
        QVERIFY2(a.contains(QRegularExpression(
            QStringLiteral("UNTIL=[0-9]{8}(;|$|\\r)"))),
            qPrintable(QStringLiteral("all-day UNTIL is not a DATE: ") + a));
    }

    void roundTripSimple() {
        QVariantMap fields;
        fields.insert(QStringLiteral("title"), QStringLiteral("RT title"));
        fields.insert(QStringLiteral("description"), QStringLiteral("RT desc"));
        fields.insert(QStringLiteral("location"), QStringLiteral("RT loc"));
        fields.insert(QStringLiteral("start"), QDateTime(QDate(2026, 8, 1), QTime(10, 0)));
        fields.insert(QStringLiteral("end"),   QDateTime(QDate(2026, 8, 1), QTime(11, 0)));
        fields.insert(QStringLiteral("allDay"), false);
        fields.insert(QStringLiteral("recurrence"), QStringLiteral("none"));

        const QString text = IcalParser::buildIcsString(fields);
        QVERIFY(!text.isEmpty());

        // Persist to temp + parse back
        QTemporaryFile f; f.setAutoRemove(true);
        QVERIFY(f.open());
        f.write(text.toUtf8());
        f.flush();
        const QString path = f.fileName();
        f.close();

        auto events = IcalParser::parseFile(path, QStringLiteral("rt"));
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].title, QStringLiteral("RT title"));
        QCOMPARE(events[0].description, QStringLiteral("RT desc"));
        QCOMPARE(events[0].location, QStringLiteral("RT loc"));
    }

    void roundTripWeekly() {
        QVariantMap fields;
        fields.insert(QStringLiteral("title"), QStringLiteral("Weekly RT"));
        fields.insert(QStringLiteral("start"), QDateTime(QDate(2026, 8, 1), QTime(10, 0)));
        fields.insert(QStringLiteral("end"),   QDateTime(QDate(2026, 8, 1), QTime(11, 0)));
        fields.insert(QStringLiteral("allDay"), false);
        fields.insert(QStringLiteral("recurrence"), QStringLiteral("weekly"));
        fields.insert(QStringLiteral("recurrenceUntil"), QDate(2026, 12, 31));

        const QString text = IcalParser::buildIcsString(fields);
        QVERIFY(text.contains(QStringLiteral("FREQ=WEEKLY")));
        QVERIFY(text.contains(QStringLiteral("UNTIL=")));

        QTemporaryFile f; f.setAutoRemove(true);
        QVERIFY(f.open());
        f.write(text.toUtf8());
        f.flush();
        const QString path = f.fileName();
        f.close();

        auto events = IcalParser::parseFile(path, QStringLiteral("rt"));
        QCOMPARE(events.size(), size_t(1));
        QVERIFY(events[0].recurrence == Recurrence::Weekly);
        QCOMPARE(events[0].recurrenceUntil, QDate(2026, 12, 31));
    }

    // ── Strong-type round-trip ─────────────────────────────────────

    void editScopeRoundTrip() {
        QCOMPARE(toString(EditScope::All), QStringLiteral("all"));
        QCOMPARE(toString(EditScope::ThisInstance), QStringLiteral("this"));

        EditScope sc = EditScope::ThisInstance;
        QVERIFY(editScopeFromString(QStringLiteral("all"), &sc));
        QVERIFY(sc == EditScope::All);
        QVERIFY(editScopeFromString(QStringLiteral("this"), &sc));
        QVERIFY(sc == EditScope::ThisInstance);

        // Unrecognised input must be REFUSED. This assertion used to say the
        // opposite — "garbage" mapped to EditScope::All — so a typo or a stale
        // caller would have wiped a whole series, and the test blessed it.
        QVERIFY(!editScopeFromString(QStringLiteral("garbage"), &sc));
        QVERIFY(!editScopeFromString(QString(), &sc));
    }

    void recurrenceRoundTrip() {
        QVERIFY(recurrenceFromString(QStringLiteral("daily")) == Recurrence::Daily);
        QVERIFY(recurrenceFromString(QStringLiteral("weekly")) == Recurrence::Weekly);
        QVERIFY(recurrenceFromString(QStringLiteral("monthly")) == Recurrence::Monthly);
        QVERIFY(recurrenceFromString(QStringLiteral("yearly")) == Recurrence::Yearly);
        QVERIFY(recurrenceFromString(QStringLiteral("none")) == Recurrence::None);
        QVERIFY(recurrenceFromString(QStringLiteral("garbage")) == Recurrence::None);
    }

    // ── Floating time (no TZID, no Z) ──────────────────────────────

    void floatingTimeIsLocalWallClock() {
        // RFC 5545 floating time = wall clock in the viewer's zone. It was
        // previously read as UTC, shifting display by the local UTC offset.
        const QByteArray ics =
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:floating@test\r\n"
            "DTSTART:20260301T090000\r\n"
            "DTEND:20260301T100000\r\n"
            "SUMMARY:Floating\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        auto events = parseFixture(ics);
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].start.time(), QTime(9, 0));
        QCOMPARE(events[0].start.date(), QDate(2026, 3, 1));
        QVERIFY(events[0].timezone.isFloating);
    }

    // ── Override identity exposure ─────────────────────────────────

    void overrideIdentityExposed() {
        const QByteArray ics =
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series@test\r\n"
            "RECURRENCE-ID:20260504T090000Z\r\n"
            "DTSTART:20260504T140000Z\r\n"
            "DTEND:20260504T150000Z\r\n"
            "SUMMARY:Moved instance\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        auto events = parseFixture(ics);
        QCOMPARE(events.size(), size_t(1));
        QVERIFY(events[0].isOverride());
        const QVariantMap m = events[0].toVariantMap();
        QVERIFY(m.value(QStringLiteral("isOverride")).toBool());
        QVERIFY(m.value(QStringLiteral("recurrenceId")).toDateTime().isValid());
    }

    // ── Iterator fast-forward for old series ───────────────────────

    void oldDailySeriesStillExpands() {
        // A daily series started in 2010 needs ~5800 iterations to reach
        // 2026 — beyond the old 5000-iteration cap, so it silently
        // disappeared. set_start fast-forwards past the gap.
        const QByteArray ics =
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:old-daily@test\r\n"
            "DTSTART:20100104T090000Z\r\n"
            "DTEND:20100104T093000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Ancient standup\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        auto events = parseFixture(ics);
        QCOMPARE(events.size(), size_t(1));
        const int n = countInRange(events, QDate(2026, 6, 1), QDate(2026, 6, 7));
        QCOMPARE(n, 7);
    }

    // ── Store-level override flows (the data-loss regression) ──────

    void storeOverrideDeleteKeepsSeries() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString calDir = tmp.path() + QStringLiteral("/cal1");

        const QString masterPath = calDir + QStringLiteral("/series.ics");
        const QString overridePath = calDir + QStringLiteral("/series-override.ics");
        writeFile(masterPath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Series\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");
        writeFile(overridePath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series@test\r\n"
            "RECURRENCE-ID:20260505T090000Z\r\n"
            "DTSTART:20260505T140000Z\r\n"
            "DTEND:20260505T150000Z\r\n"
            "SUMMARY:Moved\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();

        // Delete the MOVED occurrence, addressed by (uid, recurrenceId).
        const QDateTime rid = QDateTime::fromString(
            QStringLiteral("2026-05-05T09:00:00Z"), Qt::ISODate);
        store.deleteEventCmd(QStringLiteral("series@test"),
                             QStringLiteral("this"),
                             QDateTime(), rid);
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(),
                 qPrintable(done.at(0).at(1).toString()));

        // The series master MUST survive; the override file must be gone.
        QVERIFY(QFile::exists(masterPath));
        QVERIFY(!QFile::exists(overridePath));

        // The master gained an EXDATE at the ORIGINAL slot, so neither the
        // moved nor the original occurrence renders on that day.
        auto events = IcalParser::parseFile(masterPath, QStringLiteral("cal1"));
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].exdates.size(), size_t(1));
        const auto day = IcalParser::expandRange(events, QDate(2026, 5, 5), QDate(2026, 5, 5));
        QCOMPARE(day.size(), 0);
        // ...while the rest of the series is intact.
        const auto week = IcalParser::expandRange(events, QDate(2026, 5, 4), QDate(2026, 5, 10));
        QCOMPARE(week.size(), 6);
    }

    void storeSeriesDeleteRemovesOrphanOverrides() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString calDir = tmp.path() + QStringLiteral("/cal1");

        const QString masterPath = calDir + QStringLiteral("/series.ics");
        const QString overridePath = calDir + QStringLiteral("/series-override.ics");
        writeFile(masterPath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series2@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Series\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");
        writeFile(overridePath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series2@test\r\n"
            "RECURRENCE-ID:20260505T090000Z\r\n"
            "DTSTART:20260505T140000Z\r\n"
            "DTEND:20260505T150000Z\r\n"
            "SUMMARY:Moved\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();
        store.deleteEventCmd(QStringLiteral("series2@test"),
                             QStringLiteral("all"),
                             QDateTime(), QDateTime());
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(),
                 qPrintable(done.at(0).at(1).toString()));
        // No orphan override may survive the series deletion.
        QVERIFY(!QFile::exists(masterPath));
        QVERIFY(!QFile::exists(overridePath));
    }

    void storeOverrideEditTouchesOnlyOverride() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString calDir = tmp.path() + QStringLiteral("/cal1");

        const QString masterPath = calDir + QStringLiteral("/series.ics");
        const QString overridePath = calDir + QStringLiteral("/series-override.ics");
        writeFile(masterPath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series3@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Series\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");
        writeFile(overridePath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:series3@test\r\n"
            "RECURRENCE-ID:20260505T090000Z\r\n"
            "DTSTART:20260505T140000Z\r\n"
            "DTEND:20260505T150000Z\r\n"
            "SUMMARY:Moved\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();

        QVariantMap fields;
        fields.insert(QStringLiteral("title"), QStringLiteral("Renamed instance"));
        const QDateTime rid = QDateTime::fromString(
            QStringLiteral("2026-05-05T09:00:00Z"), Qt::ISODate);
        store.editEventCmd(QStringLiteral("series3@test"), fields,
                           QStringLiteral("all"), QDateTime(), rid);
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(),
                 qPrintable(done.at(0).at(1).toString()));

        auto master = IcalParser::parseFile(masterPath, QStringLiteral("cal1"));
        QCOMPARE(master.size(), size_t(1));
        QCOMPARE(master[0].title, QStringLiteral("Series"));   // untouched

        auto override_ = IcalParser::parseFile(overridePath, QStringLiteral("cal1"));
        QCOMPARE(override_.size(), size_t(1));
        QCOMPARE(override_[0].title, QStringLiteral("Renamed instance"));
        QVERIFY(override_[0].isOverride());
    }

    void storeDeleteFutureTruncatesSeries() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString path = tmp.path() + QStringLiteral("/cal1/series.ics");
        writeFile(path,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:future@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Daily\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();

        // Cut from May 7 onwards: May 4-6 survive, May 7+ do not.
        const QDateTime cut =
            QDateTime::fromString(QStringLiteral("2026-05-07T09:00:00Z"), Qt::ISODate);
        store.deleteEventCmd(QStringLiteral("future@test"), QStringLiteral("future"),
                             cut, QDateTime());
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(), qPrintable(done.at(0).at(1).toString()));

        auto events = IcalParser::parseFile(path, QStringLiteral("cal1"));
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(IcalParser::expandRange(events, QDate(2026, 5, 4), QDate(2026, 5, 6)).size(), 3);
        QCOMPARE(IcalParser::expandRange(events, QDate(2026, 5, 7), QDate(2026, 5, 20)).size(), 0);
    }

    void storeEditFutureSplitsSeries() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString path = tmp.path() + QStringLiteral("/cal1/series.ics");
        writeFile(path,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:split@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Before\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();

        const QDateTime cut =
            QDateTime::fromString(QStringLiteral("2026-05-07T09:00:00Z"), Qt::ISODate);
        QVariantMap fields;
        fields.insert(QStringLiteral("title"), QStringLiteral("After"));
        fields.insert(QStringLiteral("calendar"), QStringLiteral("cal1"));
        store.editEventCmd(QStringLiteral("split@test"), fields,
                           QStringLiteral("future"), cut, QDateTime());
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(), qPrintable(done.at(0).at(1).toString()));

        // Head keeps the old name and stops before the cut.
        auto head = IcalParser::parseFile(path, QStringLiteral("cal1"));
        QCOMPARE(head.size(), size_t(1));
        QCOMPARE(head[0].title, QStringLiteral("Before"));
        QCOMPARE(IcalParser::expandRange(head, QDate(2026, 5, 4), QDate(2026, 5, 6)).size(), 3);
        QCOMPARE(IcalParser::expandRange(head, QDate(2026, 5, 7), QDate(2026, 5, 20)).size(), 0);

        // Tail is a NEW file carrying the edit, starting at the cut.
        std::vector<Event> tail;
        const auto files = QDir(tmp.path() + QStringLiteral("/cal1"))
                               .entryInfoList(QStringList{ QStringLiteral("*.ics") }, QDir::Files);
        for (const QFileInfo& fi : files) {
            if (fi.absoluteFilePath() == path) continue;
            auto p = IcalParser::parseFile(fi.absoluteFilePath(), QStringLiteral("cal1"));
            tail.insert(tail.end(), p.begin(), p.end());
        }
        QCOMPARE(tail.size(), size_t(1));
        QCOMPARE(tail[0].title, QStringLiteral("After"));
        QVERIFY(tail[0].uid != QStringLiteral("split@test"));
        QCOMPARE(tail[0].start.toUTC(), cut);
        QVERIFY(IcalParser::expandRange(tail, QDate(2026, 5, 7), QDate(2026, 5, 9)).size() == 3);
    }

    void storeSeriesEditKeepsAnchorDate() {
        QTemporaryDir tmp;
        QVERIFY(tmp.isValid());
        QDir(tmp.path()).mkpath(QStringLiteral("cal1"));
        const QString masterPath = tmp.path() + QStringLiteral("/cal1/series.ics");
        writeFile(masterPath,
            "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n"
            "UID:anchor@test\r\n"
            "DTSTART:20260504T090000Z\r\n"
            "DTEND:20260504T100000Z\r\n"
            "RRULE:FREQ=DAILY\r\n"
            "SUMMARY:Series\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n");

        qputenv("CALENDAR_QML_TEST_ROOT", tmp.path().toUtf8());
        CalendarStore store;
        QSignalSpy done(&store, &CalendarStore::mutationDone);
        store.rescanAll();

        // Editing FROM the May 6 occurrence: the dialog composes start/end
        // on that occurrence's date. The series anchor must not move.
        QVariantMap fields;
        fields.insert(QStringLiteral("title"), QStringLiteral("Renamed"));
        fields.insert(QStringLiteral("start"),
                      QDateTime::fromString(QStringLiteral("2026-05-06T10:30:00Z"), Qt::ISODate));
        fields.insert(QStringLiteral("end"),
                      QDateTime::fromString(QStringLiteral("2026-05-06T11:30:00Z"), Qt::ISODate));
        store.editEventCmd(QStringLiteral("anchor@test"), fields,
                           QStringLiteral("all"), QDateTime(), QDateTime());
        qunsetenv("CALENDAR_QML_TEST_ROOT");

        QCOMPARE(done.count(), 1);
        QVERIFY2(done.at(0).at(0).toBool(), qPrintable(done.at(0).at(1).toString()));

        auto events = IcalParser::parseFile(masterPath, QStringLiteral("cal1"));
        QCOMPARE(events.size(), size_t(1));
        QCOMPARE(events[0].title, QStringLiteral("Renamed"));
        // Anchor date preserved; only time-of-day and duration moved.
        QCOMPARE(events[0].start.toUTC().date(), QDate(2026, 5, 4));
        QCOMPARE(events[0].start.toUTC().time(), QTime(10, 30));
        QCOMPARE(events[0].start.secsTo(events[0].end), qint64(3600));
        // Occurrences before the viewed one still exist.
        const auto early = IcalParser::expandRange(events, QDate(2026, 5, 4), QDate(2026, 5, 5));
        QCOMPARE(early.size(), 2);
    }
};

QTEST_MAIN(CalendarTests)
#include "CalendarTests.moc"
