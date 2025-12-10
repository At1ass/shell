#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtQml/QQmlEngine>

class SystemMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // CPU properties
    Q_PROPERTY(qreal cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(int cpuTemp READ cpuTemp NOTIFY cpuTempChanged)
    Q_PROPERTY(QString cpuModel READ cpuModel NOTIFY cpuModelChanged)

    // RAM properties
    Q_PROPERTY(qreal ramUsage READ ramUsage NOTIFY ramUsageChanged)
    Q_PROPERTY(QString ramUsed READ ramUsed NOTIFY ramUsedChanged)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY ramTotalChanged)

    // GPU properties
    Q_PROPERTY(int gpuUsage READ gpuUsage NOTIFY gpuUsageChanged)
    Q_PROPERTY(int gpuTemp READ gpuTemp NOTIFY gpuTempChanged)
    Q_PROPERTY(QString gpuModel READ gpuModel NOTIFY gpuModelChanged)

    // Disk properties
    Q_PROPERTY(qreal diskUsage READ diskUsage NOTIFY diskUsageChanged)
    Q_PROPERTY(QString diskUsed READ diskUsed NOTIFY diskUsedChanged)
    Q_PROPERTY(QString diskTotal READ diskTotal NOTIFY diskTotalChanged)

    // System info
    Q_PROPERTY(QString userName READ userName NOTIFY userNameChanged)
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString wmName READ wmName CONSTANT)

    // Status
    Q_PROPERTY(bool isMonitoring READ isMonitoring NOTIFY isMonitoringChanged)

public:
    explicit SystemMonitor(QObject* parent = nullptr);
    ~SystemMonitor() override;

    // Prevent copying
    SystemMonitor(const SystemMonitor&) = delete;
    SystemMonitor& operator=(const SystemMonitor&) = delete;

    // CPU getters
    qreal cpuUsage() const { return m_cpuUsage; }
    int cpuTemp() const { return m_cpuTemp; }
    QString cpuModel() const { return m_cpuModel; }

    // RAM getters
    qreal ramUsage() const { return m_ramUsage; }
    QString ramUsed() const { return m_ramUsed; }
    QString ramTotal() const { return m_ramTotal; }

    // GPU getters
    int gpuUsage() const { return m_gpuUsage; }
    int gpuTemp() const { return m_gpuTemp; }
    QString gpuModel() const { return m_gpuModel; }

    // Disk getters
    qreal diskUsage() const { return m_diskUsage; }
    QString diskUsed() const { return m_diskUsed; }
    QString diskTotal() const { return m_diskTotal; }

    // System info getters
    QString userName() const { return m_userName; }
    QString osName() const { return QStringLiteral("Arch Linux"); }
    QString wmName() const { return QStringLiteral("Hyprland"); }

    bool isMonitoring() const { return m_isMonitoring; }

public slots:
    void setUpdateInterval(int milliseconds);
    void refresh();

signals:
    void cpuUsageChanged();
    void cpuTempChanged();
    void cpuModelChanged();
    void ramUsageChanged();
    void ramUsedChanged();
    void ramTotalChanged();
    void gpuUsageChanged();
    void gpuTempChanged();
    void gpuModelChanged();
    void diskUsageChanged();
    void diskUsedChanged();
    void diskTotalChanged();
    void userNameChanged();
    void isMonitoringChanged();
    void statsUpdated();  // Batch signal for UI
    void errorOccurred(const QString& message);

private slots:
    void updateStats();

private:
    // Initialization
    void initializeStaticInfo();
    void openProcFiles();
    void closeProcFiles();

    // Update methods
    void updateCpu();
    void updateRam();
    void updateDisk();
    void updateTemperature();
    void updateGpu();

    // Helper methods
    bool readProcFile(int fd, char* buffer, size_t bufferSize);
    QString formatBytes(double bytes);

    // CPU state
    qreal m_cpuUsage = 0.0;
    int m_cpuTemp = 0;
    QString m_cpuModel;
    uint64_t m_lastCpuIdle = 0;
    uint64_t m_lastCpuTotal = 0;

    // RAM state
    qreal m_ramUsage = 0.0;
    QString m_ramUsed = QStringLiteral("0.0");
    QString m_ramTotal = QStringLiteral("0.0");

    // GPU state
    int m_gpuUsage = 0;
    int m_gpuTemp = 0;
    QString m_gpuModel;

    // Disk state
    qreal m_diskUsage = 0.0;
    QString m_diskUsed = QStringLiteral("0");
    QString m_diskTotal = QStringLiteral("0");

    // System info
    QString m_userName;

    // File descriptors (kept open for performance)
    int m_cpuStatFd = -1;
    int m_meminfoFd = -1;

    // Update timer
    QTimer m_updateTimer;
    bool m_isMonitoring = false;

    // Buffers (reused to avoid allocations)
    char m_cpuBuffer[2048];
    char m_memBuffer[4096];
};
