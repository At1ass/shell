#include "IcalParser.h"

#include <QtCore/QFile>
#include <QtCore/QTimeZone>
#include <QtCore/QUuid>
#include <QtCore/QSet>

#include <libical/ical.h>

namespace {

QString cstr(const char* s) {
    return s ? QString::fromUtf8(s) : QString();
}

// Convert an icaltimetype to a local QDateTime suitable for display.
// All-day (is_date == 1) becomes a date-only QDateTime in local zone.
QDateTime convertWithZone(const icaltimetype& t) {
    if (icaltime_is_null_time(t)) return QDateTime();

    if (t.is_date) {
        return QDateTime(QDate(t.year, t.month, t.day),
                         QTime(0, 0), QTimeZone::LocalTime);
    }

    // Floating time (no zone, no Z): RFC 5545 wall-clock in whatever zone
    // the viewer is in. Passing zone=nullptr to icaltime_as_timet_with_zone
    // would read it as UTC and shift display by the local UTC offset.
    if (!t.zone && !icaltime_is_utc(t)) {
        return QDateTime(QDate(t.year, t.month, t.day),
                         QTime(t.hour, t.minute, t.second),
                         QTimeZone::LocalTime);
    }

    icaltimetype copy = t;
    time_t epoch = icaltime_as_timet_with_zone(copy, copy.zone);
    if (epoch == 0 && (t.year < 1970 || t.year > 2100)) {
        // sanity fallback for invalid years
        return QDateTime(QDate(t.year, t.month, t.day),
                         QTime(t.hour, t.minute, t.second),
                         QTimeZone::LocalTime);
    }
    return QDateTime::fromSecsSinceEpoch(epoch, QTimeZone::LocalTime);
}

// Resolve TZID parameter on a property and apply zone to icaltime.
void resolvePropertyZone(icalproperty* prop, icaltimetype& t, icalcomponent* vcalendar) {
    if (t.is_date || icaltime_is_utc(t)) return;
    icalparameter* tzidParam = icalproperty_get_first_parameter(prop, ICAL_TZID_PARAMETER);
    if (!tzidParam) return;
    const char* tzid = icalparameter_get_tzid(tzidParam);
    if (!tzid) return;

    icaltimezone* tz = vcalendar
        ? icalcomponent_get_timezone(vcalendar, tzid)
        : nullptr;
    if (!tz) tz = icaltimezone_get_builtin_timezone(tzid);
    if (tz) t.zone = tz;
}

QString statusToString(icalproperty_status st) {
    switch (st) {
        case ICAL_STATUS_CONFIRMED: return QStringLiteral("CONFIRMED");
        case ICAL_STATUS_TENTATIVE: return QStringLiteral("TENTATIVE");
        case ICAL_STATUS_CANCELLED: return QStringLiteral("CANCELLED");
        default: return QString();
    }
}

// RDATE mirrors EXDATE. PERIOD-valued RDATEs (start/duration pairs) are not
// supported — libical exposes them through a different accessor and no server
// in use here emits them; they are skipped rather than mis-read.
void parseRdates(icalcomponent* vevent, std::vector<QDateTime>& out) {
    icalcomponent* vcal = icalcomponent_get_parent(vevent);
    for (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_RDATE_PROPERTY);
         p != nullptr;
         p = icalcomponent_get_next_property(vevent, ICAL_RDATE_PROPERTY)) {
        struct icaldatetimeperiodtype dp = icalproperty_get_rdate(p);
        if (!icaltime_is_null_time(dp.time)) {
            icaltimetype t = dp.time;
            resolvePropertyZone(p, t, vcal);
            QDateTime dt = convertWithZone(t);
            if (dt.isValid()) out.push_back(dt);
        }
    }
}

void parseExdates(icalcomponent* vevent, std::vector<QDateTime>& out) {
    icalcomponent* vcal = icalcomponent_get_parent(vevent);
    for (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_EXDATE_PROPERTY);
         p != nullptr;
         p = icalcomponent_get_next_property(vevent, ICAL_EXDATE_PROPERTY)) {
        icaltimetype t = icalproperty_get_exdate(p);
        resolvePropertyZone(p, t, vcal);
        QDateTime dt = convertWithZone(t);
        if (dt.isValid()) out.push_back(dt);
    }
}

