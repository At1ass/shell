#pragma once

// Strong types replacing magic strings ("all"/"this", "daily"/"weekly")
// that previously flowed through the calendar plugin. QML boundary still
// uses QString — conversions live in EventTypes.cpp.

#include <QtCore/QString>
#include <libical/ical.h>

enum class EditScope {
    All,            // edit / delete the whole VEVENT series
    ThisInstance    // edit / delete a single occurrence (RECURRENCE-ID)
};

enum class Recurrence {
    None,
    Daily,
    Weekly,
    Monthly,
    Yearly
};

// Captured from the original VEVENT — used to expand RRULEs in the
// event's authoring zone, which is the only correctness-preserving way
// to compute occurrences for cross-TZ recurring events.
struct EventTimezone {
    QString tzid;            // "Europe/Moscow" if TZID parameter present
    bool    isFloating = false;
    bool    isUtc      = false;
};

// ── Conversions ──────────────────────────────────────────────────────

QString toString(EditScope);
EditScope editScopeFromString(const QString& s);

QString toString(Recurrence);
Recurrence recurrenceFromString(const QString& s);

// libical FREQ ↔ Recurrence
icalrecurrencetype_frequency toIcalFreq(Recurrence);
Recurrence fromIcalFreq(icalrecurrencetype_frequency);
