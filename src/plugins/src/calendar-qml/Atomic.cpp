#include "Atomic.h"

#include <QtCore/QSaveFile>

namespace Atomic {

bool writeFile(const QString& path, const QByteArray& bytes, QString* errorOut) {
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (errorOut) *errorOut = QStringLiteral("Cannot open for write: ") + path
                                + QStringLiteral(" (") + f.errorString() + QLatin1Char(')');
        return false;
    }
    const qint64 written = f.write(bytes);
    if (written != bytes.size()) {
        if (errorOut) *errorOut = QStringLiteral("Short write to ") + path;
        f.cancelWriting();
        return false;
    }
    if (!f.commit()) {
        if (errorOut) *errorOut = QStringLiteral("Commit failed: ") + path
                                + QStringLiteral(" (") + f.errorString() + QLatin1Char(')');
        return false;
    }
    return true;
}

} // namespace Atomic
