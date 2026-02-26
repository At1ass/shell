#include "SystemMonitor.h"

#include <QtCore/QFile>
#include <QtCore/QRegularExpression>
#include <QtCore/QDir>
#include <QtCore/QTextStream>
#include <QtCore/QLibrary>
#include <QtCore/QStandardPaths>
#include <QtCore/QMetaType>
#include <QtCore/QTimer>
#include <memory>

#include <unistd.h>
#include <fcntl.h>
#include <sys/sysinfo.h>
#include <sys/statvfs.h>
#include <pwd.h>
#include <cerrno>
#include <cstring>
#include <optional>
#include <cmath>

#ifdef HAVE_LIBSENSORS
#include <sensors/sensors.h>
#endif

// Worker that collects metrics in a separate thread
class StatsWorker : public QObject {
    Q_OBJECT
public:
    StatsWorker();
    ~StatsWorker() override;

public slots:
    void setFastInterval(int ms);
    void refreshNow();
    void setCpuModel(const QString& model) { m_cpuModel = model; }
    void setGpuModel(const QString& model) { m_gpuModel = model; }
    void startTimers();

signals:
    void snapshotReady(const StatsSnapshot& snapshot);
    void errorOccurred(const QString& message);

private:
    void openProcFiles();
    void closeProcFiles();
    bool readProcFile(int fd, char* buffer, size_t bufferSize);
    QString formatBytes(double bytes);
    QString formatSpeed(double bytesPerSec);
    std::optional<int> readCpuTempSysfs();

    // NVML dynamic loader
    struct NvmlApi {
        using Init_t = int (*)();
        using Shutdown_t = int (*)();
        using DeviceGetHandleByIndex_t = int (*)(unsigned int, void**);
        using DeviceGetUtilizationRates_t = int (*)(void*, void*);
        using DeviceGetTemperature_t = int (*)(void*, unsigned int, unsigned int*);
        using DeviceGetName_t = int (*)(void*, char*, unsigned int);
        using DeviceGetMemoryInfo_t = int (*)(void*, void*);
        using DeviceGetClockInfo_t = int (*)(void*, unsigned int, unsigned int*);
        using DeviceGetFanSpeed_t = int (*)(void*, unsigned int*);
        using DeviceGetPowerUsage_t = int (*)(void*, unsigned int*);

        QLibrary lib;
        Init_t init = nullptr;
        Shutdown_t shutdown = nullptr;
        DeviceGetHandleByIndex_t deviceGetHandleByIndex = nullptr;
        DeviceGetUtilizationRates_t deviceGetUtilizationRates = nullptr;
        DeviceGetTemperature_t deviceGetTemperature = nullptr;
        DeviceGetName_t deviceGetName = nullptr;
        // Extended (nullable)
        DeviceGetMemoryInfo_t deviceGetMemoryInfo = nullptr;
        DeviceGetClockInfo_t deviceGetClockInfo = nullptr;
        DeviceGetFanSpeed_t deviceGetFanSpeed = nullptr;
        DeviceGetPowerUsage_t deviceGetPowerUsage = nullptr;
        bool ready = false;

        bool ensureLoaded() {
            if (ready) return true;
            lib.setFileName(QStringLiteral("nvidia-ml"));
            if (!lib.load())
                return false;
            init = reinterpret_cast<Init_t>(lib.resolve("nvmlInit_v2"));
            shutdown = reinterpret_cast<Shutdown_t>(lib.resolve("nvmlShutdown"));
            deviceGetHandleByIndex = reinterpret_cast<DeviceGetHandleByIndex_t>(lib.resolve("nvmlDeviceGetHandleByIndex_v2"));
            deviceGetUtilizationRates = reinterpret_cast<DeviceGetUtilizationRates_t>(lib.resolve("nvmlDeviceGetUtilizationRates"));
            deviceGetTemperature = reinterpret_cast<DeviceGetTemperature_t>(lib.resolve("nvmlDeviceGetTemperature"));
            deviceGetName = reinterpret_cast<DeviceGetName_t>(lib.resolve("nvmlDeviceGetName"));
            if (!init || !shutdown || !deviceGetHandleByIndex || !deviceGetUtilizationRates || !deviceGetTemperature || !deviceGetName)
                return false;
            // Extended functions — each may be null, that's ok
            deviceGetMemoryInfo = reinterpret_cast<DeviceGetMemoryInfo_t>(lib.resolve("nvmlDeviceGetMemoryInfo"));
            deviceGetClockInfo = reinterpret_cast<DeviceGetClockInfo_t>(lib.resolve("nvmlDeviceGetClockInfo"));
            deviceGetFanSpeed = reinterpret_cast<DeviceGetFanSpeed_t>(lib.resolve("nvmlDeviceGetFanSpeed"));
            deviceGetPowerUsage = reinterpret_cast<DeviceGetPowerUsage_t>(lib.resolve("nvmlDeviceGetPowerUsage"));
            ready = (init() == 0);
            return ready;
        }

        void shutdownIfReady() {
            if (ready && shutdown) shutdown();
            ready = false;
        }
    } m_nvml;

    struct NvmlUtilization {
        unsigned int gpu;
        unsigned int memory;
    };

    struct NvmlMemory {
        uint64_t total;
        uint64_t free;
        uint64_t used;
    };

    std::optional<std::pair<int, int>> readGpuNvml();
    std::optional<QString> readGpuNameNvml();
    void readGpuExtendedNvml(StatsSnapshot& snapshot);
    void readGpuAmd(StatsSnapshot& snapshot);
    void detectGpuBackend();
    void initSensors();

    void pollFast();
    void pollSlow();
    void updateCpu(StatsSnapshot& snapshot);
    void updateCpuFreq(StatsSnapshot& snapshot);
    void updateRam(StatsSnapshot& snapshot);
    void updateDisk(StatsSnapshot& snapshot);
    void updateNetwork(StatsSnapshot& snapshot);
    void updateDiskIo(StatsSnapshot& snapshot);
    void updateLoadAvg();

    void detectNetInterface();
    void detectDiskDevice();
    uint64_t readSysfsUint64(const QString& path);

    int m_cpuStatFd = -1;
    int m_meminfoFd = -1;
    int m_loadavgFd = -1;
    int m_diskstatsFd = -1;
    uint64_t m_lastCpuIdle = 0;
    uint64_t m_lastCpuTotal = 0;
    char m_cpuBuffer[2048];
    char m_memBuffer[4096];
    char m_loadavgBuffer[128];
    char m_diskstatsBuffer[8192];
    QTimer m_fastTimer;
    QTimer m_slowTimer;
    QString m_cpuModel;
    QString m_gpuModel;
    QString m_gpuModelNvml;
    std::optional<int> m_lastCpuTemp;
    std::optional<std::pair<int, int>> m_lastGpu;

