#pragma once
#include "CredentialStore.h"
namespace VpnUiHelper {
CredentialStore::Result describe(const CredentialStore::Job& job, const CredentialStore::Cancellation& cancel);
NetworkCredentials::Description parse(const QByteArray& output, const NetworkSettings& connection);
QByteArray input(const NetworkSettings& connection);
}
