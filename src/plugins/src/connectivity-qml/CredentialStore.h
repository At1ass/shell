#pragma once
#include "NetworkCredentials.h"
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <memory>

typedef struct _GCancellable GCancellable;
namespace CredentialStore {
using Cancellation = std::shared_ptr<GCancellable>;
enum class Operation { Lookup, Save, Delete, DescribeVpn };
struct Job {
    Operation operation = Operation::Lookup;
    QString uuid, setting, label;
    QStringList keys;
    QVariantMap values;
    bool allowInteraction = false;
    bool requestNew = false;
    NetworkSettings connection;
    QStringList hints;
};
struct Result {
    bool success = false;
    bool cancelled = false;
    QVariantMap values;
    QString error;
    NetworkCredentials::Description description;
};
Cancellation cancellation();
void cancel(const Cancellation& token);
bool isCancelled(const Cancellation& token);
// Runs only on an independent QtConcurrent job. No QObject/application pointers
// or logging; facade-owned watchers receive results and never wait on teardown.
Result execute(const Job& job, const Cancellation& token);
}
