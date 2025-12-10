#include "SystemMonitor.h"

#include <QtCore/QFile>
#include <QtCore/QProcess>
#include <QtCore/QRegularExpression>

#include <unistd.h>
#include <fcntl.h>
#include <sys/sysinfo.h>
#include <sys/statvfs.h>
#include <cerrno>
#include <cstring>

SystemMonitor::SystemMonitor(QObject* parent)
    : QObject(parent)
{
    // Open proc files once (keep FDs open for performance)
    openProcFiles();

    // Initialize static info (username, CPU model, GPU model)
    initializeStaticInfo();

    // Setup update timer
    connect(&m_updateTimer, &QTimer::timeout, this, &SystemMonitor::updateStats);
    m_updateTimer.setInterval(2000);  // 2 seconds default
    m_updateTimer.start();
    m_isMonitoring = true;
    emit isMonitoringChanged();

    // Initial update
    updateStats();
}

SystemMonitor::~SystemMonitor()
{
    closeProcFiles();
}

void SystemMonitor::setUpdateInterval(int milliseconds)
{
    if (milliseconds < 100) {
        qWarning() << "SystemMonitor: Update interval too small, using 100ms";
        milliseconds = 100;
    }
    m_updateTimer.setInterval(milliseconds);
}

void SystemMonitor::refresh()
{
    updateStats();
}

void SystemMonitor::openProcFiles()
{
    // Open /proc/stat (CPU usage)
    m_cpuStatFd = open("/proc/stat", O_RDONLY);
    if (m_cpuStatFd < 0) {
        qWarning() << "SystemMonitor: Failed to open /proc/stat:" << strerror(errno);
        emit errorOccurred(QStringLiteral("Failed to open /proc/stat"));
    }

    // Open /proc/meminfo (RAM usage)
    m_meminfoFd = open("/proc/meminfo", O_RDONLY);
    if (m_meminfoFd < 0) {
        qWarning() << "SystemMonitor: Failed to open /proc/meminfo:" << strerror(errno);
        emit errorOccurred(QStringLiteral("Failed to open /proc/meminfo"));
    }
}

void SystemMonitor::closeProcFiles()
{
    if (m_cpuStatFd >= 0) {
        close(m_cpuStatFd);
        m_cpuStatFd = -1;
    }
    if (m_meminfoFd >= 0) {
        close(m_meminfoFd);
        m_meminfoFd = -1;
    }
}

bool SystemMonitor::readProcFile(int fd, char* buffer, size_t bufferSize)
{
    if (fd < 0 || !buffer || bufferSize == 0) {
        return false;
    }

    // Seek to beginning
    if (lseek(fd, 0, SEEK_SET) < 0) {
        qWarning() << "SystemMonitor: lseek failed:" << strerror(errno);
        return false;
    }

    // Read entire file
    ssize_t bytesRead = read(fd, buffer, bufferSize - 1);
    if (bytesRead < 0) {
        qWarning() << "SystemMonitor: read failed:" << strerror(errno);
        return false;
    }

    buffer[bytesRead] = '\0';
    return true;
}

