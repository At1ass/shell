#pragma once

// Atomic file write — wraps QSaveFile so callers don't need to know the
// commit/cancel dance. QSaveFile internally writes to a sibling temp file
// and renames over the destination on commit; the destination either
// stays untouched on failure or contains the full new contents on success.

#include <QtCore/QString>
#include <QtCore/QByteArray>

namespace Atomic {

// Returns true on success. On failure, the original file at `path` is
// untouched and `*errorOut` (if non-null) holds a description.
bool writeFile(const QString& path,
               const QByteArray& bytes,
               QString* errorOut = nullptr);

} // namespace Atomic
