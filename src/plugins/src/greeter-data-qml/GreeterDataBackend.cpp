#include "GreeterDataBackend.h"
#include <QLocale>
#include <QDir>
#include <QtConcurrent>
#include <utility>

namespace {
GreeterCatalog::Input systemInput() {
    GreeterCatalog::Input input;
    input.dataDirectories = {"/usr/local/share", "/usr/share"};
    for (const auto& directory : qEnvironmentVariable("PATH").split(':', Qt::SkipEmptyParts)) {
        if (QDir::isAbsolutePath(directory)) input.executablePaths << directory;
    }
    if (input.executablePaths.isEmpty()) input.executablePaths = {"/usr/local/bin", "/usr/bin", "/bin"};
    input.locale = QLocale::system().name();
    input.passwdPath = "/etc/passwd";
    return input;
}
}

GreeterDataBackend::GreeterDataBackend(QObject* parent)
    : GreeterDataBackend(systemInput(), parent) {}
GreeterDataBackend::GreeterDataBackend(GreeterCatalog::Input input, QObject* parent)
    : QObject(parent), m_input(std::move(input)), m_watcher(this) {
    connect(&m_watcher, &QFutureWatcher<GreeterCatalog::Result>::finished, this, [this] {
        const auto next = m_watcher.result();
        const auto oldError = errorString();
        const bool sessionsChangedValue = next.sessions != m_result.sessions;
        const bool usersChangedValue = next.users != m_result.users;
        m_result = next;
        m_loading = false;
        const bool wasReady = m_ready;
        m_ready = true;
        if (sessionsChangedValue) emit sessionsChanged();
        if (usersChangedValue) emit usersChanged();
        emit loadingChanged();
        if (!wasReady) emit readyChanged();
        if (oldError != errorString()) emit errorOccurred(errorString());
    });
    reload();
}
void GreeterDataBackend::reload() {
    if (m_loading) return;
    m_loading = true;
    emit loadingChanged();
    // The future owns only value data. Deleting the facade never waits on I/O
    // and a completed result cannot call a destroyed QObject.
    m_watcher.setFuture(QtConcurrent::run([input = m_input] { return GreeterCatalog::collect(input); }));
}
QStringList GreeterDataBackend::sessionNames() const {
    QStringList result;
    for (const auto& session : m_result.sessions) result << session.toMap().value("name").toString();
    return result;
}
QStringList GreeterDataBackend::userNames() const {
    QStringList result;
    for (const auto& user : m_result.users) result << user.toMap().value("displayName").toString();
    return result;
}
int GreeterDataBackend::sessionIndex(const QString& preferred) const {
    if (preferred.isEmpty()) return -1;
    for (int i = 0; i < m_result.sessions.size(); ++i) {
        const auto session = m_result.sessions[i].toMap();
        if (session.value("id").toString() == preferred) return i;
    }
    if (preferred.startsWith("wayland/") || preferred.startsWith("x11/")) return -1;
    for (int i = 0; i < m_result.sessions.size(); ++i) {
        if (m_result.sessions[i].toMap().value("name").toString().compare(preferred, Qt::CaseInsensitive) == 0) return i;
    }
    for (int i = 0; i < m_result.sessions.size(); ++i) {
        if (m_result.sessions[i].toMap().value("exec").toString().contains(preferred, Qt::CaseInsensitive)) return i;
    }
    return -1;
}
int GreeterDataBackend::userIndex(const QString& username) const {
    for (int i = 0; i < m_result.users.size(); ++i) {
        if (m_result.users[i].toMap().value("username").toString() == username) return i;
    }
    return -1;
}
