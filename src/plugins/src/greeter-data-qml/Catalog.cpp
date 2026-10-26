#include "Catalog.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>
#include <memory>
// Qt's signals macro conflicts with a GLib structure member.
#pragma push_macro("signals")
#undef signals
#include <glib.h>
#pragma pop_macro("signals")

namespace {
constexpr qint64 MaxSessionBytes = 128 * 1024;
constexpr qint64 MaxPasswdBytes = 8 * 1024 * 1024;
constexpr int MaxSessions = 256;
constexpr int MaxUsers = 512;
constexpr int MaxArguments = 256;
using KeyFile = std::unique_ptr<GKeyFile, decltype(&g_key_file_unref)>;
using String = std::unique_ptr<gchar, decltype(&g_free)>;

QString value(GKeyFile* key, const char* name, const QString& locale = {}) {
    String text(locale.isEmpty()
                    ? g_key_file_get_string(key, "Desktop Entry", name, nullptr)
                    : g_key_file_get_locale_string(key, "Desktop Entry", name,
                                                   locale.toUtf8().constData(), nullptr),
                &g_free);
    return text ? QString::fromUtf8(text.get()) : QString();
}
bool flag(GKeyFile* key, const char* name) {
    return g_key_file_get_boolean(key, "Desktop Entry", name, nullptr);
}
QString executable(const QString& name, const QStringList& paths) {
    if (name.isEmpty() || name.contains(QChar::Null)) return {};
    if (QDir::isAbsolutePath(name)) {
        const QFileInfo file(name);
        return file.isFile() && file.isExecutable() ? file.absoluteFilePath() : QString();
    }
    if (name.contains('/')) return {};
    return QStandardPaths::findExecutable(name, paths);
}
QStringList expand(const QStringList& arguments, GKeyFile* key, const QString& path,
                   const QString& name, QString* error) {
    QStringList result;
    for (const auto& argument : arguments) {
        if (argument == "%i") {
            const auto icon = value(key, "Icon");
            if (!icon.isEmpty()) result << "--icon" << icon;
            continue;
        }
        QString out;
        bool removed = false;
        for (qsizetype i = 0; i < argument.size(); ++i) {
            if (argument[i] != '%') { out += argument[i]; continue; }
            if (++i == argument.size()) { *error = "Trailing field code"; return {}; }
            const auto code = argument[i];
            if (code == '%') out += '%';
            else if (code == 'c') out += name;
            else if (code == 'k') out += path;
            else if (QStringLiteral("fFuUdDnNvm").contains(code)) {
                // Session startup has no file/URL arguments. Deprecated codes
                // are removed too; list-valued codes must occupy their own token.
                if (argument.size() != 2) { *error = "Embedded file field code"; return {}; }
                removed = true;
            } else { *error = "Unsupported field code: %" + QString(code); return {}; }
        }
        if (!removed) result << out; // Preserve explicitly quoted empty arguments.
    }
    return result;
}
void report(QStringList& errors, const QString& message) {
    if (errors.size() < 8) errors << message.left(512);
}
}

