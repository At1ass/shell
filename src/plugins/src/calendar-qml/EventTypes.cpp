#include "EventTypes.h"

QString toString(EditScope s) {
    switch (s) {
        case EditScope::All:          return QStringLiteral("all");
        case EditScope::ThisInstance: return QStringLiteral("this");
    }
    return QStringLiteral("all");
}

EditScope editScopeFromString(const QString& s) {
    if (s == QLatin1String("this")) return EditScope::ThisInstance;
    return EditScope::All;
}

QString toString(Recurrence r) {
    switch (r) {
        case Recurrence::None:    return QStringLiteral("none");
        case Recurrence::Daily:   return QStringLiteral("daily");
        case Recurrence::Weekly:  return QStringLiteral("weekly");
        case Recurrence::Monthly: return QStringLiteral("monthly");
        case Recurrence::Yearly:  return QStringLiteral("yearly");
    }
    return QStringLiteral("none");
}

Recurrence recurrenceFromString(const QString& s) {
    if (s == QLatin1String("daily"))   return Recurrence::Daily;
    if (s == QLatin1String("weekly"))  return Recurrence::Weekly;
    if (s == QLatin1String("monthly")) return Recurrence::Monthly;
    if (s == QLatin1String("yearly"))  return Recurrence::Yearly;
    return Recurrence::None;
}

icalrecurrencetype_frequency toIcalFreq(Recurrence r) {
    switch (r) {
        case Recurrence::Daily:   return ICAL_DAILY_RECURRENCE;
        case Recurrence::Weekly:  return ICAL_WEEKLY_RECURRENCE;
        case Recurrence::Monthly: return ICAL_MONTHLY_RECURRENCE;
        case Recurrence::Yearly:  return ICAL_YEARLY_RECURRENCE;
        case Recurrence::None:    return ICAL_NO_RECURRENCE;
    }
    return ICAL_NO_RECURRENCE;
}

Recurrence fromIcalFreq(icalrecurrencetype_frequency f) {
    switch (f) {
        case ICAL_DAILY_RECURRENCE:   return Recurrence::Daily;
        case ICAL_WEEKLY_RECURRENCE:  return Recurrence::Weekly;
        case ICAL_MONTHLY_RECURRENCE: return Recurrence::Monthly;
        case ICAL_YEARLY_RECURRENCE:  return Recurrence::Yearly;
        default:                      return Recurrence::None;
    }
}