QStringList parseCategories(icalcomponent* vevent) {
    QStringList out;
    for (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_CATEGORIES_PROPERTY);
         p != nullptr;
         p = icalcomponent_get_next_property(vevent, ICAL_CATEGORIES_PROPERTY)) {
        const char* cats = icalproperty_get_categories(p);
        if (!cats) continue;
        const QString s = QString::fromUtf8(cats);
        for (const QString& part : s.split(',', Qt::SkipEmptyParts))
            out << part.trimmed();
    }
    return out;
}

void extractTimezone(icalproperty* dtstart, EventTimezone& tz) {
    if (!dtstart) return;
    icaltimetype t = icalproperty_get_dtstart(dtstart);
    if (t.is_date) {
        // All-day — no zone semantics
        tz.isFloating = true;
        return;
    }
    if (icaltime_is_utc(t)) {
        tz.isUtc = true;
        return;
    }
    icalparameter* tzidParam = icalproperty_get_first_parameter(dtstart, ICAL_TZID_PARAMETER);
    if (tzidParam) {
        const char* tzid = icalparameter_get_tzid(tzidParam);
        if (tzid && *tzid) tz.tzid = QString::fromUtf8(tzid);
    }
    if (tz.tzid.isEmpty()) tz.isFloating = true;
}

Event extractEvent(icalcomponent* vevent, const QString& path, const QString& calendar) {
    Event ev;
    ev.sourceFile  = path;
    ev.calendar    = calendar;
    ev.uid         = cstr(icalcomponent_get_uid(vevent));
    ev.title       = cstr(icalcomponent_get_summary(vevent));
    ev.description = cstr(icalcomponent_get_description(vevent));
    ev.location    = cstr(icalcomponent_get_location(vevent));
    ev.categories  = parseCategories(vevent);
    ev.status      = statusToString(icalcomponent_get_status(vevent));

    icalcomponent* vcal = icalcomponent_get_parent(vevent);

    icalproperty* dtstartProp = icalcomponent_get_first_property(vevent, ICAL_DTSTART_PROPERTY);
    if (dtstartProp) {
        extractTimezone(dtstartProp, ev.timezone);
        icaltimetype t = icalproperty_get_dtstart(dtstartProp);
        resolvePropertyZone(dtstartProp, t, vcal);
        ev.allDay = (t.is_date != 0);
        ev.start  = convertWithZone(t);
    }

    // RFC 5545 §3.6.1: DTEND and DURATION are mutually exclusive ways to say
    // the same thing, and a DATE-valued DTSTART with neither lasts ONE DAY.
    // Only DTEND was read, so a DURATION-only event (Apple/iCloud and
    // Nextcloud emit these on recurring events) collapsed to zero length, and
    // a bare all-day event ended the instant it began — which also made it
    // vanish from any range query, since a zero-length event only matches a
    // range that contains its exact start.
    if (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_DTEND_PROPERTY)) {
        icaltimetype t = icalproperty_get_dtend(p);
        resolvePropertyZone(p, t, vcal);
        ev.end = convertWithZone(t);
    } else if (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_DURATION_PROPERTY)) {
        const struct icaldurationtype d = icalproperty_get_duration(p);
        ev.end = ev.start.isValid()
            ? ev.start.addSecs(icaldurationtype_as_seconds(d))
            : ev.start;
    } else if (ev.allDay) {
        ev.end = ev.start.isValid() ? ev.start.addDays(1) : ev.start;
    } else {
        ev.end = ev.start;
    }

    if (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_RRULE_PROPERTY)) {
        const char* raw = icalproperty_get_value_as_string(p);
        if (raw) ev.rruleRaw = QString::fromUtf8(raw);
        if (struct icalrecurrencetype* rule = icalproperty_get_rrule(p)) {  // borrowed
            ev.recurrence = fromIcalFreq(rule->freq);
            if (!icaltime_is_null_time(rule->until)) {
                ev.recurrenceUntil = QDate(rule->until.year, rule->until.month, rule->until.day);
            }
        }
    }

    parseExdates(vevent, ev.exdates);
    parseRdates(vevent, ev.rdates);

    if (icalproperty* p = icalcomponent_get_first_property(vevent, ICAL_RECURRENCEID_PROPERTY)) {
        icaltimetype t = icalproperty_get_recurrenceid(p);
        resolvePropertyZone(p, t, vcal);
        ev.recurrenceId = convertWithZone(t);
    }

    return ev;
}

