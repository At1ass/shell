#pragma once

#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QDateTime>
#include <QtCore/QDate>
#include <QtCore/QVariantMap>
#include <QtCore/QVariantList>

#include <libical/ical.h>

#include "EventTypes.h"
#include "IcalRaii.h"

#include <vector>
#include <optional>

// ── Plain event record parsed from a single VEVENT block ──────────────
//
// One Event corresponds to one VEVENT in a .ics file. Recurrence is
// expressed via `recurrence`/`recurrenceUntil` (RRULE master) or via
// `recurrenceId` (overriding instance with RECURRENCE-ID).
//
// Expanded occurrences are produced separately by expandRange() and are
// not represented as Event records (they are emitted directly as
// QVariantMap entries).

struct Event {
    QString uid;
    QString calendar;       // logical name, e.g. "google/main"
    QString sourceFile;     // absolute path to backing .ics file
    QString title;
    QString description;
    QString location;
    QStringList categories;
    QDateTime start;        // converted to local time for display
    QDateTime end;
    bool     allDay = false;
    QString  status;        // "CONFIRMED" | "CANCELLED" | "TENTATIVE"

    // Original DTSTART timezone — required to expand RRULE in the
    // event's authoring zone (so cross-TZ events fire at the right
    // wall-clock time when the viewer is elsewhere).
    EventTimezone timezone;

    // Recurrence (master VEVENT)
    QString    rruleRaw;          // raw RRULE for round-trip
    Recurrence recurrence = Recurrence::None;
    QDate      recurrenceUntil;   // invalid if no UNTIL
    std::vector<QDateTime> exdates;

    // Override (single instance with RECURRENCE-ID)
    QDateTime recurrenceId;       // invalid if not an override

    bool isMaster()   const { return !rruleRaw.isEmpty(); }
    bool isOverride() const { return recurrenceId.isValid(); }

    // Build a QVariantMap for the QML side.
    QVariantMap toVariantMap(const QDateTime& occurrenceStart = QDateTime(),
                             const QDateTime& occurrenceEnd   = QDateTime()) const;
};

namespace IcalParser {

// Parse a single .ics file. Returns master + override VEVENTs (NOT expanded).
std::vector<Event> parseFile(const QString& path, const QString& calendar);

// Parse raw .ics text, return the root VCALENDAR component for in-place editing.
// Caller owns via RAII.
ical::ComponentPtr parseToComponent(const QByteArray& data);

// Serialize a component to .ics text. Returns empty string on failure.
QString serializeComponent(icalcomponent* root);

// Expand recurring masters across [from, to] and overlay RECURRENCE-ID
// overrides (suppressing master at override dates regardless of EXDATE).
QVariantList expandRange(const std::vector<Event>& events,
                         const QDate& from,
                         const QDate& to);

// Build a fresh VCALENDAR + VEVENT serialisation. Used only for NEW
// events and for the override (RECURRENCE-ID) child file. In-place
// edits go through parseToComponent + setters + serializeComponent
// instead of buildIcsString — that path preserves VALARM, X-properties,
// and complex RRULE clauses.
QString buildIcsString(const QVariantMap& fields);

// Resolve TZID name → icaltimezone* (built-in DB or VTIMEZONE in vcalendar).
// Returns UTC zone for empty/floating tzid.
icaltimezone* resolveTimezone(const QString& tzid, icalcomponent* vcalendar = nullptr);

// QDateTime ↔ icaltimetype
QDateTime icalTimeToQDateTime(const icaltimetype& t);
icaltimetype qDateTimeToIcalTime(const QDateTime& dt, bool asDate);

} // namespace IcalParser
