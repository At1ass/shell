#pragma once

#include <QObject>
#include <QThread>

// A worker may outlive its QML facade while finishing an operation. Neither
// QObject destruction nor a timeout may destroy a running QThread. The thread
// owns its cleanup, and queued results lose their receiver with the facade.
namespace WorkerLifetime {
inline QThread* create(QObject* worker) {
    auto* thread = new QThread;
    worker->moveToThread(thread);
    QObject::connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    QObject::connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    return thread;
}

inline void retire(QThread*& thread) {
    if (!thread) return;
    thread->requestInterruption();
    thread->quit();
    thread = nullptr;
}
} // namespace WorkerLifetime