// Compare an EXDATE entry to an occurrence start. Uses the master event's
// allDay flag to decide whether to compare dates only or full timestamps.
bool exdateMatches(const std::vector<QDateTime>& exdates,
                   const QDateTime& occ, bool allDay) {
    for (const QDateTime& e : exdates) {
        if (allDay) {
            if (e.date() == occ.date()) return true;
        } else {
            // Allow second-level mismatch tolerance — RRULE iterator
            // may produce occurrences at second-precision while EXDATE
            // is minute-precise.
            if (e.date() == occ.date() &&
                e.time().hour()   == occ.time().hour() &&
                e.time().minute() == occ.time().minute()) return true;
        }
    }
    return false;
}

} // namespace

namespace IcalParser {

QDateTime icalTimeToQDateTime(const icaltimetype& t) {
    return convertWithZone(t);
}

icaltimetype qDateTimeToIcalTime(const QDateTime& dt, bool asDate) {
    icaltimetype t = icaltime_null_time();
    if (!dt.isValid()) return t;

    if (asDate) {
        QDate d = dt.date();
        t = icaltime_null_date();
        t.year = d.year();
        t.month = d.month();
        t.day = d.day();
        t.is_date = 1;
        return t;
    }

    QDateTime utc = dt.toUTC();
    QDate d = utc.date();
    QTime tm = utc.time();
    t.year   = d.year();
    t.month  = d.month();
    t.day    = d.day();
    t.hour   = tm.hour();
    t.minute = tm.minute();
    t.second = tm.second();
    t.is_date = 0;
    t.zone   = icaltimezone_get_utc_timezone();
    return t;
}

icaltimezone* resolveTimezone(const QString& tzid, icalcomponent* vcalendar) {
    if (tzid.isEmpty()) return icaltimezone_get_utc_timezone();
    if (vcalendar) {
        if (icaltimezone* tz = icalcomponent_get_timezone(vcalendar, tzid.toUtf8().constData()))
            return tz;
    }
    if (icaltimezone* tz = icaltimezone_get_builtin_timezone(tzid.toUtf8().constData()))
        return tz;
    return icaltimezone_get_utc_timezone();
}

ical::ComponentPtr parseToComponent(const QByteArray& data) {
    return ical::wrapComponent(icalparser_parse_string(data.constData()));
}

QString serializeComponent(icalcomponent* root) {
    if (!root) return QString();
    ical::StringPtr str = ical::wrapString(icalcomponent_as_ical_string_r(root));
    if (!str) return QString();
    return QString::fromUtf8(str.get());
}

std::vector<Event> parseFile(const QString& path, const QString& calendar) {
    std::vector<Event> out;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return out;
    const QByteArray data = f.readAll();
    f.close();
    if (data.isEmpty()) return out;

    ical::ComponentPtr root = parseToComponent(data);
    if (!root) return out;

    for (icalcomponent* ve = icalcomponent_get_first_component(root.get(), ICAL_VEVENT_COMPONENT);
         ve != nullptr;
         ve = icalcomponent_get_next_component(root.get(), ICAL_VEVENT_COMPONENT)) {
        out.push_back(extractEvent(ve, path, calendar));
    }
    return out;
}

QVariantList expandRange(const std::vector<Event>& events,
                         const QDate& from, const QDate& to)
{
    QVariantList out;
    if (!from.isValid() || !to.isValid() || from > to) return out;

    const QDateTime rangeStart(from, QTime(0, 0), QTimeZone::LocalTime);
    const QDateTime rangeEnd(to.addDays(1), QTime(0, 0), QTimeZone::LocalTime);

    // Index overrides by UID + recurrenceId. Used both to render the
    // override at its moved time AND to suppress the master at the
    // original date — RFC 5545 doesn't require EXDATE when an override
    // exists, but Google/Yandex CalDAV clients often omit it.
    QMap<QString, const Event*> overrideByKey;
    QSet<QString>               overrideKeys;
    for (const Event& ev : events) {
        if (ev.isOverride()) {
            const QString k = ev.uid + QLatin1Char('|') +
                              ev.recurrenceId.toString(Qt::ISODate);
            overrideByKey.insert(k, &ev);
            overrideKeys.insert(k);
        }
    }

    icaltimezone* localTz = icaltimezone_get_builtin_timezone(
        QTimeZone::systemTimeZoneId().constData());
    if (!localTz) localTz = icaltimezone_get_utc_timezone();

    // Does [start, end) overlap [rangeStart, rangeEnd)?
    //
    // DTEND is EXCLUSIVE, and the range filters used to ignore that: an
    // all-day event on 15 Mar has DTEND 16 Mar, so `end >= rangeStart` made
    // it appear on the 16th as well — every all-day event was duplicated
    // onto the following day, and every timed one onto the moment it ended.
    // Zero-length events are points and are kept when they sit inside the
    // range, which half-open comparison alone would drop.
    const auto intersects = [&](const QDateTime& start, const QDateTime& end) {
        if (start >= rangeEnd) return false;
        return end > start ? end > rangeStart : start >= rangeStart;
    };

    for (const Event& ev : events) {
        if (ev.isOverride()) continue;            // emitted via override map
        if (!ev.start.isValid()) continue;

        // Expansion is decided by the RRULE itself, never by `ev.recurrence`.
        // That enum is the EDITOR's vocabulary (none/daily/weekly/monthly/
        // yearly); libical also knows HOURLY, MINUTELY and SECONDLY, which
        // mapped to None and made the expander treat a live series as a
        // one-off — FREQ=HOURLY;COUNT=5 rendered exactly once.
        const qint64 seriesDuration = ev.start.secsTo(ev.end);

        // One place where an occurrence becomes output, so RRULE-produced and
        // RDATE-produced ones cannot drift apart on filtering. Returns false
        // if the occurrence was suppressed (out of range, EXDATE, overridden,
        // or already emitted).
        QSet<QString> emitted;
        auto emit_ = [&](const QDateTime& occStart) {
            const QDateTime occEnd = occStart.addSecs(seriesDuration);
            if (!intersects(occStart, occEnd)) return false;
            if (exdateMatches(ev.exdates, occStart, ev.allDay)) return false;
            const QString key = ev.uid + QLatin1Char('|') + occStart.toString(Qt::ISODate);
            // Suppress the master at any date carrying a RECURRENCE-ID override,
            // even when the file omits the matching EXDATE — RFC 5545 does not
            // require one and Google/Yandex often leave it out.
            if (overrideKeys.contains(key)) return false;
            if (emitted.contains(key)) return false;
            emitted.insert(key);
            out.append(ev.toVariantMap(occStart, occEnd));
            return true;
        };

        // RDATE occurrences are explicit additions to the series and apply
        // whether or not an RRULE is present — an RDATE-only VEVENT is a
        // perfectly legal "these exact dates" series.
        auto emitRdates = [&]() { for (const QDateTime& r : ev.rdates) emit_(r); };

        if (ev.rruleRaw.isEmpty()) {
            emit_(ev.start);
            emitRdates();
            continue;
        }

        // Recurring — expand in event's authoring TZ
        ical::RecurrencePtr rule = ical::wrapRecurrence(
            icalrecurrencetype_new_from_string(ev.rruleRaw.toUtf8().constData()));
        if (!rule) {
            // Unparseable RRULE: degrade to a single event rather than drop it.
            // `continue` here would make a malformed series vanish entirely,
            // which is the worst possible reading of "I don't understand this".
            emit_(ev.start);
            emitRdates();
            continue;
        }

        const qint64 durationSecs = seriesDuration;

        // Build dtstart in event's authoring zone (not local, not UTC).
        icaltimezone* eventTz = nullptr;
        if (!ev.timezone.tzid.isEmpty())
            eventTz = icaltimezone_get_builtin_timezone(ev.timezone.tzid.toUtf8().constData());
        if (!eventTz) eventTz = ev.timezone.isUtc
            ? icaltimezone_get_utc_timezone()
            : localTz;   // floating events expand in local zone

        // ev.start is local-displayed; convert back to authoring TZ for iter
        icaltimetype dtstart = icaltime_null_time();
        if (ev.allDay) {
            // A VALUE=DATE is FLOATING — it denotes a calendar day, not an
            // instant, and has no zone to convert from or to. Routing it
            // through UTC like a timed event moved it back by the local
            // offset: in MSK (UTC+3) a birthday on 20 Oct became
            // 19 Oct 21:00 UTC, and since only the date part is kept, every
            // yearly occurrence landed on the 19th. The bug is invisible in
            // UTC and anywhere west of it, which is why it survived.
            // Take the date as authored and leave the zone null.
            const QDate d = ev.start.date();
            dtstart.year   = d.year();
            dtstart.month  = d.month();
            dtstart.day    = d.day();
            dtstart.hour   = 0;
            dtstart.minute = 0;
            dtstart.second = 0;
            dtstart.is_date = 1;
            dtstart.zone   = nullptr;
        } else {
            // Timed event: build a UTC representation, then move it into the
            // authoring zone the RRULE is meant to be iterated in.
            const QDateTime utc = ev.start.toUTC();
            dtstart.year   = utc.date().year();
            dtstart.month  = utc.date().month();
            dtstart.day    = utc.date().day();
            dtstart.hour   = utc.time().hour();
            dtstart.minute = utc.time().minute();
            dtstart.second = utc.time().second();
            dtstart.is_date = 0;
            dtstart.zone   = icaltimezone_get_utc_timezone();
            dtstart = icaltime_convert_to_zone(dtstart, eventTz);
        }

        ical::RecurIterPtr it = ical::wrapRecurIter(icalrecur_iterator_new(rule.get(), dtstart));
        if (!it) continue;

        // Fast-forward to just before the requested range. Without this,
        // every request replays the series from DTSTART — a decade-old
        // daily event costs thousands of iterations per call and the
        // safety cap silently drops occurrences past ~13.7 years. COUNT
        // rules must iterate from the start to number the occurrences.
        if (rule.get()->count == 0) {
            if (ev.allDay) {
                // All-day series were excluded from fast-forward, so they
                // always replayed from DTSTART and the 5000-iteration cap cut
                // them off after ~13.7 years: a DAILY all-day event authored
                // in 2005 produced ZERO occurrences in 2026. The seek value
                // must itself be a DATE — handing the iterator a timed value
                // for a date-based rule is what made this unsafe before.
                // Back off by the event's own span in days so a multi-day
                // occurrence that starts before the range but overlaps it is
                // still produced.
                const qint64 spanDays = qMax<qint64>(0, ev.start.date().daysTo(ev.end.date()));
                const QDate ffDate = from.addDays(-spanDays);
                if (ffDate > ev.start.date()) {
                    icaltimetype ff = icaltime_null_date();
                    ff.year    = ffDate.year();
                    ff.month   = ffDate.month();
                    ff.day     = ffDate.day();
                    ff.is_date = 1;
                    ff.zone    = nullptr;
                    icalrecur_iterator_set_start(it.get(), ff);
                }
            } else {
                const QDateTime ffLocal = rangeStart.addSecs(
                    durationSecs > 0 ? -durationSecs : 0);
                if (ffLocal > ev.start) {
                    icaltimetype ff = icaltime_from_timet_with_zone(
                        ffLocal.toSecsSinceEpoch(), 0, eventTz);
                    ff.zone = eventTz;
                    icalrecur_iterator_set_start(it.get(), ff);
                }
            }
        }

        int safety = 0;
        for (icaltimetype occ = icalrecur_iterator_next(it.get());
             !icaltime_is_null_time(occ) && safety < 5000;
             occ = icalrecur_iterator_next(it.get()), ++safety) {

            QDateTime occStart;
            if (ev.allDay) {
                occStart = QDateTime(QDate(occ.year, occ.month, occ.day),
                                     QTime(0, 0), QTimeZone::LocalTime);
            } else {
                // Convert occurrence from event TZ to local before exposing
                icaltimetype localOcc = icaltime_convert_to_zone(occ, localTz);
                occStart = QDateTime(QDate(localOcc.year, localOcc.month, localOcc.day),
                                     QTime(localOcc.hour, localOcc.minute, localOcc.second),
                                     QTimeZone::LocalTime);
            }
            if (occStart >= rangeEnd) break;
            emit_(occStart);
        }

        emitRdates();
    }

    // Emit overrides at their moved start (skip CANCELLED).
    for (auto it = overrideByKey.constBegin(); it != overrideByKey.constEnd(); ++it) {
        const Event* ov = it.value();
        if (ov->status == QLatin1String("CANCELLED")) continue;
        if (!ov->start.isValid()) continue;
        if (!intersects(ov->start, ov->end)) continue;
        out.append(ov->toVariantMap(ov->start, ov->end));
    }

    return out;
}

QString buildIcsString(const QVariantMap& fields) {
    ical::ComponentPtr cal = ical::wrapComponent(icalcomponent_new_vcalendar());
    if (!cal) return QString();
    icalcomponent_add_property(cal.get(), icalproperty_new_version("2.0"));
    icalcomponent_add_property(cal.get(),
        icalproperty_new_prodid("-//quickshell//calendar-qml//EN"));

    icalcomponent* ev = icalcomponent_new_vevent();   // ownership transferred at add_component below

    QString uid = fields.value(QStringLiteral("uid")).toString();
    if (uid.isEmpty()) {
        uid = QUuid::createUuid().toString(QUuid::WithoutBraces) +
              QStringLiteral("@quickshell");
    }
    icalcomponent_set_uid(ev, uid.toUtf8().constData());

    icaltimetype now = icaltime_current_time_with_zone(icaltimezone_get_utc_timezone());
    icalcomponent_add_property(ev, icalproperty_new_dtstamp(now));
    icalcomponent_add_property(ev, icalproperty_new_created(now));
    icalcomponent_add_property(ev, icalproperty_new_lastmodified(now));

    const QString title = fields.value(QStringLiteral("title")).toString();
    if (!title.isEmpty())
        icalcomponent_set_summary(ev, title.toUtf8().constData());

    const QString desc = fields.value(QStringLiteral("description")).toString();
    if (!desc.isEmpty())
        icalcomponent_set_description(ev, desc.toUtf8().constData());

    const QString loc = fields.value(QStringLiteral("location")).toString();
    if (!loc.isEmpty())
        icalcomponent_set_location(ev, loc.toUtf8().constData());

    const bool allDay = fields.value(QStringLiteral("allDay")).toBool();
    QDateTime start = fields.value(QStringLiteral("start")).toDateTime();
    QDateTime end   = fields.value(QStringLiteral("end")).toDateTime();
    if (!end.isValid()) end = start.addSecs(allDay ? 86400 : 3600);

    icalcomponent_set_dtstart(ev, qDateTimeToIcalTime(start, allDay));
    icalcomponent_set_dtend(ev,   qDateTimeToIcalTime(end,   allDay));

    QDateTime recurId = fields.value(QStringLiteral("recurrenceId")).toDateTime();
    if (recurId.isValid()) {
        icalcomponent_add_property(ev,
            icalproperty_new_recurrenceid(qDateTimeToIcalTime(recurId, allDay)));
    }

    const Recurrence rec = recurrenceFromString(fields.value(QStringLiteral("recurrence")).toString());
    if (rec != Recurrence::None) {
        ical::RecurrencePtr rule = ical::wrapRecurrence(icalrecurrencetype_new());
        rule->freq = toIcalFreq(rec);
        rule->interval = 1;
        QDate until = fields.value(QStringLiteral("recurrenceUntil")).toDate();
        if (until.isValid()) {
            // RFC 5545 §3.3.10: UNTIL's value type MUST match DTSTART's, and
            // when DTSTART is a DATE-TIME, UNTIL MUST be a UTC DATE-TIME.
            // A bare DATE was written for every series, timed ones included —
            // a spec violation other clients are free to reject. The user
            // picks a DAY, so a timed series runs to the END of that day.
            if (allDay) {
                icaltimetype u = icaltime_null_date();
                u.year  = until.year();
                u.month = until.month();
                u.day   = until.day();
                u.is_date = 1;
                rule->until = u;
            } else {
                const QDateTime endOfDayUtc =
                    QDateTime(until, QTime(23, 59, 59), QTimeZone::LocalTime).toUTC();
                icaltimetype u = icaltime_null_time();
                u.year   = endOfDayUtc.date().year();
                u.month  = endOfDayUtc.date().month();
                u.day    = endOfDayUtc.date().day();
                u.hour   = endOfDayUtc.time().hour();
                u.minute = endOfDayUtc.time().minute();
                u.second = endOfDayUtc.time().second();
                u.is_date = 0;
                u.zone    = icaltimezone_get_utc_timezone();
                rule->until = u;
            }
        }
        icalcomponent_add_property(ev, icalproperty_new_rrule(rule.get()));
    }

    QStringList cats = fields.value(QStringLiteral("categories")).toStringList();
    if (!cats.isEmpty()) {
        QByteArray joined = cats.join(QLatin1Char(',')).toUtf8();
        icalcomponent_add_property(ev,
            icalproperty_new_categories(joined.constData()));
    }

    icalcomponent_add_component(cal.get(), ev);   // transfers ownership
    return serializeComponent(cal.get());
}

} // namespace IcalParser