    // Network state
    uint64_t m_prevRxBytes = 0, m_prevTxBytes = 0;
    bool m_netFirstTick = true;
    QString m_netInterface;
    int m_netRedetectCounter = 0;

    // Disk I/O state
    uint64_t m_prevReadSectors = 0, m_prevWriteSectors = 0;
    bool m_diskIoFirstTick = true;
    QString m_diskDevice;

    // GPU backend
    GpuBackend m_gpuBackend = GpuBackend::None;
    QString m_amdGpuPath, m_amdHwmonPath;

    // Cached slow-poll values
    qreal m_lastLoadAvg1 = 0, m_lastLoadAvg5 = 0, m_lastLoadAvg15 = 0;
    int m_lastGpuClockMHz = 0, m_lastGpuFanSpeed = 0, m_lastGpuPowerWatts = 0;
    qreal m_lastGpuMemUsage = 0;
    QString m_lastGpuMemUsed, m_lastGpuMemTotal;

#ifdef HAVE_LIBSENSORS
    std::optional<int> readCpuTempSensors();
    bool m_sensorsReady = false;
    sensors_chip_name m_chip = {};
    int m_tempSubfeature = -1;
#endif
};

SystemMonitor::SystemMonitor(QObject* parent)
    : QObject(parent)
{
    qRegisterMetaType<StatsSnapshot>("StatsSnapshot");

    initializeStaticInfo();

    m_worker = new StatsWorker;
    m_worker->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &StatsWorker::snapshotReady, this, &SystemMonitor::handleSnapshot, Qt::QueuedConnection);
    connect(m_worker, &StatsWorker::errorOccurred, this, &SystemMonitor::errorOccurred, Qt::QueuedConnection);

    // Pass static values to the worker
    QMetaObject::invokeMethod(m_worker, "setCpuModel", Qt::QueuedConnection, Q_ARG(QString, m_cpuModel));
    QMetaObject::invokeMethod(m_worker, "setGpuModel", Qt::QueuedConnection, Q_ARG(QString, m_gpuModel));

    m_workerThread.start();
    QMetaObject::invokeMethod(m_worker, "startTimers", Qt::QueuedConnection);
    m_isMonitoring = true;
    emit isMonitoringChanged();
}

SystemMonitor::~SystemMonitor()
{
    stopWorker();
}

void SystemMonitor::setUpdateInterval(int milliseconds)
{
    if (milliseconds < 500) {
        qWarning() << "SystemMonitor: Update interval too small, using 500ms";
        milliseconds = 500;
    }
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "setFastInterval", Qt::QueuedConnection, Q_ARG(int, milliseconds));
    }
}

void SystemMonitor::refresh()
{
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "refreshNow", Qt::QueuedConnection);
    }
}

// ─── StatsWorker implementation ─────────────────────────────────────────────

StatsWorker::StatsWorker() {
    openProcFiles();
    initSensors();
    detectGpuBackend();
    detectNetInterface();
    detectDiskDevice();

    m_fastTimer.setParent(this);
    m_slowTimer.setParent(this);

    m_fastTimer.setInterval(2000);
    m_fastTimer.setSingleShot(false);
    connect(&m_fastTimer, &QTimer::timeout, this, &StatsWorker::pollFast);

    m_slowTimer.setInterval(5000);
    m_slowTimer.setSingleShot(false);
    connect(&m_slowTimer, &QTimer::timeout, this, &StatsWorker::pollSlow);
}

StatsWorker::~StatsWorker() {
    closeProcFiles();
    m_nvml.shutdownIfReady();
#ifdef HAVE_LIBSENSORS
    if (m_sensorsReady) {
        sensors_cleanup();
        m_sensorsReady = false;
    }
#endif
}

void StatsWorker::setFastInterval(int ms) {
    if (ms < 500) ms = 500;
    m_fastTimer.setInterval(ms);
}

void StatsWorker::refreshNow() {
    pollFast();
    pollSlow();
}

void StatsWorker::startTimers() {
    // Initial collection so UI doesn't see zeroes
    pollSlow();
    pollFast();

    if (!m_fastTimer.isActive()) m_fastTimer.start();
    if (!m_slowTimer.isActive()) m_slowTimer.start();
}

void StatsWorker::openProcFiles() {
    m_cpuStatFd = open("/proc/stat", O_RDONLY);
    if (m_cpuStatFd < 0) {
        emit errorOccurred(QStringLiteral("Failed to open /proc/stat"));
    }

    m_meminfoFd = open("/proc/meminfo", O_RDONLY);
    if (m_meminfoFd < 0) {
        emit errorOccurred(QStringLiteral("Failed to open /proc/meminfo"));
    }

    m_loadavgFd = open("/proc/loadavg", O_RDONLY);
    m_diskstatsFd = open("/proc/diskstats", O_RDONLY);
}

void StatsWorker::closeProcFiles() {
    if (m_cpuStatFd >= 0) { close(m_cpuStatFd); m_cpuStatFd = -1; }
    if (m_meminfoFd >= 0) { close(m_meminfoFd); m_meminfoFd = -1; }
    if (m_loadavgFd >= 0) { close(m_loadavgFd); m_loadavgFd = -1; }
    if (m_diskstatsFd >= 0) { close(m_diskstatsFd); m_diskstatsFd = -1; }
}

bool StatsWorker::readProcFile(int fd, char* buffer, size_t bufferSize) {
    if (fd < 0 || !buffer || bufferSize == 0) {
        return false;
    }
    if (lseek(fd, 0, SEEK_SET) < 0) {
        return false;
    }
    ssize_t bytesRead = read(fd, buffer, bufferSize - 1);
    if (bytesRead < 0) {
        return false;
    }
    buffer[bytesRead] = '\0';
    return true;
}

QString StatsWorker::formatBytes(double bytes) {
    const char* units[] = {"B", "KB", "MB", "GB", "TB"};
    int unitIndex = 0;
    while (bytes >= 1024.0 && unitIndex < 4) {
        bytes /= 1024.0;
        unitIndex++;
    }
    if (unitIndex >= 3) {
        return QString::number(bytes, 'f', 1) + units[unitIndex];
    }
    return QString::number(qRound(bytes)) + units[unitIndex];
}

QString StatsWorker::formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024.0)
        return QString::number(qRound(bytesPerSec)) + QStringLiteral(" B/s");
    if (bytesPerSec < 1024.0 * 1024.0)
        return QString::number(bytesPerSec / 1024.0, 'f', 1) + QStringLiteral(" KB/s");
    if (bytesPerSec < 1024.0 * 1024.0 * 1024.0)
        return QString::number(bytesPerSec / (1024.0 * 1024.0), 'f', 1) + QStringLiteral(" MB/s");
    return QString::number(bytesPerSec / (1024.0 * 1024.0 * 1024.0), 'f', 2) + QStringLiteral(" GB/s");
}

