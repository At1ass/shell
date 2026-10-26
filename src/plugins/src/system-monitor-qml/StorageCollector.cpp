#include "StorageCollector.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>
#include <algorithm>
#include <cmath>

namespace {
constexpr int maxVolumes = 128;
constexpr int maxDrives = 128;
constexpr int maxAliases = 64;

QByteArray readFile(const QString& path, qint64 limit = 1024 * 1024) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.read(limit) : QByteArray{};
}

QString unescape(const QByteArray& value) {
    QByteArray decoded;
    for (int i = 0; i < value.size(); ++i) {
        if (value[i] == '\\' && i + 3 < value.size()
            && value[i + 1] >= '0' && value[i + 1] <= '7'
            && value[i + 2] >= '0' && value[i + 2] <= '7'
            && value[i + 3] >= '0' && value[i + 3] <= '7') {
            decoded += char((value[i + 1] - '0') * 64 + (value[i + 2] - '0') * 8 + value[i + 3] - '0');
            i += 3;
        } else decoded += value[i];
    }
    return QString::fromUtf8(decoded);
}

int rank(const QString& path, const QStringList& order) {
    const int index = order.indexOf(path);
    return index < 0 ? order.size() : index;
}

QVariantMap optionsWithDefaults(const QVariantMap& options) {
    QVariantMap result = StorageCollector::defaultOptions();
    for (auto it = options.begin(); it != options.end(); ++it) result[it.key()] = it.value();
    auto threshold = [&](const QString& key, double fallback) {
        bool ok = false;
        const double value = result.value(key).toDouble(&ok);
        return ok && std::isfinite(value) ? std::clamp(value, 0.0, 100.0) : fallback;
    };
    const double warning = threshold(QStringLiteral("warningFreePercent"), 10);
    result[QStringLiteral("warningFreePercent")] = warning;
    result[QStringLiteral("criticalFreePercent")] = std::min(warning, threshold(QStringLiteral("criticalFreePercent"), 5));
    return result;
}
}

StorageCollector::StorageCollector(QString sysRoot)
    : m_sysRoot(std::move(sysRoot)), m_options(defaultOptions()) {}

QVariantMap StorageCollector::defaultOptions() {
    return {{QStringLiteral("warningFreePercent"), 10},
            {QStringLiteral("criticalFreePercent"), 5},
            {QStringLiteral("excludedMounts"), QStringList{QStringLiteral("/boot"), QStringLiteral("/boot/efi"), QStringLiteral("/efi")}},
            {QStringLiteral("order"), QStringList{QStringLiteral("/"), QStringLiteral("/home")}},
            {QStringLiteral("labels"), QVariantMap{}}};
}

void StorageCollector::setOptions(const QVariantMap& options) {
    m_options = optionsWithDefaults(options);
}

QString StorageCollector::formatBytes(double bytes) {
    if (!std::isfinite(bytes) || bytes < 0) return QStringLiteral("—");
    static const QStringList units{QStringLiteral("B"), QStringLiteral("KiB"), QStringLiteral("MiB"), QStringLiteral("GiB"), QStringLiteral("TiB"), QStringLiteral("PiB")};
    int unit = 0;
    while (bytes >= 1024 && unit < units.size() - 1) { bytes /= 1024; ++unit; }
    return QString::number(bytes, 'f', unit ? 1 : 0) + QLatin1Char(' ') + units[unit];
}
QString StorageCollector::formatSpeed(double bytes) { return formatBytes(bytes) + QStringLiteral("/s"); }