namespace GreeterCatalog {
QVariantMap parseSession(const QByteArray& data, const QString& path,
                         const QString& kind, const Input& input, QString* error) {
    error->clear();
    if (data.size() > MaxSessionBytes || data.contains('\0')) {
        *error = "Invalid or oversized desktop entry";
        return {};
    }
    KeyFile key(g_key_file_new(), &g_key_file_unref);
    GError* failure = nullptr;
    if (!g_key_file_load_from_data(key.get(), data.constData(), data.size(),
                                  G_KEY_FILE_KEEP_TRANSLATIONS, &failure)) {
        *error = QString::fromUtf8(failure->message);
        g_error_free(failure);
        return {};
    }
    if (!g_key_file_has_group(key.get(), "Desktop Entry")) { *error = "Missing Desktop Entry group"; return {}; }
    if (flag(key.get(), "Hidden") || flag(key.get(), "NoDisplay")) return {};
    if (value(key.get(), "Type") != "Application") { *error = "Not an application entry"; return {}; }
    if (flag(key.get(), "Terminal")) { *error = "Terminal sessions require an explicit wrapper"; return {}; }
    const auto name = value(key.get(), "Name", input.locale);
    const auto command = value(key.get(), "Exec");
    if (name.isEmpty() || command.isEmpty()) { *error = "Missing Name or Exec"; return {}; }
    if (name.size() > 256) { *error = "Session name is too long"; return {}; }
    const auto tryExec = value(key.get(), "TryExec");
    if (!tryExec.isEmpty() && executable(tryExec, input.executablePaths).isEmpty()) return {};
    gint count = 0;
    gchar** parsed = nullptr;
    if (!g_shell_parse_argv(command.toUtf8().constData(), &count, &parsed, &failure)) {
        *error = QString::fromUtf8(failure->message);
        g_error_free(failure);
        return {};
    }
    std::unique_ptr<gchar*, decltype(&g_strfreev)> owner(parsed, &g_strfreev);
    if (count > MaxArguments) { *error = "Too many session arguments"; return {}; }
    QStringList arguments;
    for (int i = 0; i < count; ++i) arguments << QString::fromUtf8(parsed[i]);
    arguments = expand(arguments, key.get(), path, name, error);
    if (!error->isEmpty() || arguments.isEmpty()) return {};
    if (arguments.size() > MaxArguments) { *error = "Too many expanded session arguments"; return {}; }
    if (arguments[0].contains('=')) { *error = "Invalid executable name"; return {}; }
    const auto binary = executable(arguments[0], input.executablePaths);
    if (binary.isEmpty()) return {};
    arguments[0] = binary;
    return {{"id", kind + '/' + QFileInfo(path).fileName()}, {"name", name},
            {"comment", value(key.get(), "Comment", input.locale).left(512)}, {"exec", command},
            {"argv", arguments}, {"type", kind}, {"path", path}};
}

QVariantList parseUsers(const QByteArray& data) {
    QVariantList users;
    QSet<QString> seen;
    if (data.size() > MaxPasswdBytes || data.contains('\0')) return users;
    for (const auto& line : data.split('\n')) {
        if (users.size() == MaxUsers) break;
        const auto fields = line.split(':');
        if (fields.size() != 7) continue;
        bool validUid = false;
        const auto uid = fields[2].toUInt(&validUid);
        const auto username = QString::fromUtf8(fields[0]);
        const auto shell = QString::fromUtf8(fields[6]).trimmed();
        if (!validUid || uid < 1000 || uid >= 65534 || username.isEmpty() || username.size() > 256 ||
            seen.contains(username) || shell.isEmpty() || QFileInfo(shell).fileName() == "nologin" ||
            QFileInfo(shell).fileName() == "false") continue;
        seen.insert(username);
        const auto display = QString::fromUtf8(fields[4]).section(',', 0, 0).left(256);
        users << QVariantMap{{"username", username}, {"displayName", display.isEmpty() ? username : display},
                             {"uid", uid}};
    }
    std::sort(users.begin(), users.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value("username").toString() < b.toMap().value("username").toString();
    });
    return users;
}

Result collect(const Input& input) {
    Result result;
    QSet<QString> seen;
    int scanned = 0;
    for (const auto& directory : input.dataDirectories) {
        for (const auto& kind : {QStringLiteral("wayland"), QStringLiteral("x11")}) {
            const QDir dir(directory + (kind == "wayland" ? "/wayland-sessions" : "/xsessions"));
            for (const auto& entry : dir.entryInfoList({"*.desktop"}, QDir::Files, QDir::Name)) {
                const auto id = kind + '/' + entry.fileName();
                if (seen.contains(id)) continue;
                seen.insert(id); // Hidden/invalid high-priority entries also shadow lower ones.
                if (++scanned > MaxSessions) { report(result.errors, "Session catalog limit reached"); break; }
                QFile file(entry.absoluteFilePath());
                if (entry.size() > MaxSessionBytes || !file.open(QIODevice::ReadOnly)) {
                    report(result.errors, entry.fileName() + ": cannot read desktop entry");
                    continue;
                }
                QString error;
                const auto session = parseSession(file.read(MaxSessionBytes + 1), file.fileName(), kind, input, &error);
                if (!session.isEmpty()) result.sessions << session;
                else if (!error.isEmpty()) report(result.errors, entry.fileName() + ": " + error);
            }
        }
        if (scanned > MaxSessions) break;
    }
    QFile passwd(input.passwdPath);
    if (!QFileInfo(passwd).isFile() || !passwd.open(QIODevice::ReadOnly))
        report(result.errors, "Cannot read local user catalog");
    else {
        const auto data = passwd.read(MaxPasswdBytes + 1);
        if (data.size() > MaxPasswdBytes) report(result.errors, "Local user catalog limit reached");
        else result.users = parseUsers(data);
    }
    return result;
}
} // namespace GreeterCatalog