uint64_t StatsWorker::readSysfsUint64(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return 0;
    bool ok = false;
    uint64_t val = QString::fromUtf8(f.readAll()).trimmed().toULongLong(&ok);
    return ok ? val : 0;
}

// ─── GPU backend detection ──────────────────────────────────────────────────

void StatsWorker::detectGpuBackend() {
    QDir drmDir(QStringLiteral("/sys/class/drm"));
    const auto cards = drmDir.entryList(QStringList() << QStringLiteral("card[0-9]*"), QDir::Dirs | QDir::NoDotAndDotDot);

    // Scan all cards first, prefer discrete (Nvml) over integrated (AmdSysfs)
    bool foundAmd = false;
    QString amdGpuPath, amdHwmonPath;

    for (const auto& card : cards) {
        // Skip output nodes like card0-HDMI-A-1, card0-DP-1
        if (card.contains('-'))
            continue;

        QString vendorPath = drmDir.absoluteFilePath(card + QStringLiteral("/device/vendor"));
        QFile vendorFile(vendorPath);
        if (!vendorFile.open(QIODevice::ReadOnly))
            continue;
        QString vendor = QString::fromUtf8(vendorFile.readAll()).trimmed();

        if (vendor == QStringLiteral("0x10de")) {
            // NVIDIA found — always prefer NVML, return immediately
            m_gpuBackend = GpuBackend::Nvml;
            return;
        }
        if (!foundAmd && (vendor == QStringLiteral("0x1002") || vendor == QStringLiteral("0x1022"))) {
            // Remember AMD as fallback, but keep scanning for NVIDIA
            foundAmd = true;
            amdGpuPath = drmDir.absoluteFilePath(card + QStringLiteral("/device"));

            QDir hwmonDir(amdGpuPath + QStringLiteral("/hwmon"));
            const auto hwmons = hwmonDir.entryList(QStringList() << QStringLiteral("hwmon*"), QDir::Dirs | QDir::NoDotAndDotDot);
            if (!hwmons.isEmpty()) {
                amdHwmonPath = hwmonDir.absoluteFilePath(hwmons.first());
            }
        }
    }

    // No NVIDIA found — use AMD if available
    if (foundAmd) {
        m_gpuBackend = GpuBackend::AmdSysfs;
        m_amdGpuPath = amdGpuPath;
        m_amdHwmonPath = amdHwmonPath;
    } else {
        m_gpuBackend = GpuBackend::None;
    }
}

// ─── Network interface auto-detection ───────────────────────────────────────

void StatsWorker::detectNetInterface() {
    QDir netDir(QStringLiteral("/sys/class/net"));
    const auto ifaces = netDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    QString bestIface;
    uint64_t bestRx = 0;

    for (const auto& iface : ifaces) {
        // Skip virtual interfaces
        if (iface == QStringLiteral("lo") ||
            iface.startsWith(QStringLiteral("docker")) ||
            iface.startsWith(QStringLiteral("veth")) ||
            iface.startsWith(QStringLiteral("br-")) ||
            iface.startsWith(QStringLiteral("virbr")))
            continue;

        uint64_t rx = readSysfsUint64(netDir.absoluteFilePath(iface + QStringLiteral("/statistics/rx_bytes")));
        if (rx > bestRx) {
            bestRx = rx;
            bestIface = iface;
        }
    }
    m_netInterface = bestIface;
}

// ─── Disk device auto-detection ─────────────────────────────────────────────

void StatsWorker::detectDiskDevice() {
    QFile mounts(QStringLiteral("/proc/mounts"));
    if (!mounts.open(QIODevice::ReadOnly))
        return;

    while (!mounts.atEnd()) {
        const QByteArray line = mounts.readLine();
        const auto parts = line.split(' ');
        if (parts.size() < 2)
            continue;
        if (parts.at(1) != "/")
            continue;
        QString dev = QString::fromUtf8(parts.at(0));
        // e.g. /dev/nvme0n1p2 → nvme0n1, /dev/sda1 → sda
        dev = dev.mid(dev.lastIndexOf('/') + 1);
        // Strip partition: nvme0n1p2 → nvme0n1
        static QRegularExpression nvmePartRe(QStringLiteral("^(nvme\\d+n\\d+)p\\d+$"));
        auto m = nvmePartRe.match(dev);
        if (m.hasMatch()) {
            m_diskDevice = m.captured(1);
            return;
        }
        // sda1 → sda
        static QRegularExpression sdPartRe(QStringLiteral("^(sd[a-z]+)\\d+$"));
        m = sdPartRe.match(dev);
        if (m.hasMatch()) {
            m_diskDevice = m.captured(1);
            return;
        }
        // mmcblk0p1 → mmcblk0
        static QRegularExpression mmcPartRe(QStringLiteral("^(mmcblk\\d+)p\\d+$"));
        m = mmcPartRe.match(dev);
        if (m.hasMatch()) {
            m_diskDevice = m.captured(1);
            return;
        }
        // Fallback: use as-is
        m_diskDevice = dev;
        return;
    }
}

// ─── CPU temperature ────────────────────────────────────────────────────────

std::optional<int> StatsWorker::readCpuTempSysfs() {
    // thermal_zone*: take the best matching one
    QDir thermalDir(QStringLiteral("/sys/class/thermal"));
    const auto zones = thermalDir.entryList(QStringList() << "thermal_zone*", QDir::Dirs | QDir::NoDotAndDotDot);
    int best = 0;
    for (const auto& zone : zones) {
        QFile typeFile(thermalDir.absoluteFilePath(zone + "/type"));
        QString type;
        if (typeFile.open(QIODevice::ReadOnly))
            type = QString::fromUtf8(typeFile.readAll()).trimmed();

        QFile tempFile(thermalDir.absoluteFilePath(zone + "/temp"));
        if (!tempFile.open(QIODevice::ReadOnly)) continue;
        bool ok = false;
        const int milli = QString::fromUtf8(tempFile.readAll()).trimmed().toInt(&ok);
        if (!ok) continue;
        const int celsius = milli / 1000;

        const bool likelyCpu = type.contains("cpu", Qt::CaseInsensitive)
                            || type.contains("tctl", Qt::CaseInsensitive)
                            || type.contains("package", Qt::CaseInsensitive);
        if (likelyCpu || best == 0 || celsius > best)
            best = celsius;
    }
    if (best > 0) return best;

    // hwmon temp*_label
    QDir hwmonDir(QStringLiteral("/sys/class/hwmon"));
    const auto hwmons = hwmonDir.entryList(QStringList() << "hwmon*", QDir::Dirs | QDir::NoDotAndDotDot);
    auto scoreLabel = [](const QString& label)->int {
        QString lower = label.toLower();
        if (lower.contains("tctl") || lower.contains("tdie") || lower.contains("tctrl")) return 3;
        if (lower.contains("package") || lower.contains("cpu")) return 2;
        if (lower.contains("core")) return 1;
        return 0;
    };

    int bestScore = -1;
    int bestTemp = 0;
    for (const auto& hw : hwmons) {
        QDir d(hwmonDir.absoluteFilePath(hw));
        const auto temps = d.entryList(QStringList() << "temp*_input", QDir::Files);
        for (const auto& t : temps) {
            const QString base = t.left(t.size() - QStringLiteral("_input").size());
            QFile inputFile(d.absoluteFilePath(t));
            if (!inputFile.open(QIODevice::ReadOnly)) continue;
            bool ok = false;
            const int milli = QString::fromUtf8(inputFile.readAll()).trimmed().toInt(&ok);
            if (!ok) continue;
            const int celsius = milli / 1000;

            QString labelText;
            QFile labelFile(d.absoluteFilePath(base + "_label"));
            if (labelFile.open(QIODevice::ReadOnly)) {
                labelText = QString::fromUtf8(labelFile.readAll()).trimmed();
            }
            const int score = scoreLabel(labelText);
            if (score > bestScore || (score == bestScore && celsius > bestTemp)) {
                bestScore = score;
                bestTemp = celsius;
            }
        }
    }
    if (bestTemp > 0) return bestTemp;

    return std::nullopt;
}

