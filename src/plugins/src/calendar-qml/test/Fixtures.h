#pragma once

// iCalendar fixture strings used by the unit tests. Kept inline
// (rather than separate .ics files) so changes don't require rebuilding
// the resource file or messing with QRC/install paths.

#include <QtCore/QString>
#include <QtCore/QByteArray>

namespace fixtures {

// Single timed VEVENT, no recurrence, no TZID — naive local time.
inline QByteArray simple() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:simple@test\r\n"
"SUMMARY:Simple event\r\n"
"DESCRIPTION:Hello\r\n"
"LOCATION:Earth\r\n"
"CATEGORIES:work,urgent\r\n"
"DTSTART:20260301T100000Z\r\n"
"DTEND:20260301T110000Z\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// All-day event (VALUE=DATE).
inline QByteArray allday() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:allday@test\r\n"
"SUMMARY:All day\r\n"
"DTSTART;VALUE=DATE:20260315\r\n"
"DTEND;VALUE=DATE:20260316\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// 3-day all-day event (15→18, exclusive end).
inline QByteArray multiday() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:multi@test\r\n"
"SUMMARY:Trip\r\n"
"DTSTART;VALUE=DATE:20260415\r\n"
"DTEND;VALUE=DATE:20260418\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Weekly recurring (UTC), starts 2026-05-04 (Mon) at 09:00 UTC.
inline QByteArray weekly() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:weekly@test\r\n"
"SUMMARY:Weekly meeting\r\n"
"DTSTART:20260504T090000Z\r\n"
"DTEND:20260504T100000Z\r\n"
"RRULE:FREQ=WEEKLY\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Weekly + 1 EXDATE (skip 2026-05-11).
inline QByteArray weeklyExdate() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:weeklyexdate@test\r\n"
"SUMMARY:Weekly with hole\r\n"
"DTSTART:20260504T090000Z\r\n"
"DTEND:20260504T100000Z\r\n"
"RRULE:FREQ=WEEKLY\r\n"
"EXDATE:20260511T090000Z\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Weekly + RECURRENCE-ID override moving 2026-05-11 → 2026-05-12 14:00.
// Notably NO EXDATE — the override must still suppress the master at 05-11.
inline QByteArray weeklyOverrideNoExdate() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:weeklyov@test\r\n"
"SUMMARY:Weekly base\r\n"
"DTSTART:20260504T090000Z\r\n"
"DTEND:20260504T100000Z\r\n"
"RRULE:FREQ=WEEKLY\r\n"
"END:VEVENT\r\n"
"BEGIN:VEVENT\r\n"
"UID:weeklyov@test\r\n"
"RECURRENCE-ID:20260511T090000Z\r\n"
"SUMMARY:Override moved\r\n"
"DTSTART:20260512T140000Z\r\n"
"DTEND:20260512T150000Z\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH — every other Tue/Thu starting
// 2026-06-02 (Tue).
inline QByteArray complexRrule() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:complex@test\r\n"
"SUMMARY:Biweekly TT\r\n"
"DTSTART:20260602T090000Z\r\n"
"DTEND:20260602T100000Z\r\n"
"RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// TZID=America/New_York 09:00 — must surface to viewer in their TZ.
inline QByteArray crossTz() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:tz@test\r\n"
"SUMMARY:NY morning\r\n"
"DTSTART;TZID=America/New_York:20260720T090000\r\n"
"DTEND;TZID=America/New_York:20260720T100000\r\n"
"RRULE:FREQ=WEEKLY\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Yearly all-day event — the birthday shape. A VALUE=DATE is FLOATING: it
// carries no zone, so it must survive expansion unshifted in every timezone.
// Routing it through UTC moved it a day earlier everywhere east of Greenwich.
inline QByteArray yearlyAllDay() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:birthday@test\r\n"
"SUMMARY:Happy birthday!\r\n"
"DTSTART;VALUE=DATE:20241020\r\n"
"DTEND;VALUE=DATE:20241021\r\n"
"RRULE:FREQ=YEARLY\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Long-running DAILY all-day series. The expander's fast-forward is disabled
// for all-day events, so this replays from DTSTART; with a 5000-iteration
// safety cap that silently truncates after ~13.7 years.
inline QByteArray dailyAllDayOld() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:dailyold@test\r\n"
"SUMMARY:Long daily\r\n"
"DTSTART;VALUE=DATE:20050101\r\n"
"DTEND;VALUE=DATE:20050102\r\n"
"RRULE:FREQ=DAILY\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// RFC 5545 §3.6.1: DTEND and DURATION are mutually exclusive alternatives.
// Apple/iCloud and Nextcloud commonly emit DURATION on recurring events.
inline QByteArray timedWithDuration() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:duration@test\r\n"
"SUMMARY:Has duration\r\n"
"DTSTART:20260315T090000Z\r\n"
"DURATION:PT1H30M\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// RFC 5545 §3.6.1: a DATE-valued DTSTART with neither DTEND nor DURATION
// has a duration of ONE DAY.
inline QByteArray allDayNoEnd() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:alldaynoend@test\r\n"
"SUMMARY:Bare all-day\r\n"
"DTSTART;VALUE=DATE:20260315\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Sub-daily frequency. `Recurrence` (the editor's enum) has no HOURLY, so it
// mapped to None and the expander treated the event as non-recurring.
inline QByteArray hourly() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:hourly@test\r\n"
"SUMMARY:Every hour\r\n"
"DTSTART:20260315T000000Z\r\n"
"DTEND:20260315T001500Z\r\n"
"RRULE:FREQ=HOURLY;COUNT=5\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// Unparseable RRULE. The event must still render once rather than vanish.
inline QByteArray brokenRrule() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:broken@test\r\n"
"SUMMARY:Broken rule\r\n"
"DTSTART:20260315T090000Z\r\n"
"DTEND:20260315T100000Z\r\n"
"RRULE:FREQ=NONSENSE;BANANA=7\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// RRULE plus an off-schedule RDATE. RDATE was never read, so the extra
// occurrence silently vanished.
inline QByteArray weeklyWithRdate() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:rdate@test\r\n"
"SUMMARY:Weekly plus one\r\n"
"DTSTART:20260504T090000Z\r\n"
"DTEND:20260504T100000Z\r\n"
"RRULE:FREQ=WEEKLY;COUNT=3\r\n"
"RDATE:20260507T140000Z\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

// RDATE with no RRULE: the series is exactly DTSTART plus the listed dates.
inline QByteArray rdateOnly() {
    return
"BEGIN:VCALENDAR\r\n"
"VERSION:2.0\r\n"
"PRODID:-//test//EN\r\n"
"BEGIN:VEVENT\r\n"
"UID:rdateonly@test\r\n"
"SUMMARY:Listed dates\r\n"
"DTSTART:20260504T090000Z\r\n"
"DTEND:20260504T100000Z\r\n"
"RDATE:20260506T090000Z\r\n"
"RDATE:20260508T090000Z\r\n"
"END:VEVENT\r\n"
"END:VCALENDAR\r\n";
}

} // namespace fixtures