QList<StorageCollector::Mount> StorageCollector::parseMountInfo(const QByteArray& data) {
    QList<Mount> result;
    for (const auto& line : data.split('\n')) {
        const int separator = line.indexOf(" - ");
        if (separator < 0) continue;
        const auto left = line.left(separator).split(' ');
        const auto right = line.mid(separator + 3).split(' ');
        if (left.size() < 6 || right.size() < 3) continue;
        Mount mount{unescape(left[4]), unescape(right[1]), QString::fromUtf8(right[0]), left[5].split(',').contains("ro")};
        // Filter before stat calls: never traverse remote/automount/pseudo filesystems.
        const bool local = mount.source.startsWith(QStringLiteral("/dev/")) || mount.fileSystem == QStringLiteral("zfs");
        if (!local || !mount.path.startsWith(QLatin1Char('/')) || mount.source.startsWith(QStringLiteral("/dev/loop"))) continue;
        if (mount.fileSystem == QStringLiteral("autofs")) continue;
        result.append(mount);
        if (result.size() >= maxVolumes * maxAliases) break;
    }
    return result;
}

QVariantList StorageCollector::groupVolumes(const QList<Mount>& mounts, const Probe& probe, const QVariantMap& rawOptions) {
    const auto options = optionsWithDefaults(rawOptions);
    const auto excluded = options.value(QStringLiteral("excludedMounts")).toStringList();
    const auto order = options.value(QStringLiteral("order")).toStringList();
    const auto labels = options.value(QStringLiteral("labels")).toMap();
    QMap<QString, QList<Mount>> groups;
    for (const auto& mount : mounts) {
        if (excluded.contains(mount.path)) continue;
        const QString key = mount.fileSystem + QLatin1Char(':') + mount.source;
        if (!groups.contains(key) && groups.size() >= maxVolumes) continue;
        auto& aliases = groups[key];
        if (aliases.size() < maxAliases && std::none_of(aliases.begin(), aliases.end(), [&](const auto& item) { return item.path == mount.path; }))
            aliases.append(mount);
    }
    QVariantList result;
    for (auto it = groups.begin(); it != groups.end(); ++it) {
        auto aliases = it.value();
        std::sort(aliases.begin(), aliases.end(), [&](const auto& a, const auto& b) {
            if (a.readOnly != b.readOnly) return !a.readOnly;
            const int ar = rank(a.path, order), br = rank(b.path, order);
            return ar == br ? (a.path.size() == b.path.size() ? a.path < b.path : a.path.size() < b.path.size()) : ar < br;
        });
        const auto& primary = aliases.first();
        const Space space = probe(primary);
        const bool available = space.total > 0 && space.available >= 0;
        const qint64 free = available ? std::min(space.total, space.available) : 0;
        const double percent = available ? 100.0 * double(free) / space.total : 0;
        const bool readOnly = space.readOnly || std::all_of(aliases.begin(), aliases.end(), [](const auto& item) { return item.readOnly; });
        const int severity = !available || readOnly ? 0
            : percent <= options.value(QStringLiteral("criticalFreePercent")).toDouble() ? 2
            : percent <= options.value(QStringLiteral("warningFreePercent")).toDouble() ? 1 : 0;
        QStringList paths;
        for (const auto& mount : aliases) paths.append(mount.path);
        QString name = labels.value(primary.path).toString();
        if (name.isEmpty()) name = space.label;
        if (name.isEmpty()) name = primary.path == QStringLiteral("/") ? QStringLiteral("System") : primary.path;
        result.append(QVariantMap{{QStringLiteral("id"), it.key()}, {QStringLiteral("name"), name},
            {QStringLiteral("mountPoint"), primary.path}, {QStringLiteral("mountPoints"), paths},
            {QStringLiteral("device"), primary.source}, {QStringLiteral("fileSystem"), primary.fileSystem},
            {QStringLiteral("isRoot"), paths.contains(QStringLiteral("/"))}, {QStringLiteral("readOnly"), readOnly},
            {QStringLiteral("available"), available}, {QStringLiteral("bytesAvailable"), free},
            {QStringLiteral("bytesTotal"), available ? space.total : 0}, {QStringLiteral("freePercent"), percent},
            {QStringLiteral("usedFraction"), available ? 1.0 - percent / 100.0 : 0},
            {QStringLiteral("availableFormatted"), available ? formatBytes(free) : QStringLiteral("—")},
            {QStringLiteral("totalFormatted"), available ? formatBytes(space.total) : QStringLiteral("—")},
            {QStringLiteral("severity"), severity}});
    }
    std::sort(result.begin(), result.end(), [&](const auto& a, const auto& b) {
        const auto ap = a.toMap().value(QStringLiteral("mountPoint")).toString();
        const auto bp = b.toMap().value(QStringLiteral("mountPoint")).toString();
        const int ar = rank(ap, order), br = rank(bp, order);
        return ar == br ? ap < bp : ar < br;
    });
    return result;
}