#ifdef HAVE_LIBSENSORS
void StatsWorker::initSensors() {
    if (m_sensorsReady)
        return;
    if (sensors_init(nullptr) != 0)
        return;

    const sensors_chip_name* chip;
    int c = 0;
    int bestScore = -1;
    int bestSub = -1;
    sensors_chip_name bestChip{};

    auto scoreLabel = [](const char* label)->int {
        if (!label) return 0;
        QString l = QString::fromUtf8(label).toLower();
        if (l.contains("tctl") || l.contains("tdie") || l.contains("package")) return 3;
        if (l.contains("cpu")) return 2;
        if (l.contains("core")) return 1;
        return 0;
    };

    while ((chip = sensors_get_detected_chips(nullptr, &c)) != nullptr) {
        int f = 0;
        const sensors_feature* feature;
        while ((feature = sensors_get_features(chip, &f)) != nullptr) {
            if (feature->type != SENSORS_FEATURE_TEMP)
                continue;
            int s = 0;
            const sensors_subfeature* sub;
            while ((sub = sensors_get_all_subfeatures(chip, feature, &s)) != nullptr) {
                if (sub->type != SENSORS_SUBFEATURE_TEMP_INPUT)
                    continue;
                const sensors_subfeature* labelSub = sensors_get_subfeature(chip, feature, SENSORS_SUBFEATURE_TEMP_TYPE);
                std::unique_ptr<char, decltype(&free)> labelPtr(
                    labelSub ? sensors_get_label(chip, feature) : nullptr, &free);
                const char* label = labelPtr.get();
                int sc = scoreLabel(label);
                if (sc > bestScore) {
                    bestScore = sc;
                    bestSub = sub->number;
                    bestChip = *chip;
                }
            }
        }
    }

    if (bestSub >= 0) {
        m_tempSubfeature = bestSub;
        m_chip = bestChip;
        m_sensorsReady = true;
    } else {
        sensors_cleanup();
    }
}

std::optional<int> StatsWorker::readCpuTempSensors() {
    if (!m_sensorsReady)
        return std::nullopt;
    double val = 0.0;
    if (sensors_get_value(&m_chip, m_tempSubfeature, &val) == 0) {
        return static_cast<int>(std::lround(val));
    }
    return std::nullopt;
}
#endif

#ifndef HAVE_LIBSENSORS
void StatsWorker::initSensors() {}
#endif

// ─── NVIDIA GPU via NVML ────────────────────────────────────────────────────

std::optional<std::pair<int, int>> StatsWorker::readGpuNvml() {
    if (!m_nvml.ensureLoaded())
        return std::nullopt;
    void* device = nullptr;
    if (m_nvml.deviceGetHandleByIndex(0, &device) != 0)
        return std::nullopt;
    NvmlUtilization util{};
    if (m_nvml.deviceGetUtilizationRates(device, &util) != 0)
        return std::nullopt;
    unsigned int temp = 0;
    if (m_nvml.deviceGetTemperature(device, 0 /*GPU*/, &temp) != 0)
        temp = 0;
    return std::make_pair(static_cast<int>(util.gpu), static_cast<int>(temp));
}

std::optional<QString> StatsWorker::readGpuNameNvml() {
    if (!m_nvml.ensureLoaded())
        return std::nullopt;
    void* device = nullptr;
    if (m_nvml.deviceGetHandleByIndex(0, &device) != 0)
        return std::nullopt;
    char nameBuf[96] = {0};
    if (m_nvml.deviceGetName(device, nameBuf, sizeof(nameBuf)) != 0)
        return std::nullopt;
    QString name = QString::fromUtf8(nameBuf).trimmed();
    name.replace("NVIDIA", "", Qt::CaseInsensitive);
    name.replace("GeForce", "", Qt::CaseInsensitive);
    name.replace("Graphics", "", Qt::CaseInsensitive);
    name = name.simplified();
    return name;
}

void StatsWorker::readGpuExtendedNvml(StatsSnapshot& snapshot) {
    if (!m_nvml.ready)
        return;
    void* device = nullptr;
    if (m_nvml.deviceGetHandleByIndex(0, &device) != 0)
        return;

    // Memory info
    if (m_nvml.deviceGetMemoryInfo) {
        NvmlMemory mem{};
        if (m_nvml.deviceGetMemoryInfo(device, &mem) == 0 && mem.total > 0) {
            snapshot.gpuMemUsage = static_cast<qreal>(mem.used) * 100.0 / mem.total;
            snapshot.gpuMemUsed = formatBytes(static_cast<double>(mem.used));
            snapshot.gpuMemTotal = formatBytes(static_cast<double>(mem.total));
        }
    }

    // Clock (graphics clock = type 0)
    if (m_nvml.deviceGetClockInfo) {
        unsigned int clockMHz = 0;
        if (m_nvml.deviceGetClockInfo(device, 0, &clockMHz) == 0) {
            snapshot.gpuClockMHz = static_cast<int>(clockMHz);
        }
    }

    // Fan speed
    if (m_nvml.deviceGetFanSpeed) {
        unsigned int fan = 0;
        if (m_nvml.deviceGetFanSpeed(device, &fan) == 0) {
            snapshot.gpuFanSpeed = static_cast<int>(fan);
        }
    }

    // Power usage (returned in milliwatts)
    if (m_nvml.deviceGetPowerUsage) {
        unsigned int powerMw = 0;
        if (m_nvml.deviceGetPowerUsage(device, &powerMw) == 0) {
            snapshot.gpuPowerWatts = static_cast<int>(powerMw / 1000);
        }
    }
}