// ── Event::toVariantMap ───────────────────────────────────────────────

QVariantMap Event::toVariantMap(const QDateTime& occurrenceStart,
                                const QDateTime& occurrenceEnd) const
{
    QVariantMap m;
    m.insert(QStringLiteral("uid"), uid);
    m.insert(QStringLiteral("calendar"), calendar);
    m.insert(QStringLiteral("title"), title);
    m.insert(QStringLiteral("description"), description);
    m.insert(QStringLiteral("location"), location);
    m.insert(QStringLiteral("categories"), categories);
    m.insert(QStringLiteral("start"), occurrenceStart.isValid() ? occurrenceStart : start);
    m.insert(QStringLiteral("end"),   occurrenceEnd.isValid()   ? occurrenceEnd   : end);
    m.insert(QStringLiteral("allDay"), allDay);
    m.insert(QStringLiteral("status"), status.isEmpty() ? QStringLiteral("CONFIRMED") : status);
    m.insert(QStringLiteral("recurrence"), toString(recurrence));
    m.insert(QStringLiteral("recurrenceUntil"), recurrenceUntil);
    m.insert(QStringLiteral("isRecurringInstance"),
             !rruleRaw.isEmpty() && occurrenceStart.isValid() && occurrenceStart != start);
    m.insert(QStringLiteral("isRecurringMaster"), !rruleRaw.isEmpty());
    // Override identity: QML must hand recurrenceId back on edit/delete so
    // the store can address the override VEVENT instead of the master
    // (uid alone deleted the WHOLE SERIES when targeting a moved instance).
    m.insert(QStringLiteral("isOverride"), isOverride());
    m.insert(QStringLiteral("recurrenceId"), recurrenceId);
    m.insert(QStringLiteral("sourceFile"), sourceFile);
    return m;
}