void StorageCollector::discover() {
    auto mounts = parseMountInfo(readFile(QStringLiteral("/proc/self/mountinfo")));
    for (auto& mount : mounts) {
        if (mount.source.startsWith(QStringLiteral("/dev/"))) {
            const QString canonical = QFileInfo(mount.source).canonicalFilePath();
            if (!canonical.isEmpty()) mount.source = canonical;
        }
    }
    m_volumes = groupVolumes(mounts, [](const auto& mount) {
        const QStorageInfo info(mount.path);
        if (!info.isValid() || !info.isReady()) return Space{};
        return Space{info.bytesTotal(), info.bytesAvailable(), info.name(), info.isReadOnly()};
    }, m_options);
    QVariantList drives;
    const QDir blocks(m_sysRoot + QStringLiteral("/block"));
    const QDir hwmons(m_sysRoot + QStringLiteral("/class/hwmon"));
    for (const auto& name : blocks.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        if (name.startsWith(QStringLiteral("loop")) || name.startsWith(QStringLiteral("ram")) || name.startsWith(QStringLiteral("zram"))) continue;
        const QDir block(blocks.filePath(name));
        const QString canonical = QFileInfo(block.path()).canonicalFilePath();
        if (canonical.contains(QStringLiteral("/devices/virtual/")) || QFileInfo::exists(block.filePath(QStringLiteral("partition")))) continue;
        if (!QDir(block.filePath(QStringLiteral("slaves"))).entryList(QDir::Dirs | QDir::NoDotAndDotDot).isEmpty()) continue;
        if (readFile(block.filePath(QStringLiteral("size")), 128).trimmed().toULongLong() == 0) continue;
        QString model = QString::fromUtf8(readFile(block.filePath(QStringLiteral("device/model")), 512)).trimmed();
        if (model.isEmpty()) model = name;
        const QString devicePath = QFileInfo(block.filePath(QStringLiteral("device"))).canonicalFilePath();
        bool hasTemperature = false;
        int temperature = 0;
        for (const auto& sensor : hwmons.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            const QDir hwmon(hwmons.filePath(sensor));
            const QString sensorPath = QFileInfo(hwmon.path()).canonicalFilePath();
            if (devicePath.isEmpty() || !sensorPath.startsWith(devicePath + QLatin1Char('/'))) continue;
            for (const auto& input : hwmon.entryList({QStringLiteral("temp*_input")}, QDir::Files)) {
                bool ok = false;
                const int milli = readFile(hwmon.filePath(input), 128).trimmed().toInt(&ok);
                if (!ok || milli < -40000 || milli > 200000) continue;
                temperature = hasTemperature ? std::max(temperature, milli / 1000) : milli / 1000;
                hasTemperature = true;
            }
        }
        drives.append(QVariantMap{{QStringLiteral("id"), name}, {QStringLiteral("device"), QStringLiteral("/dev/") + name},
            {QStringLiteral("name"), model}, {QStringLiteral("removable"), readFile(block.filePath(QStringLiteral("removable")), 128).trimmed() == "1" || canonical.contains(QStringLiteral("/usb"))},
            {QStringLiteral("hasTemperature"), hasTemperature}, {QStringLiteral("temperature"), temperature},
            {QStringLiteral("hasIo"), false}, {QStringLiteral("readSpeed"), 0.0}, {QStringLiteral("writeSpeed"), 0.0},
            {QStringLiteral("readFormatted"), formatSpeed(0)}, {QStringLiteral("writeFormatted"), formatSpeed(0)}});
        if (drives.size() >= maxDrives) break;
    }
    m_drives = drives;
}

void StorageCollector::resetIo() { m_previous.clear(); }