// ─── AMD GPU via sysfs ──────────────────────────────────────────────────────

void StatsWorker::readGpuAmd(StatsSnapshot& snapshot) {
    if (m_amdGpuPath.isEmpty())
        return;

    // GPU usage %
    {
        QFile f(m_amdGpuPath + QStringLiteral("/gpu_busy_percent"));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            int val = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
            if (ok) snapshot.gpuUsage = val;
        }
    }

    // VRAM
    {
        uint64_t used = readSysfsUint64(m_amdGpuPath + QStringLiteral("/mem_info_vram_used"));
        uint64_t total = readSysfsUint64(m_amdGpuPath + QStringLiteral("/mem_info_vram_total"));
        if (total > 0) {
            snapshot.gpuMemUsage = static_cast<qreal>(used) * 100.0 / total;
            snapshot.gpuMemUsed = formatBytes(static_cast<double>(used));
            snapshot.gpuMemTotal = formatBytes(static_cast<double>(total));
        }
    }

    if (m_amdHwmonPath.isEmpty())
        return;

    // Temperature (milli°C)
    {
        QFile f(m_amdHwmonPath + QStringLiteral("/temp1_input"));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            int milli = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
            if (ok) snapshot.gpuTemp = milli / 1000;
        }
    }

    // Clock (freq1_input in Hz → MHz)
    {
        QFile f(m_amdHwmonPath + QStringLiteral("/freq1_input"));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            uint64_t hz = QString::fromUtf8(f.readAll()).trimmed().toULongLong(&ok);
            if (ok) snapshot.gpuClockMHz = static_cast<int>(hz / 1000000);
        }
    }

    // Power (power1_average in μW → W)
    {
        QFile f(m_amdHwmonPath + QStringLiteral("/power1_average"));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            uint64_t uW = QString::fromUtf8(f.readAll()).trimmed().toULongLong(&ok);
            if (ok) snapshot.gpuPowerWatts = static_cast<int>(uW / 1000000);
        }
    }

    // Fan speed (pwm1 → percentage: pwm1_max is typically 255)
    {
        QFile f(m_amdHwmonPath + QStringLiteral("/pwm1"));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            int pwm = QString::fromUtf8(f.readAll()).trimmed().toInt(&ok);
            if (ok) snapshot.gpuFanSpeed = pwm * 100 / 255;
        }
    }
}

// ─── CPU frequency ──────────────────────────────────────────────────────────

void StatsWorker::updateCpuFreq(StatsSnapshot& snapshot) {
    QDir cpuDir(QStringLiteral("/sys/devices/system/cpu"));
    const auto cpus = cpuDir.entryList(QStringList() << QStringLiteral("cpu[0-9]*"), QDir::Dirs | QDir::NoDotAndDotDot);

    double totalFreqKHz = 0;
    int count = 0;
    for (const auto& cpu : cpus) {
        QFile f(cpuDir.absoluteFilePath(cpu + QStringLiteral("/cpufreq/scaling_cur_freq")));
        if (!f.open(QIODevice::ReadOnly))
            continue;
        bool ok = false;
        double khz = QString::fromUtf8(f.readAll()).trimmed().toDouble(&ok);
        if (ok) {
            totalFreqKHz += khz;
            count++;
        }
    }
    if (count > 0) {
        snapshot.cpuFreqGHz = (totalFreqKHz / count) / 1000000.0;
    }
}

// ─── Load average ───────────────────────────────────────────────────────────

void StatsWorker::updateLoadAvg() {
    if (m_loadavgFd < 0)
        return;
    if (!readProcFile(m_loadavgFd, m_loadavgBuffer, sizeof(m_loadavgBuffer)))
        return;
    float l1 = 0, l5 = 0, l15 = 0;
    if (sscanf(m_loadavgBuffer, "%f %f %f", &l1, &l5, &l15) == 3) {
        m_lastLoadAvg1 = l1;
        m_lastLoadAvg5 = l5;
        m_lastLoadAvg15 = l15;
    }
}

// ─── Network speed ──────────────────────────────────────────────────────────

void StatsWorker::updateNetwork(StatsSnapshot& snapshot) {
    if (m_netInterface.isEmpty()) {
        snapshot.hasNet = false;
        return;
    }

    QString basePath = QStringLiteral("/sys/class/net/") + m_netInterface + QStringLiteral("/statistics/");
    uint64_t rxBytes = readSysfsUint64(basePath + QStringLiteral("rx_bytes"));
    uint64_t txBytes = readSysfsUint64(basePath + QStringLiteral("tx_bytes"));

    if (m_netFirstTick) {
        m_prevRxBytes = rxBytes;
        m_prevTxBytes = txBytes;
        m_netFirstTick = false;
        snapshot.hasNet = true;
        snapshot.netInterface = m_netInterface;
        snapshot.netRxSpeed = 0;
        snapshot.netTxSpeed = 0;
        snapshot.netRxFormatted = QStringLiteral("0 B/s");
        snapshot.netTxFormatted = QStringLiteral("0 B/s");
        return;
    }

    double interval = m_fastTimer.interval() / 1000.0;
    if (interval <= 0) interval = 2.0;

    double rxSpeed = (rxBytes >= m_prevRxBytes) ? (rxBytes - m_prevRxBytes) / interval : 0;
    double txSpeed = (txBytes >= m_prevTxBytes) ? (txBytes - m_prevTxBytes) / interval : 0;

    m_prevRxBytes = rxBytes;
    m_prevTxBytes = txBytes;

    snapshot.hasNet = true;
    snapshot.netInterface = m_netInterface;
    snapshot.netRxSpeed = rxSpeed;
    snapshot.netTxSpeed = txSpeed;
    snapshot.netRxFormatted = formatSpeed(rxSpeed);
    snapshot.netTxFormatted = formatSpeed(txSpeed);
}

// ─── Disk I/O ───────────────────────────────────────────────────────────────

