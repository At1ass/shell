#pragma once

#include <QStringList>
#include <QVariantList>

namespace GreeterCatalog {
struct Input {
    QStringList dataDirectories;
    QStringList executablePaths;
    QString locale;
    QString passwdPath;
};
struct Result {
    QVariantList sessions;
    QVariantList users;
    QStringList errors;
};
// All filesystem access and parsing belongs to the independent worker input.
Result collect(const Input& input);
QVariantMap parseSession(const QByteArray& data, const QString& path,
                         const QString& kind, const Input& input, QString* error);
QVariantList parseUsers(const QByteArray& data);
} // namespace GreeterCatalog
