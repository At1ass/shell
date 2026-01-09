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

// Воркер, собирающий метрики в отдельном потоке
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
    std::optional<int> readCpuTempSysfs();

    // NVML dynamic loader
    struct NvmlApi {
        using Init_t = int (*)();
        using Shutdown_t = int (*)();
        using DeviceGetHandleByIndex_t = int (*)(unsigned int, void**);
        using DeviceGetUtilizationRates_t = int (*)(void*, void*);
        using DeviceGetTemperature_t = int (*)(void*, unsigned int, unsigned int*);
        using DeviceGetName_t = int (*)(void*, char*, unsigned int);

        QLibrary lib;
        Init_t init = nullptr;
        Shutdown_t shutdown = nullptr;
        DeviceGetHandleByIndex_t deviceGetHandleByIndex = nullptr;
        DeviceGetUtilizationRates_t deviceGetUtilizationRates = nullptr;
        DeviceGetTemperature_t deviceGetTemperature = nullptr;
        DeviceGetName_t deviceGetName = nullptr;
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

    std::optional<std::pair<int, int>> readGpuNvml();
    std::optional<QString> readGpuNameNvml();
    void initSensors();

    void pollFast();
    void pollSlow();
    void updateCpu(StatsSnapshot& snapshot);
    void updateRam(StatsSnapshot& snapshot);
    void updateDisk(StatsSnapshot& snapshot);

    int m_cpuStatFd = -1;
    int m_meminfoFd = -1;
    uint64_t m_lastCpuIdle = 0;
    uint64_t m_lastCpuTotal = 0;
    char m_cpuBuffer[2048];
    char m_memBuffer[4096];
    QTimer m_fastTimer;
    QTimer m_slowTimer;
    QString m_cpuModel;
    QString m_gpuModel;
    QString m_gpuModelNvml;
    std::optional<int> m_lastCpuTemp;
    std::optional<std::pair<int, int>> m_lastGpu;

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

    // Передаём статические значения в воркер
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
    if (ms < 500) ms = 500; // ограничиваем частоту
    m_fastTimer.setInterval(ms);
}

void StatsWorker::refreshNow() {
    pollFast();
    pollSlow();
}

void StatsWorker::startTimers() {
    // Выполним первичный сбор, чтобы UI не видел нули
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
}

void StatsWorker::closeProcFiles() {
    if (m_cpuStatFd >= 0) {
        close(m_cpuStatFd);
        m_cpuStatFd = -1;
    }
    if (m_meminfoFd >= 0) {
        close(m_meminfoFd);
        m_meminfoFd = -1;
    }
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

std::optional<int> StatsWorker::readCpuTempSysfs() {
    // thermal_zone*: берём максимальную подходящую
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

void StatsWorker::pollFast() {
    StatsSnapshot snapshot;
    snapshot.cpuModel = m_cpuModel;
    snapshot.gpuModel = !m_gpuModelNvml.isEmpty() ? m_gpuModelNvml : m_gpuModel;

    updateCpu(snapshot);
    updateRam(snapshot);
    updateDisk(snapshot);

    snapshot.hasCpuTemp = m_lastCpuTemp.has_value();
    snapshot.cpuTemp = m_lastCpuTemp.value_or(0);
    snapshot.hasGpuStats = m_lastGpu.has_value();
    if (m_lastGpu.has_value()) {
        snapshot.gpuUsage = m_lastGpu->first;
        snapshot.gpuTemp = m_lastGpu->second;
    }

    emit snapshotReady(snapshot);
}

void StatsWorker::pollSlow() {
    std::optional<int> t;
#ifdef HAVE_LIBSENSORS
    t = readCpuTempSensors();
#endif
    if (!t)
        t = readCpuTempSysfs();
    m_lastCpuTemp = t;
    m_lastGpu = readGpuNvml();
    if (auto name = readGpuNameNvml()) {
        m_gpuModelNvml = name.value();
    }
}

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

    uint64_t memTotal = 0;
    uint64_t memAvailable = 0;

    char* line = m_memBuffer;
    char* lineEnd;

    while ((lineEnd = strchr(line, '\n')) != nullptr) {
        *lineEnd = '\0';

        if (strncmp(line, "MemTotal:", 9) == 0) {
            sscanf(line + 9, "%lu", &memTotal);
        } else if (strncmp(line, "MemAvailable:", 13) == 0) {
            sscanf(line + 13, "%lu", &memAvailable);
        }

        line = lineEnd + 1;
        if (memTotal > 0 && memAvailable > 0) {
            break;
        }
    }

    if (memTotal == 0) return;

    qreal totalGb = memTotal / (1024.0 * 1024.0);
    qreal availableGb = memAvailable / (1024.0 * 1024.0);
    qreal usedGb = totalGb - availableGb;

    snapshot.ramUsage = (usedGb / totalGb) * 100.0;
    snapshot.ramUsed = QString::number(usedGb, 'f', 1);
    snapshot.ramTotal = QString::number(totalGb, 'f', 1);
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

    // GPU model (sysfs лёгкий путь вместо lspci)
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

    emitIfChanged(m_cpuUsage, snapshot.cpuUsage, [this]() { emit cpuUsageChanged(); });
    emitIfChanged(m_cpuTemp, snapshot.cpuTemp, [this]() { emit cpuTempChanged(); });
    emitIfChanged(m_ramUsage, snapshot.ramUsage, [this]() { emit ramUsageChanged(); });
    emitIfChanged(m_ramUsed, snapshot.ramUsed, [this]() { emit ramUsedChanged(); });
    emitIfChanged(m_ramTotal, snapshot.ramTotal, [this]() { emit ramTotalChanged(); });
    emitIfChanged(m_gpuUsage, snapshot.gpuUsage, [this]() { emit gpuUsageChanged(); });
    emitIfChanged(m_gpuTemp, snapshot.gpuTemp, [this]() { emit gpuTempChanged(); });
    emitIfChanged(m_gpuModel, snapshot.gpuModel, [this]() { emit gpuModelChanged(); });
    emitIfChanged(m_diskUsage, snapshot.diskUsage, [this]() { emit diskUsageChanged(); });
    emitIfChanged(m_diskUsed, snapshot.diskUsed, [this]() { emit diskUsedChanged(); });
    emitIfChanged(m_diskTotal, snapshot.diskTotal, [this]() { emit diskTotalChanged(); });
    emitIfChanged(m_hasCpuTemp, snapshot.hasCpuTemp, [this]() { emit hasCpuTempChanged(); });
    emitIfChanged(m_hasGpuStats, snapshot.hasGpuStats, [this]() { emit hasGpuStatsChanged(); });

    emit statsUpdated();
}

void SystemMonitor::stopWorker()
{
    m_workerThread.requestInterruption();
    m_workerThread.quit();
    m_workerThread.wait(1000);
}

#include "SystemMonitor.moc"