void StatsWorker::updateDiskIo(StatsSnapshot& snapshot) {
    if (m_diskDevice.isEmpty() || m_diskstatsFd < 0) {
        snapshot.hasDiskIo = false;
        return;
    }

    if (!readProcFile(m_diskstatsFd, m_diskstatsBuffer, sizeof(m_diskstatsBuffer)))
        return;

    QByteArray devName = m_diskDevice.toUtf8();
    uint64_t readSectors = 0, writeSectors = 0;
    bool found = false;

    char* line = m_diskstatsBuffer;
    char* lineEnd;
    while ((lineEnd = strchr(line, '\n')) != nullptr) {
        *lineEnd = '\0';
        // diskstats format: major minor name rd_ios rd_merges rd_sectors rd_ticks wr_ios wr_merges wr_sectors ...
        unsigned int major, minor;
        char name[64] = {0};
        uint64_t rdIos, rdMerges, rdSect, rdTicks, wrIos, wrMerges, wrSect;
        int parsed = sscanf(line, "%u %u %63s %lu %lu %lu %lu %lu %lu %lu",
                            &major, &minor, name,
                            &rdIos, &rdMerges, &rdSect, &rdTicks,
                            &wrIos, &wrMerges, &wrSect);
        if (parsed >= 10 && devName == name) {
            readSectors = rdSect;
            writeSectors = wrSect;
            found = true;
            break;
        }
        line = lineEnd + 1;
    }

    if (!found) {
        snapshot.hasDiskIo = false;
        return;
    }

    if (m_diskIoFirstTick) {
        m_prevReadSectors = readSectors;
        m_prevWriteSectors = writeSectors;
        m_diskIoFirstTick = false;
        snapshot.hasDiskIo = true;
        snapshot.diskReadSpeed = 0;
        snapshot.diskWriteSpeed = 0;
        snapshot.diskReadFormatted = QStringLiteral("0 B/s");
        snapshot.diskWriteFormatted = QStringLiteral("0 B/s");
        return;
    }

    double interval = m_fastTimer.interval() / 1000.0;
    if (interval <= 0) interval = 2.0;

    double readBytes = (readSectors >= m_prevReadSectors) ? (readSectors - m_prevReadSectors) * 512.0 : 0;
    double writeBytes = (writeSectors >= m_prevWriteSectors) ? (writeSectors - m_prevWriteSectors) * 512.0 : 0;

    m_prevReadSectors = readSectors;
    m_prevWriteSectors = writeSectors;

    snapshot.hasDiskIo = true;
    snapshot.diskReadSpeed = readBytes / interval;
    snapshot.diskWriteSpeed = writeBytes / interval;
    snapshot.diskReadFormatted = formatSpeed(readBytes / interval);
    snapshot.diskWriteFormatted = formatSpeed(writeBytes / interval);
}

// ─── Poll methods ───────────────────────────────────────────────────────────

void StatsWorker::pollFast() {
    StatsSnapshot snapshot;
    snapshot.cpuModel = m_cpuModel;
    snapshot.gpuModel = !m_gpuModelNvml.isEmpty() ? m_gpuModelNvml : m_gpuModel;

    updateCpu(snapshot);
    updateCpuFreq(snapshot);
    updateRam(snapshot);
    updateDisk(snapshot);
    updateNetwork(snapshot);
    updateDiskIo(snapshot);

    // Re-detect network interface periodically (every 6th slow poll ≈ 30s)
    // This counter is bumped in pollSlow

    snapshot.hasCpuTemp = m_lastCpuTemp.has_value();
    snapshot.cpuTemp = m_lastCpuTemp.value_or(0);

    // Load average (cached from slow poll)
    snapshot.loadAvg1 = m_lastLoadAvg1;
    snapshot.loadAvg5 = m_lastLoadAvg5;
    snapshot.loadAvg15 = m_lastLoadAvg15;

    // GPU stats (cached from slow poll)
    if (m_gpuBackend == GpuBackend::Nvml) {
        snapshot.hasGpuStats = m_lastGpu.has_value();
        if (m_lastGpu.has_value()) {
            snapshot.gpuUsage = m_lastGpu->first;
            snapshot.gpuTemp = m_lastGpu->second;
        }
        snapshot.gpuMemUsage = m_lastGpuMemUsage;
        snapshot.gpuMemUsed = m_lastGpuMemUsed;
        snapshot.gpuMemTotal = m_lastGpuMemTotal;
        snapshot.gpuClockMHz = m_lastGpuClockMHz;
        snapshot.gpuFanSpeed = m_lastGpuFanSpeed;
        snapshot.gpuPowerWatts = m_lastGpuPowerWatts;
    } else if (m_gpuBackend == GpuBackend::AmdSysfs) {
        snapshot.hasGpuStats = true;
        // AMD cached values from slow poll are already stored
        // We still read gpu_busy_percent on slow poll too, cached in snapshot via readGpuAmd
        snapshot.gpuMemUsage = m_lastGpuMemUsage;
        snapshot.gpuMemUsed = m_lastGpuMemUsed;
        snapshot.gpuMemTotal = m_lastGpuMemTotal;
        snapshot.gpuClockMHz = m_lastGpuClockMHz;
        snapshot.gpuFanSpeed = m_lastGpuFanSpeed;
        snapshot.gpuPowerWatts = m_lastGpuPowerWatts;
        // Usage and temp also cached
        if (m_lastGpu.has_value()) {
            snapshot.gpuUsage = m_lastGpu->first;
            snapshot.gpuTemp = m_lastGpu->second;
        }
    } else {
        snapshot.hasGpuStats = m_lastGpu.has_value();
        if (m_lastGpu.has_value()) {
            snapshot.gpuUsage = m_lastGpu->first;
            snapshot.gpuTemp = m_lastGpu->second;
        }
    }

    emit snapshotReady(snapshot);
}

void StatsWorker::pollSlow() {
    // CPU temperature
    std::optional<int> t;
#ifdef HAVE_LIBSENSORS
    t = readCpuTempSensors();
#endif
    if (!t)
        t = readCpuTempSysfs();
    m_lastCpuTemp = t;

    // Load average
    updateLoadAvg();

    // GPU — branch by backend
    if (m_gpuBackend == GpuBackend::Nvml) {
        m_lastGpu = readGpuNvml();
        if (auto name = readGpuNameNvml()) {
            m_gpuModelNvml = name.value();
        }
        // Extended NVML metrics
        StatsSnapshot tmpSnap;
        readGpuExtendedNvml(tmpSnap);
        m_lastGpuMemUsage = tmpSnap.gpuMemUsage;
        m_lastGpuMemUsed = tmpSnap.gpuMemUsed;
        m_lastGpuMemTotal = tmpSnap.gpuMemTotal;
        m_lastGpuClockMHz = tmpSnap.gpuClockMHz;
        m_lastGpuFanSpeed = tmpSnap.gpuFanSpeed;
        m_lastGpuPowerWatts = tmpSnap.gpuPowerWatts;
    } else if (m_gpuBackend == GpuBackend::AmdSysfs) {
        StatsSnapshot tmpSnap;
        readGpuAmd(tmpSnap);
        m_lastGpu = std::make_pair(tmpSnap.gpuUsage, tmpSnap.gpuTemp);
        m_lastGpuMemUsage = tmpSnap.gpuMemUsage;
        m_lastGpuMemUsed = tmpSnap.gpuMemUsed;
        m_lastGpuMemTotal = tmpSnap.gpuMemTotal;
        m_lastGpuClockMHz = tmpSnap.gpuClockMHz;
        m_lastGpuFanSpeed = tmpSnap.gpuFanSpeed;
        m_lastGpuPowerWatts = tmpSnap.gpuPowerWatts;
    }
    // GpuBackend::None — no GPU polling

    // Re-detect network interface periodically
    m_netRedetectCounter++;
    if (m_netRedetectCounter >= 6) {
        m_netRedetectCounter = 0;
        detectNetInterface();
    }
}

