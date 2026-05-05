// Unit tests for the calendar plugin's pure-C++ layer (IcalParser).
// CalendarStore is excluded — it touches QFileSystemWatcher and disk,
// which would require a temp-dir harness; the parser/expander layer
// is where all the subtle logic lives.

#include <QtTest>
#include <QtCore/QTemporaryFile>
#include <QtCore/QTextStream>
#include <QtCore/QTimeZone>

#include "../IcalParser.h"
#include "../EventTypes.h"
#include "Fixtures.h"

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
        QVERIFY(editScopeFromString(QStringLiteral("all")) == EditScope::All);
        QVERIFY(editScopeFromString(QStringLiteral("this")) == EditScope::ThisInstance);
        QVERIFY(editScopeFromString(QStringLiteral("garbage")) == EditScope::All);
    }

    void recurrenceRoundTrip() {
        QVERIFY(recurrenceFromString(QStringLiteral("daily")) == Recurrence::Daily);
        QVERIFY(recurrenceFromString(QStringLiteral("weekly")) == Recurrence::Weekly);
        QVERIFY(recurrenceFromString(QStringLiteral("monthly")) == Recurrence::Monthly);
        QVERIFY(recurrenceFromString(QStringLiteral("yearly")) == Recurrence::Yearly);
        QVERIFY(recurrenceFromString(QStringLiteral("none")) == Recurrence::None);
        QVERIFY(recurrenceFromString(QStringLiteral("garbage")) == Recurrence::None);
    }
};

QTEST_MAIN(CalendarTests)
#include "CalendarTests.moc"
