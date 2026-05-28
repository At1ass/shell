#pragma once

// RAII wrappers for libical opaque pointers.
//
// libical hands out raw owned pointers from `*_new` / `*_parse_*` and
// `*_as_ical_string_r`, plus a free-floating `char*` for serialised
// strings (freed via `icalmemory_free_buffer`). Manually pairing each
// allocation with a free is error-prone — this header forces RAII.
//
// ── Ownership rules (libical 3.0) ────────────────────────────────────
// • `icalcomponent_new_*` / `icalparser_parse_string`        → caller owns
// • `icalrecur_iterator_new`                                  → caller owns
// • `icalcomponent_as_ical_string_r`                          → caller owns the char*
//
// • `icalcomponent_add_property(parent, prop)`        ← TRANSFERS ownership of prop
// • `icalcomponent_add_component(parent, child)`      ← TRANSFERS ownership of child
//
// • `icalcomponent_get_first_property` / `_get_first_component`         → BORROWED
// • `icalcomponent_get_uid` / `_get_summary` / `_get_description`       → BORROWED
// • Any `icalproperty_get_*` returning a pointer                        → BORROWED
//
// • `icaltimetype` / `icalparameter*` (returned)                       → value/borrowed
// • `icalrecurrencetype*` (libical ≥ 4.0): refcounted; owned from
//   `icalrecurrencetype_new` / `_new_from_string` / `_clone`,
//   borrowed from `icalproperty_get_rrule`. Release owned with
//   `icalrecurrencetype_unref` (wrapped here as `RecurrencePtr`).
//
// Convention in this codebase:
// 1. Wrap a pointer at the moment of allocation in the appropriate alias below.
// 2. Pass the wrapped object by reference, or call `.get()` for borrowed access.
// 3. Only call `.release()` when transferring ownership to a libical parent
//    via `icalcomponent_add_*`.

#include <libical/ical.h>
#include <memory>

namespace ical {

using ComponentPtr = std::unique_ptr<icalcomponent, decltype(&icalcomponent_free)>;
using RecurIterPtr = std::unique_ptr<icalrecur_iterator, decltype(&icalrecur_iterator_free)>;
using RecurrencePtr = std::unique_ptr<icalrecurrencetype, decltype(&icalrecurrencetype_unref)>;

// icalmemory_free_buffer takes void*, but we want a typed unique_ptr<char>.
// Wrap the call in a deleter functor.
struct MemBufferDeleter {
    void operator()(char* p) const noexcept {
        if (p) icalmemory_free_buffer(p);
    }
};
using StringPtr = std::unique_ptr<char, MemBufferDeleter>;

// Construction helpers — explicit at call site, hides the deleter wiring.
inline ComponentPtr wrapComponent(icalcomponent* p) noexcept {
    return { p, &icalcomponent_free };
}

inline RecurIterPtr wrapRecurIter(icalrecur_iterator* p) noexcept {
    return { p, &icalrecur_iterator_free };
}

inline RecurrencePtr wrapRecurrence(icalrecurrencetype* p) noexcept {
    return { p, &icalrecurrencetype_unref };
}

inline StringPtr wrapString(char* p) noexcept {
    return StringPtr(p);
}

} // namespace ical