// ─── Data collection ────────────────────────────────────────────────────────

void StatsWorker::updateCpu(StatsSnapshot& snapshot) {
    if (m_cpuStatFd < 0) return;
    if (!readProcFile(m_cpuStatFd, m_cpuBuffer, sizeof(m_cpuBuffer)))
        return;

    uint64_t user, nice, system, idle, iowait, irq, softirq;
    int parsed = sscanf(m_cpuBuffer, "cpu %lu %lu %lu %lu %lu %lu %lu",
                        &user, &nice, &system, &idle, &iowait, &irq, &softirq);
    if (parsed != 7)
        return;

    uint64_t total = user + nice + system + idle + iowait + irq + softirq;

    if (m_lastCpuTotal != 0) {
        uint64_t totalDelta = total - m_lastCpuTotal;
        uint64_t idleDelta = idle - m_lastCpuIdle;
        if (totalDelta > 0) {
            snapshot.cpuUsage = 100.0 * (1.0 - static_cast<qreal>(idleDelta) / totalDelta);
        }
    }
    m_lastCpuIdle = idle;
    m_lastCpuTotal = total;
}

void StatsWorker::updateRam(StatsSnapshot& snapshot) {
    if (m_meminfoFd < 0) return;
    if (!readProcFile(m_meminfoFd, m_memBuffer, sizeof(m_memBuffer)))
        return;

    uint64_t memTotal = 0, memAvailable = 0;
    uint64_t swapTotal = 0, swapFree = 0;

    char* line = m_memBuffer;
    char* lineEnd;

    while ((lineEnd = strchr(line, '\n')) != nullptr) {
        *lineEnd = '\0';

        if (strncmp(line, "MemTotal:", 9) == 0) {
            sscanf(line + 9, "%lu", &memTotal);
        } else if (strncmp(line, "MemAvailable:", 13) == 0) {
            sscanf(line + 13, "%lu", &memAvailable);
        } else if (strncmp(line, "SwapTotal:", 10) == 0) {
            sscanf(line + 10, "%lu", &swapTotal);
        } else if (strncmp(line, "SwapFree:", 9) == 0) {
            sscanf(line + 9, "%lu", &swapFree);
        }

        line = lineEnd + 1;
    }

    if (memTotal > 0) {
        qreal totalGb = memTotal / (1024.0 * 1024.0);
        qreal availableGb = memAvailable / (1024.0 * 1024.0);
        qreal usedGb = totalGb - availableGb;

        snapshot.ramUsage = (usedGb / totalGb) * 100.0;
        snapshot.ramUsed = QString::number(usedGb, 'f', 1);
        snapshot.ramTotal = QString::number(totalGb, 'f', 1);
    }

    // Swap
    if (swapTotal > 0) {
        qreal swapTotalGb = swapTotal / (1024.0 * 1024.0);
        qreal swapFreeGb = swapFree / (1024.0 * 1024.0);
        qreal swapUsedGb = swapTotalGb - swapFreeGb;

        snapshot.hasSwap = true;
        snapshot.swapUsage = (swapUsedGb / swapTotalGb) * 100.0;
        snapshot.swapUsed = QString::number(swapUsedGb, 'f', 1);
        snapshot.swapTotal = QString::number(swapTotalGb, 'f', 1);
    } else {
        snapshot.hasSwap = false;
    }
}

void StatsWorker::updateDisk(StatsSnapshot& snapshot) {
    struct statvfs stat;
    if (statvfs("/", &stat) != 0) {
        return;
    }
    uint64_t totalBytes = stat.f_blocks * stat.f_frsize;
    uint64_t availableBytes = stat.f_bavail * stat.f_frsize;
    uint64_t usedBytes = totalBytes - availableBytes;
    snapshot.diskUsage = totalBytes > 0 ? (usedBytes * 100.0 / totalBytes) : 0.0;
    snapshot.diskUsed = formatBytes(usedBytes);
    snapshot.diskTotal = formatBytes(totalBytes);
}

// ─── SystemMonitor main thread ──────────────────────────────────────────────

void SystemMonitor::initializeStaticInfo()
{
    // Username
    m_userName = qEnvironmentVariable("USER");
    if (m_userName.isEmpty()) {
        if (passwd* pw = getpwuid(getuid())) {
            m_userName = QString::fromLocal8Bit(pw->pw_name);
        }
    }
    emit userNameChanged();

    // OS name from /etc/os-release
    for (const auto& path : {"/etc/os-release", "/usr/lib/os-release"}) {
        QFile osRelease(path);
        if (osRelease.open(QIODevice::ReadOnly)) {
            while (!osRelease.atEnd()) {
                const QString line = QString::fromUtf8(osRelease.readLine()).trimmed();
                if (line.startsWith(QStringLiteral("PRETTY_NAME="))) {
                    m_osName = line.mid(12);
                    if (m_osName.startsWith('"') && m_osName.endsWith('"'))
                        m_osName = m_osName.mid(1, m_osName.size() - 2);
                    break;
                }
            }
            if (!m_osName.isEmpty()) break;
        }
    }
    if (m_osName.isEmpty())
        m_osName = QStringLiteral("Linux");

    // WM/DE from environment
    m_wmName = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
    if (m_wmName.isEmpty())
        m_wmName = qEnvironmentVariable("XDG_SESSION_DESKTOP");
    if (m_wmName.isEmpty())
        m_wmName = qEnvironmentVariable("DESKTOP_SESSION");
    if (m_wmName.isEmpty())
        m_wmName = QStringLiteral("Unknown");

    // CPU model
    QFile cpuinfo("/proc/cpuinfo");
    if (cpuinfo.open(QIODevice::ReadOnly)) {
        QByteArray content = cpuinfo.readAll();
        cpuinfo.close();

        QRegularExpression modelRegex("model name\\s*:\\s*(.+)");
        auto match = modelRegex.match(QString::fromLatin1(content));
        if (match.hasMatch()) {
            QString model = match.captured(1).trimmed();
            model.replace(QRegularExpression("AMD Ryzen (\\d) (\\w+).*"), "R\\1 \\2");
            model.replace(QRegularExpression("Intel.*Core.*i(\\d)-(\\w+).*"), "i\\1-\\2");
            m_cpuModel = model;
            emit cpuModelChanged();
        }
    }

    // GPU model (sysfs lightweight path instead of lspci)
    QFile vendorFile("/sys/class/drm/card0/device/vendor");
    QFile deviceFile("/sys/class/drm/card0/device/device");
    if (vendorFile.open(QIODevice::ReadOnly)) {
        const QString vendor = QString::fromUtf8(vendorFile.readAll()).trimmed();
        QString vendorName;
        if (vendor == "0x10de") vendorName = "NVIDIA";
        else if (vendor == "0x1002" || vendor == "0x1022") vendorName = "AMD";
        else if (vendor == "0x8086") vendorName = "Intel";

        if (deviceFile.open(QIODevice::ReadOnly)) {
            const QString devId = QString::fromUtf8(deviceFile.readAll()).trimmed();
            if (!vendorName.isEmpty())
                m_gpuModel = vendorName + " " + devId;
            else
                m_gpuModel = devId;
            emit gpuModelChanged();
        } else if (!vendorName.isEmpty()) {
            m_gpuModel = vendorName;
            emit gpuModelChanged();
        }
    }
}