void StorageCollector::sampleIo(const QByteArray& data, double elapsedSeconds) {
    QHash<QString, Counters> current;
    for (const auto& line : data.split('\n')) {
        const auto fields = line.simplified().split(' ');
        if (fields.size() < 10) continue;
        bool readOk = false, writeOk = false;
        const quint64 read = fields[5].toULongLong(&readOk), write = fields[9].toULongLong(&writeOk);
        if (!readOk || !writeOk) continue;
        const QString name = QString::fromUtf8(fields[2]);
        // Only keep whole leaf devices discovered in sysfs, never partitions or dm/md parents.
        if (std::none_of(m_drives.begin(), m_drives.end(), [&](const auto& drive) { return drive.toMap().value(QStringLiteral("id")).toString() == name; })) continue;
        const QString seq = QString::fromUtf8(readFile(m_sysRoot + QStringLiteral("/block/") + name + QStringLiteral("/diskseq"), 128)).trimmed();
        current.insert(name, Counters{read, write, QString::fromUtf8(fields[0] + ':' + fields[1]) + QLatin1Char(':') + seq});
    }
    m_readSpeed = m_writeSpeed = 0;
    m_hasIo = false;
    for (auto& variant : m_drives) {
        auto drive = variant.toMap();
        const QString name = drive.value(QStringLiteral("id")).toString();
        const bool hasIo = current.contains(name);
        double read = 0, write = 0;
        if (hasIo && m_previous.contains(name) && std::isfinite(elapsedSeconds) && elapsedSeconds > 0) {
            const auto& now = current[name];
            const auto& before = m_previous[name];
            if (now.generation == before.generation && now.read >= before.read && now.write >= before.write) {
                // Kernel diskstats sectors are always 512 bytes, irrespective of device block size.
                read = double(now.read - before.read) * 512.0 / elapsedSeconds;
                write = double(now.write - before.write) * 512.0 / elapsedSeconds;
            }
        }
        drive[QStringLiteral("hasIo")] = hasIo;
        drive[QStringLiteral("readSpeed")] = read;
        drive[QStringLiteral("writeSpeed")] = write;
        drive[QStringLiteral("readFormatted")] = hasIo ? formatSpeed(read) : QStringLiteral("—");
        drive[QStringLiteral("writeFormatted")] = hasIo ? formatSpeed(write) : QStringLiteral("—");
        variant = drive;
        m_readSpeed += read;
        m_writeSpeed += write;
        m_hasIo |= hasIo;
    }
    m_previous = current;
}

QVariantMap StorageCollector::summarizeVolumes(const QVariantList& volumes) {
    QVariantMap selected;
    int warnings = 0, critical = 0;
    for (const auto& variant : volumes) {
        const auto volume = variant.toMap();
        if (!volume.value(QStringLiteral("available")).toBool()) continue;
        const int severity = volume.value(QStringLiteral("severity")).toInt();
        warnings += severity == 1;
        critical += severity == 2;
        const int previous = selected.value(QStringLiteral("severity")).toInt();
        if (selected.isEmpty() || severity > previous
            || (severity > 0 && severity == previous && volume.value(QStringLiteral("freePercent")).toDouble() < selected.value(QStringLiteral("freePercent")).toDouble())
            || (severity == 0 && previous == 0 && volume.value(QStringLiteral("isRoot")).toBool())) selected = volume;
    }
    selected[QStringLiteral("available")] = !selected.isEmpty();
    selected[QStringLiteral("warningCount")] = warnings;
    selected[QStringLiteral("criticalCount")] = critical;
    return selected;
}

QVariantMap StorageCollector::summary() const {
    auto selected = summarizeVolumes(m_volumes);
    selected[QStringLiteral("hasIo")] = m_hasIo;
    selected[QStringLiteral("readFormatted")] = m_hasIo ? formatSpeed(m_readSpeed) : QStringLiteral("—");
    selected[QStringLiteral("writeFormatted")] = m_hasIo ? formatSpeed(m_writeSpeed) : QStringLiteral("—");
    return selected;
}
