// Include GLib before Qt's signals macro.
#include <libsecret/secret.h>
#include "CredentialStore.h"
#include "VpnUiHelper.h"

namespace CredentialStore {
namespace {
const SecretSchema Schema = {
    "org.freedesktop.NetworkManager.Connection", SECRET_SCHEMA_DONT_MATCH_NAME,
    {{"connection-uuid", SECRET_SCHEMA_ATTRIBUTE_STRING},
     {"setting-name", SECRET_SCHEMA_ATTRIBUTE_STRING},
     {"setting-key", SECRET_SCHEMA_ATTRIBUTE_STRING}, {nullptr, SECRET_SCHEMA_ATTRIBUTE_STRING}},
    0, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr
};
using Service = std::unique_ptr<SecretService, decltype(&g_object_unref)>;
using Value = std::unique_ptr<SecretValue, decltype(&secret_value_unref)>;
using Attributes = std::unique_ptr<GHashTable, decltype(&g_hash_table_unref)>;
Attributes attributes(const QString& uuid, const QString& setting = {}, const QString& key = {}) {
    Attributes out(g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free), &g_hash_table_unref);
    auto add = [&out](const char* name, const QString& value) {
        const auto bytes = value.toUtf8();
        g_hash_table_insert(out.get(), g_strdup(name), g_strndup(bytes.constData(), bytes.size()));
    };
    add("connection-uuid", uuid);
    if (!setting.isEmpty()) add("setting-name", setting);
    if (!key.isEmpty()) add("setting-key", key);
    return out;
}
Result failure(GError* error) {
    Result result;
    result.cancelled = error && g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED);
    // Provider errors can contain sensitive context; expose only a fixed message.
    result.error = result.cancelled ? "Credential storage request cancelled"
                                   : "The system password store is unavailable or locked";
    if (error) g_error_free(error);
    return result;
}
}
Cancellation cancellation() { return Cancellation(g_cancellable_new(), [](GCancellable* p) { g_object_unref(p); }); }
void cancel(const Cancellation& token) { if (token) g_cancellable_cancel(token.get()); }
bool isCancelled(const Cancellation& token) { return token && g_cancellable_is_cancelled(token.get()); }
Result execute(const Job& job, const Cancellation& token) {
    if (job.operation == Operation::DescribeVpn) return VpnUiHelper::describe(job, token);
    if (!token || job.uuid.isEmpty()) return failure(nullptr);
    GError* error = nullptr;
    Service service(secret_service_open_sync(SECRET_TYPE_SERVICE, nullptr, SECRET_SERVICE_OPEN_SESSION,
                                             token.get(), &error), &g_object_unref);
    if (!service) return failure(error);
    Result out;
    if (job.operation == Operation::Delete) {
        auto attrs = attributes(job.uuid);
        const bool ok = secret_service_clear_sync(service.get(), &Schema, attrs.get(), token.get(), &error);
        if (!ok) return failure(error);
    } else if (job.operation == Operation::Save) {
        for (auto it = job.values.cbegin(); it != job.values.cend(); ++it) {
            auto attrs = attributes(job.uuid, job.setting, it.key());
            if (it.value().toString().isEmpty()) {
                if (!secret_service_clear_sync(service.get(), &Schema, attrs.get(), token.get(), &error)) return failure(error);
                continue;
            }
            auto bytes = it.value().toString().toUtf8();
            SecretValue* value = secret_value_new(bytes.constData(), bytes.size(), "text/plain");
            bytes.fill('\0');
            const auto label = (job.label + " / " + job.setting + " / " + it.key()).toUtf8();
            const bool ok = secret_service_store_sync(service.get(), &Schema, attrs.get(),
                SECRET_COLLECTION_DEFAULT, label.constData(), value, token.get(), &error);
            secret_value_unref(value);
            if (!ok) return failure(error);
        }
    } else {
        for (const auto& key : job.keys) {
            auto attrs = attributes(job.uuid, job.setting, key);
            auto flags = static_cast<SecretSearchFlags>(SECRET_SEARCH_ALL | SECRET_SEARCH_LOAD_SECRETS
                | (job.allowInteraction ? SECRET_SEARCH_UNLOCK : SECRET_SEARCH_NONE));
            GList* list = secret_service_search_sync(service.get(), &Schema, attrs.get(), flags, token.get(), &error);
            if (error) { g_list_free_full(list, g_object_unref); return failure(error); }
            for (auto* item = list; item; item = item->next) {
                auto* secretItem = SECRET_ITEM(item->data);
                if (secret_item_get_locked(secretItem)) continue;
                Value value(secret_item_get_secret(secretItem), &secret_value_unref);
                if (!value) continue;
                gsize size = 0;
                const char* bytes = secret_value_get(value.get(), &size);
                if (bytes && size > 0 && size <= 16384) {
                    out.values.insert(key, QString::fromUtf8(bytes, static_cast<qsizetype>(size)));
                    break;
                }
            }
            g_list_free_full(list, g_object_unref);
        }
    }
    out.success = true;
    return out;
}
}