void SystemMonitor::handleSnapshot(const StatsSnapshot& snapshot)
{
    auto emitIfChanged = [](auto& field, const auto& value, auto signal) {
        if (field != value) {
            field = value;
            signal();
        }
    };

    // CPU
    emitIfChanged(m_cpuUsage, snapshot.cpuUsage, [this]() { emit cpuUsageChanged(); });
    emitIfChanged(m_cpuTemp, snapshot.cpuTemp, [this]() { emit cpuTempChanged(); });
    emitIfChanged(m_cpuFreqGHz, snapshot.cpuFreqGHz, [this]() { emit cpuFreqGHzChanged(); });
    emitIfChanged(m_loadAvg1, snapshot.loadAvg1, [this]() { emit loadAvg1Changed(); });
    emitIfChanged(m_loadAvg5, snapshot.loadAvg5, [this]() { emit loadAvg5Changed(); });
    emitIfChanged(m_loadAvg15, snapshot.loadAvg15, [this]() { emit loadAvg15Changed(); });

    // RAM
    emitIfChanged(m_ramUsage, snapshot.ramUsage, [this]() { emit ramUsageChanged(); });
    emitIfChanged(m_ramUsed, snapshot.ramUsed, [this]() { emit ramUsedChanged(); });
    emitIfChanged(m_ramTotal, snapshot.ramTotal, [this]() { emit ramTotalChanged(); });

    // Swap
    emitIfChanged(m_swapUsage, snapshot.swapUsage, [this]() { emit swapUsageChanged(); });
    emitIfChanged(m_swapUsed, snapshot.swapUsed, [this]() { emit swapUsedChanged(); });
    emitIfChanged(m_swapTotal, snapshot.swapTotal, [this]() { emit swapTotalChanged(); });
    emitIfChanged(m_hasSwap, snapshot.hasSwap, [this]() { emit hasSwapChanged(); });

    // GPU
    emitIfChanged(m_gpuUsage, snapshot.gpuUsage, [this]() { emit gpuUsageChanged(); });
    emitIfChanged(m_gpuTemp, snapshot.gpuTemp, [this]() { emit gpuTempChanged(); });
    emitIfChanged(m_gpuModel, snapshot.gpuModel, [this]() { emit gpuModelChanged(); });
    emitIfChanged(m_gpuMemUsage, snapshot.gpuMemUsage, [this]() { emit gpuMemUsageChanged(); });
    emitIfChanged(m_gpuMemUsed, snapshot.gpuMemUsed, [this]() { emit gpuMemUsedChanged(); });
    emitIfChanged(m_gpuMemTotal, snapshot.gpuMemTotal, [this]() { emit gpuMemTotalChanged(); });
    emitIfChanged(m_gpuClockMHz, snapshot.gpuClockMHz, [this]() { emit gpuClockMHzChanged(); });
    emitIfChanged(m_gpuFanSpeed, snapshot.gpuFanSpeed, [this]() { emit gpuFanSpeedChanged(); });
    emitIfChanged(m_gpuPowerWatts, snapshot.gpuPowerWatts, [this]() { emit gpuPowerWattsChanged(); });

    // Disk
    emitIfChanged(m_diskUsage, snapshot.diskUsage, [this]() { emit diskUsageChanged(); });
    emitIfChanged(m_diskUsed, snapshot.diskUsed, [this]() { emit diskUsedChanged(); });
    emitIfChanged(m_diskTotal, snapshot.diskTotal, [this]() { emit diskTotalChanged(); });
    emitIfChanged(m_diskReadSpeed, snapshot.diskReadSpeed, [this]() { emit diskReadSpeedChanged(); });
    emitIfChanged(m_diskWriteSpeed, snapshot.diskWriteSpeed, [this]() { emit diskWriteSpeedChanged(); });
    emitIfChanged(m_diskReadFormatted, snapshot.diskReadFormatted, [this]() { emit diskReadFormattedChanged(); });
    emitIfChanged(m_diskWriteFormatted, snapshot.diskWriteFormatted, [this]() { emit diskWriteFormattedChanged(); });
    emitIfChanged(m_hasDiskIo, snapshot.hasDiskIo, [this]() { emit hasDiskIoChanged(); });

    // Network
    emitIfChanged(m_netRxSpeed, snapshot.netRxSpeed, [this]() { emit netRxSpeedChanged(); });
    emitIfChanged(m_netTxSpeed, snapshot.netTxSpeed, [this]() { emit netTxSpeedChanged(); });
    emitIfChanged(m_netRxFormatted, snapshot.netRxFormatted, [this]() { emit netRxFormattedChanged(); });
    emitIfChanged(m_netTxFormatted, snapshot.netTxFormatted, [this]() { emit netTxFormattedChanged(); });
    emitIfChanged(m_netInterface, snapshot.netInterface, [this]() { emit netInterfaceChanged(); });
    emitIfChanged(m_hasNet, snapshot.hasNet, [this]() { emit hasNetChanged(); });

    // Status flags
    emitIfChanged(m_hasCpuTemp, snapshot.hasCpuTemp, [this]() { emit hasCpuTempChanged(); });
    emitIfChanged(m_hasGpuStats, snapshot.hasGpuStats, [this]() { emit hasGpuStatsChanged(); });

    emit statsUpdated();
}

void SystemMonitor::stopWorker()
{
    m_workerThread.requestInterruption();
    m_workerThread.quit();
    if (!m_workerThread.wait(3000)) {
        qWarning("SystemMonitor: worker thread did not stop in 3s, waiting indefinitely");
        m_workerThread.wait();
    }
}

#include "SystemMonitor.moc"