void SystemMonitor::initializeStaticInfo()
{
    // Username
    QProcess whoami;
    whoami.start("whoami");
    if (whoami.waitForFinished(1000)) {
        m_userName = QString::fromUtf8(whoami.readAllStandardOutput()).trimmed();
        emit userNameChanged();
    } else {
        qWarning() << "SystemMonitor: Failed to get username";
        m_userName = qgetenv("USER");
        emit userNameChanged();
    }

    // CPU model
    QFile cpuinfo("/proc/cpuinfo");
    if (cpuinfo.open(QIODevice::ReadOnly)) {
        QByteArray content = cpuinfo.readAll();
        cpuinfo.close();

        QRegularExpression modelRegex("model name\\s*:\\s*(.+)");
        auto match = modelRegex.match(QString::fromLatin1(content));
        if (match.hasMatch()) {
            QString model = match.captured(1).trimmed();
            // Shorten: "AMD Ryzen 7 7700X 8-Core Processor" -> "R7 7700X"
            model.replace(QRegularExpression("AMD Ryzen (\\d) (\\w+).*"), "R\\1 \\2");
            model.replace(QRegularExpression("Intel.*Core.*i(\\d)-(\\w+).*"), "i\\1-\\2");
            m_cpuModel = model;
            emit cpuModelChanged();
        }
    }

    // GPU model
    QProcess lspci;
    lspci.start("lspci");
    if (lspci.waitForFinished(1000)) {
        QString output = QString::fromUtf8(lspci.readAllStandardOutput());

        // Try NVIDIA
        QRegularExpression nvidiaRegex("VGA.*NVIDIA.*\\[(.+?)\\]");
        auto match = nvidiaRegex.match(output);
        if (match.hasMatch()) {
            QString model = match.captured(1).trimmed();
            model.replace("GeForce ", "");  // "GeForce RTX 4070 Ti" -> "RTX 4070 Ti"
            m_gpuModel = model;
            emit gpuModelChanged();
        } else {
            // Try AMD
            QRegularExpression amdRegex("VGA.*AMD.*\\[(.+?)\\]");
            auto amdMatch = amdRegex.match(output);
            if (amdMatch.hasMatch()) {
                m_gpuModel = amdMatch.captured(1).trimmed();
                emit gpuModelChanged();
            }
        }
    }
}

void SystemMonitor::updateStats()
{
    // Update all metrics
    updateCpu();
    updateRam();
    updateDisk();
    updateTemperature();
    updateGpu();

    // Emit batch signal for UI
    emit statsUpdated();
}

void SystemMonitor::updateCpu()
{
    if (m_cpuStatFd < 0) {
        return;  // Graceful degradation
    }

    if (!readProcFile(m_cpuStatFd, m_cpuBuffer, sizeof(m_cpuBuffer))) {
        return;
    }

    // Parse first line: "cpu  user nice system idle iowait irq softirq"
    uint64_t user, nice, system, idle, iowait, irq, softirq;
    int parsed = sscanf(m_cpuBuffer, "cpu %lu %lu %lu %lu %lu %lu %lu",
                        &user, &nice, &system, &idle, &iowait, &irq, &softirq);

    if (parsed != 7) {
        qWarning() << "SystemMonitor: Failed to parse /proc/stat";
        return;
    }

    uint64_t total = user + nice + system + idle + iowait + irq + softirq;

    // Calculate usage (skip first call, need delta)
    if (m_lastCpuTotal != 0) {
        uint64_t totalDelta = total - m_lastCpuTotal;
        uint64_t idleDelta = idle - m_lastCpuIdle;

        if (totalDelta > 0) {
            qreal newUsage = 100.0 * (1.0 - static_cast<qreal>(idleDelta) / totalDelta);
            if (qAbs(newUsage - m_cpuUsage) > 0.1) {  // Only emit if changed significantly
                m_cpuUsage = newUsage;
                emit cpuUsageChanged();
            }
        }
    }

    m_lastCpuIdle = idle;
    m_lastCpuTotal = total;
}

void SystemMonitor::updateRam()
{
    if (m_meminfoFd < 0) {
        return;  // Graceful degradation
    }

    if (!readProcFile(m_meminfoFd, m_memBuffer, sizeof(m_memBuffer))) {
        return;
    }

    // Parse /proc/meminfo
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

        // Optimization: stop after finding both
        if (memTotal > 0 && memAvailable > 0) {
            break;
        }
    }

    if (memTotal == 0) {
        qWarning() << "SystemMonitor: Failed to parse /proc/meminfo";
        return;
    }

    // Convert KB to GB
    qreal totalGb = memTotal / (1024.0 * 1024.0);
    qreal availableGb = memAvailable / (1024.0 * 1024.0);
    qreal usedGb = totalGb - availableGb;

    qreal newUsage = (usedGb / totalGb) * 100.0;
    QString newUsed = QString::number(usedGb, 'f', 1);
    QString newTotal = QString::number(totalGb, 'f', 1);

    if (qAbs(newUsage - m_ramUsage) > 0.1) {
        m_ramUsage = newUsage;
        emit ramUsageChanged();
    }

    if (newUsed != m_ramUsed) {
        m_ramUsed = newUsed;
        emit ramUsedChanged();
    }

    if (newTotal != m_ramTotal) {
        m_ramTotal = newTotal;
        emit ramTotalChanged();
    }
}

