#include <glib.h>
#include "VpnUiHelper.h"
#include <QFileInfo>
#include <QProcess>
#include <QDeadlineTimer>
#include <QRegularExpression>

namespace VpnUiHelper {
QByteArray input(const NetworkSettings& connection) {
    QByteArray out;
    const auto data = NetworkCredentials::stringMap(connection.value("vpn").value("data"));
    for (auto it = data.cbegin(); it != data.cend(); ++it) {
        if (it.key().contains('\n') || it.key().contains(QChar('\0')) || it.value().contains(QChar('\0'))) return {};
        out += "DATA_KEY=" + it.key().toUtf8() + "\nDATA_VAL=" + it.value().toUtf8().replace("\n", "\n=") + "\n";
        if (out.size() > 1024 * 1024) return {};
    }
    // The helper only describes fields. These non-secret placeholders prevent
    // it from querying/unlocking a keyring itself; our store owns that lifecycle.
    for (const auto* key : {"password", "cert-pass", "http-proxy-password"})
        out += QByteArray("SECRET_KEY=") + key + "\nSECRET_VAL=shell-field-description\n";
    return out + "DONE\n\nQUIT\n\n";
}
NetworkCredentials::Description parse(const QByteArray& output, const NetworkSettings& connection) {
    NetworkCredentials::Description out;
    out.uuid = connection.value("connection").value("uuid").toString();
    out.name = connection.value("connection").value("id").toString().left(256);
    out.setting = "vpn";
    if (output.isEmpty() || output.size() > 65536) return out;
    GError* error = nullptr;
    GKeyFile* file = g_key_file_new();
    if (!g_key_file_load_from_data(file, output.constData(), output.size(), G_KEY_FILE_NONE, &error)) {
        if (error) g_error_free(error);
        g_key_file_unref(file); return out;
    }
    if (g_key_file_get_integer(file, "VPN Plugin UI", "Version", nullptr) != 2) {
        g_key_file_unref(file); return out;
    }
    gchar* description = g_key_file_get_string(file, "VPN Plugin UI", "Description", nullptr);
    if (description) { out.message = QString::fromUtf8(description).left(4096); g_free(description); }
    const auto data = NetworkCredentials::stringMap(connection.value("vpn").value("data"));
    const auto values = NetworkCredentials::stringMap(connection.value("vpn").value("secrets"));
    gsize count = 0;
    gchar** groups = g_key_file_get_groups(file, &count);
    bool valid = count <= 17;
    for (gsize i = 0; valid && i < count; ++i) {
        const QString key = QString::fromUtf8(groups[i]);
        if (key == "VPN Plugin UI") continue;
        if (key == "no-secret") { out.values.insert(key, "true"); continue; }
        if (key.size() > 128 || key.contains(QChar('\0'))) { valid = false; break; }
        if (!g_key_file_get_boolean(file, groups[i], "ShouldAsk", nullptr)) continue;
        gchar* label = g_key_file_get_string(file, groups[i], "Label", nullptr);
        const auto text = label ? QString::fromUtf8(label).left(256) : QStringLiteral("VPN credential");
        g_free(label);
        const bool echo = g_key_file_get_boolean(file, groups[i], "ForceEcho", nullptr);
        out.fields.append(QVariantMap{{"key", key}, {"label", text}, {"secret", !echo}});
        bool ok = true;
        const auto flags = data.contains(key + "-flags") ? data.value(key + "-flags").toUInt(&ok) : 0u;
        if (!ok || (flags & ~7u)) { valid = false; break; }
        const bool challenge = key.startsWith("x-dynamic-challenge") || key == "challenge-response";
        out.secretFlags.insert(key, challenge ? 2u : flags);
        if (!challenge && !values.value(key).isEmpty()) out.values.insert(key, values.value(key));
    }
    g_strfreev(groups); g_key_file_unref(file);
    out.supported = valid && (!out.fields.isEmpty() || out.values.contains("no-secret"));
    return out;
}
CredentialStore::Result describe(const CredentialStore::Job& job, const CredentialStore::Cancellation& cancel) {
    CredentialStore::Result out;
    if (job.connection.value("vpn").value("service-type").toString() != "org.freedesktop.NetworkManager.openvpn") {
        out.error = "This VPN authentication plugin is not supported"; return out;
    }
    const QString path = "/usr/lib/nm-openvpn-auth-dialog";
    QFileInfo file(path);
    const auto forbidden = QFileDevice::WriteGroup | QFileDevice::WriteOther;
    if (!file.isFile() || !file.isExecutable() || file.ownerId() != 0 || (file.permissions() & forbidden)) {
        out.error = "The trusted OpenVPN authentication helper is unavailable"; return out;
    }
    const auto payload = input(job.connection);
    if (payload.isEmpty()) { out.error = "Invalid VPN authentication data"; return out; }
    QProcess process;
    QStringList arguments = {"--uuid", job.uuid, "--name", job.label, "--service",
        "org.freedesktop.NetworkManager.openvpn", "--external-ui-mode", "--allow-interaction"};
    if (job.requestNew) arguments << "--reprompt";
    for (const auto& hint : job.hints) {
        if (hint.size() > 4096 || hint.contains(QChar('\0'))) { out.error = "Invalid VPN authentication hint"; return out; }
        arguments << "--hint" << hint;
    }
    process.setProgram(path); process.setArguments(arguments);
    process.start();
    if (!process.waitForStarted(5000)) {
        if (process.state() != QProcess::NotRunning) { process.kill(); process.waitForFinished(-1); }
        out.error = "Could not start the OpenVPN authentication helper"; return out;
    }
    process.write(payload); process.closeWriteChannel();
    QByteArray output;
    QDeadlineTimer deadline(5000);
    while (process.state() != QProcess::NotRunning) {
        process.waitForFinished(50);
        output += process.readAllStandardOutput(); process.readAllStandardError();
        if (output.size() > 65536 || deadline.hasExpired() || CredentialStore::isCancelled(cancel)) {
            process.kill(); process.waitForFinished(-1);
            out.cancelled = CredentialStore::isCancelled(cancel);
            out.error = out.cancelled ? "VPN authentication cancelled" : "VPN authentication helper exceeded its limits";
            return out;
        }
    }
    output += process.readAllStandardOutput();
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        out.error = "OpenVPN authentication helper failed"; return out;
    }
    out.description = parse(output, job.connection);
    out.success = out.description.supported;
    if (!out.success) out.error = "Unsupported OpenVPN authentication response";
    return out;
}
}