void SystemMonitor::updateDisk()
{
    struct statvfs stat;

    if (statvfs("/", &stat) != 0) {
        qWarning() << "SystemMonitor: statvfs failed:" << strerror(errno);
        return;
    }

    // Calculate disk usage
    uint64_t totalBytes = stat.f_blocks * stat.f_frsize;
    uint64_t availableBytes = stat.f_bavail * stat.f_frsize;
    uint64_t usedBytes = totalBytes - availableBytes;

    qreal newUsage = totalBytes > 0 ? (usedBytes * 100.0 / totalBytes) : 0.0;
    QString newUsed = formatBytes(usedBytes);
    QString newTotal = formatBytes(totalBytes);

    if (qAbs(newUsage - m_diskUsage) > 0.1) {
        m_diskUsage = newUsage;
        emit diskUsageChanged();
    }

    if (newUsed != m_diskUsed) {
        m_diskUsed = newUsed;
        emit diskUsedChanged();
    }

    if (newTotal != m_diskTotal) {
        m_diskTotal = newTotal;
        emit diskTotalChanged();
    }
}

void SystemMonitor::updateTemperature()
{
    // Use sensors command for CPU temperature
    QProcess sensors;
    sensors.start("sensors");

    if (!sensors.waitForFinished(500)) {
        return;  // Graceful degradation - no temperature available
    }

    QString output = QString::fromUtf8(sensors.readAllStandardOutput());

    // Try Tctl (AMD) or Package (Intel)
    QRegularExpression tctlRegex("Tctl:\\s*\\+?([0-9.]+)°C");
    QRegularExpression packageRegex("Package id 0:\\s*\\+?([0-9.]+)°C");

    auto tctlMatch = tctlRegex.match(output);
    auto packageMatch = packageRegex.match(output);

    int newTemp = 0;
    if (tctlMatch.hasMatch()) {
        newTemp = qRound(tctlMatch.captured(1).toDouble());
    } else if (packageMatch.hasMatch()) {
        newTemp = qRound(packageMatch.captured(1).toDouble());
    }

    if (newTemp > 0 && newTemp != m_cpuTemp) {
        m_cpuTemp = newTemp;
        emit cpuTempChanged();
    }
}

void SystemMonitor::updateGpu()
{
    // Try nvidia-smi for NVIDIA GPUs
    QProcess nvidiaSmi;
    nvidiaSmi.start("nvidia-smi", QStringList{
        "--query-gpu=utilization.gpu,temperature.gpu",
        "--format=csv,noheader,nounits"
    });

    if (!nvidiaSmi.waitForFinished(500)) {
        return;  // Graceful degradation - no GPU available
    }

    if (nvidiaSmi.exitCode() != 0) {
        return;  // nvidia-smi not available or failed
    }

    QString output = QString::fromUtf8(nvidiaSmi.readAllStandardOutput()).trimmed();
    QStringList parts = output.split(',');

    if (parts.size() >= 2) {
        int newUsage = parts[0].trimmed().toInt();
        int newTemp = parts[1].trimmed().toInt();

        if (newUsage != m_gpuUsage) {
            m_gpuUsage = newUsage;
            emit gpuUsageChanged();
        }

        if (newTemp != m_gpuTemp) {
            m_gpuTemp = newTemp;
            emit gpuTempChanged();
        }
    }
}

QString SystemMonitor::formatBytes(double bytes)
{
    const char* units[] = {"B", "KB", "MB", "GB", "TB"};
    int unitIndex = 0;

    while (bytes >= 1024.0 && unitIndex < 4) {
        bytes /= 1024.0;
        unitIndex++;
    }

    // For GB/TB, show 1 decimal place
    if (unitIndex >= 3) {
        return QString::number(bytes, 'f', 1) + units[unitIndex];
    }

    return QString::number(qRound(bytes)) + units[unitIndex];
}
