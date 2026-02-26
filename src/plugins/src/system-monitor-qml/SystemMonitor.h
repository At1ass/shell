#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtCore/QThread>
#include <QtCore/QAtomicInt>
#include <QtQml/QQmlEngine>
#include <memory>

class StatsWorker;

enum class GpuBackend { None, Nvml, AmdSysfs };

struct StatsSnapshot {
    qreal cpuUsage = 0.0;
    int cpuTemp = 0;
    QString cpuModel;

    // CPU extensions
    qreal cpuFreqGHz = 0.0;
    qreal loadAvg1 = 0.0, loadAvg5 = 0.0, loadAvg15 = 0.0;

    qreal ramUsage = 0.0;
    QString ramUsed;
    QString ramTotal;

    // Swap
    qreal swapUsage = 0.0;
    QString swapUsed, swapTotal;
    bool hasSwap = false;

    int gpuUsage = 0;
    int gpuTemp = 0;
    QString gpuModel;

    // GPU extensions (NVML or AMD sysfs)
    qreal gpuMemUsage = 0.0;
    QString gpuMemUsed, gpuMemTotal;
    int gpuClockMHz = 0, gpuFanSpeed = 0, gpuPowerWatts = 0;

    qreal diskUsage = 0.0;
    QString diskUsed;
    QString diskTotal;

    // Disk I/O
    double diskReadSpeed = 0.0, diskWriteSpeed = 0.0;
    QString diskReadFormatted, diskWriteFormatted;
    bool hasDiskIo = false;

    // Network
    double netRxSpeed = 0.0, netTxSpeed = 0.0;  // bytes/sec
    QString netRxFormatted, netTxFormatted, netInterface;
    bool hasNet = false;

    bool hasCpuTemp = false;
    bool hasGpuStats = false;
};

Q_DECLARE_METATYPE(StatsSnapshot)

class SystemMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // CPU properties
    Q_PROPERTY(qreal cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(int cpuTemp READ cpuTemp NOTIFY cpuTempChanged)
    Q_PROPERTY(QString cpuModel READ cpuModel NOTIFY cpuModelChanged)
    Q_PROPERTY(qreal cpuFreqGHz READ cpuFreqGHz NOTIFY cpuFreqGHzChanged)
    Q_PROPERTY(qreal loadAvg1 READ loadAvg1 NOTIFY loadAvg1Changed)
    Q_PROPERTY(qreal loadAvg5 READ loadAvg5 NOTIFY loadAvg5Changed)
    Q_PROPERTY(qreal loadAvg15 READ loadAvg15 NOTIFY loadAvg15Changed)

    // RAM properties
    Q_PROPERTY(qreal ramUsage READ ramUsage NOTIFY ramUsageChanged)
    Q_PROPERTY(QString ramUsed READ ramUsed NOTIFY ramUsedChanged)
    Q_PROPERTY(QString ramTotal READ ramTotal NOTIFY ramTotalChanged)

    // Swap properties
    Q_PROPERTY(qreal swapUsage READ swapUsage NOTIFY swapUsageChanged)
    Q_PROPERTY(QString swapUsed READ swapUsed NOTIFY swapUsedChanged)
    Q_PROPERTY(QString swapTotal READ swapTotal NOTIFY swapTotalChanged)
    Q_PROPERTY(bool hasSwap READ hasSwap NOTIFY hasSwapChanged)

    // GPU properties
    Q_PROPERTY(int gpuUsage READ gpuUsage NOTIFY gpuUsageChanged)
    Q_PROPERTY(int gpuTemp READ gpuTemp NOTIFY gpuTempChanged)
    Q_PROPERTY(QString gpuModel READ gpuModel NOTIFY gpuModelChanged)
    Q_PROPERTY(qreal gpuMemUsage READ gpuMemUsage NOTIFY gpuMemUsageChanged)
    Q_PROPERTY(QString gpuMemUsed READ gpuMemUsed NOTIFY gpuMemUsedChanged)
    Q_PROPERTY(QString gpuMemTotal READ gpuMemTotal NOTIFY gpuMemTotalChanged)
    Q_PROPERTY(int gpuClockMHz READ gpuClockMHz NOTIFY gpuClockMHzChanged)
    Q_PROPERTY(int gpuFanSpeed READ gpuFanSpeed NOTIFY gpuFanSpeedChanged)
    Q_PROPERTY(int gpuPowerWatts READ gpuPowerWatts NOTIFY gpuPowerWattsChanged)

    // Disk properties
    Q_PROPERTY(qreal diskUsage READ diskUsage NOTIFY diskUsageChanged)
    Q_PROPERTY(QString diskUsed READ diskUsed NOTIFY diskUsedChanged)
    Q_PROPERTY(QString diskTotal READ diskTotal NOTIFY diskTotalChanged)
    Q_PROPERTY(double diskReadSpeed READ diskReadSpeed NOTIFY diskReadSpeedChanged)
    Q_PROPERTY(double diskWriteSpeed READ diskWriteSpeed NOTIFY diskWriteSpeedChanged)
    Q_PROPERTY(QString diskReadFormatted READ diskReadFormatted NOTIFY diskReadFormattedChanged)
    Q_PROPERTY(QString diskWriteFormatted READ diskWriteFormatted NOTIFY diskWriteFormattedChanged)
    Q_PROPERTY(bool hasDiskIo READ hasDiskIo NOTIFY hasDiskIoChanged)

    // Network properties
    Q_PROPERTY(double netRxSpeed READ netRxSpeed NOTIFY netRxSpeedChanged)
    Q_PROPERTY(double netTxSpeed READ netTxSpeed NOTIFY netTxSpeedChanged)
    Q_PROPERTY(QString netRxFormatted READ netRxFormatted NOTIFY netRxFormattedChanged)
    Q_PROPERTY(QString netTxFormatted READ netTxFormatted NOTIFY netTxFormattedChanged)
    Q_PROPERTY(QString netInterface READ netInterface NOTIFY netInterfaceChanged)
    Q_PROPERTY(bool hasNet READ hasNet NOTIFY hasNetChanged)

    // System info
    Q_PROPERTY(QString userName READ userName NOTIFY userNameChanged)
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString wmName READ wmName CONSTANT)

    // Status
    Q_PROPERTY(bool isMonitoring READ isMonitoring NOTIFY isMonitoringChanged)
    Q_PROPERTY(bool hasCpuTemp READ hasCpuTemp NOTIFY hasCpuTempChanged)
    Q_PROPERTY(bool hasGpuStats READ hasGpuStats NOTIFY hasGpuStatsChanged)

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
    qreal cpuFreqGHz() const { return m_cpuFreqGHz; }
    qreal loadAvg1() const { return m_loadAvg1; }
    qreal loadAvg5() const { return m_loadAvg5; }
    qreal loadAvg15() const { return m_loadAvg15; }

    // RAM getters
    qreal ramUsage() const { return m_ramUsage; }
    QString ramUsed() const { return m_ramUsed; }
    QString ramTotal() const { return m_ramTotal; }

    // Swap getters
    qreal swapUsage() const { return m_swapUsage; }
    QString swapUsed() const { return m_swapUsed; }
    QString swapTotal() const { return m_swapTotal; }
    bool hasSwap() const { return m_hasSwap; }

    // GPU getters
    int gpuUsage() const { return m_gpuUsage; }
    int gpuTemp() const { return m_gpuTemp; }
    QString gpuModel() const { return m_gpuModel; }
    qreal gpuMemUsage() const { return m_gpuMemUsage; }
    QString gpuMemUsed() const { return m_gpuMemUsed; }
    QString gpuMemTotal() const { return m_gpuMemTotal; }
    int gpuClockMHz() const { return m_gpuClockMHz; }
    int gpuFanSpeed() const { return m_gpuFanSpeed; }
    int gpuPowerWatts() const { return m_gpuPowerWatts; }

    // Disk getters
    qreal diskUsage() const { return m_diskUsage; }
    QString diskUsed() const { return m_diskUsed; }
    QString diskTotal() const { return m_diskTotal; }
    double diskReadSpeed() const { return m_diskReadSpeed; }
    double diskWriteSpeed() const { return m_diskWriteSpeed; }
    QString diskReadFormatted() const { return m_diskReadFormatted; }
    QString diskWriteFormatted() const { return m_diskWriteFormatted; }
    bool hasDiskIo() const { return m_hasDiskIo; }

    // Network getters
    double netRxSpeed() const { return m_netRxSpeed; }
    double netTxSpeed() const { return m_netTxSpeed; }
    QString netRxFormatted() const { return m_netRxFormatted; }
    QString netTxFormatted() const { return m_netTxFormatted; }
    QString netInterface() const { return m_netInterface; }
    bool hasNet() const { return m_hasNet; }

    // System info getters
    QString userName() const { return m_userName; }
    QString osName() const { return m_osName; }
    QString wmName() const { return m_wmName; }

    bool isMonitoring() const { return m_isMonitoring; }
    bool hasCpuTemp() const { return m_hasCpuTemp; }
    bool hasGpuStats() const { return m_hasGpuStats; }

public slots:
    void setUpdateInterval(int milliseconds);
    void refresh();

signals:
    void cpuUsageChanged();
    void cpuTempChanged();
    void cpuModelChanged();
    void cpuFreqGHzChanged();
    void loadAvg1Changed();
    void loadAvg5Changed();
    void loadAvg15Changed();
    void ramUsageChanged();
    void ramUsedChanged();
    void ramTotalChanged();
    void swapUsageChanged();
    void swapUsedChanged();
    void swapTotalChanged();
    void hasSwapChanged();
    void gpuUsageChanged();
    void gpuTempChanged();
    void gpuModelChanged();
    void gpuMemUsageChanged();
    void gpuMemUsedChanged();
    void gpuMemTotalChanged();
    void gpuClockMHzChanged();
    void gpuFanSpeedChanged();
    void gpuPowerWattsChanged();
    void diskUsageChanged();
    void diskUsedChanged();
    void diskTotalChanged();
    void diskReadSpeedChanged();
    void diskWriteSpeedChanged();
    void diskReadFormattedChanged();
    void diskWriteFormattedChanged();
    void hasDiskIoChanged();
    void netRxSpeedChanged();
    void netTxSpeedChanged();
    void netRxFormattedChanged();
    void netTxFormattedChanged();
    void netInterfaceChanged();
    void hasNetChanged();
    void userNameChanged();
    void isMonitoringChanged();
    void hasCpuTempChanged();
    void hasGpuStatsChanged();
    void statsUpdated();  // Batch signal for UI
    void errorOccurred(const QString& message);

private slots:
    void handleSnapshot(const StatsSnapshot& snapshot);

private:
    void initializeStaticInfo();
    void stopWorker();

    // CPU state
    qreal m_cpuUsage = 0.0;
    int m_cpuTemp = 0;
    QString m_cpuModel;
    qreal m_cpuFreqGHz = 0.0;
    qreal m_loadAvg1 = 0.0, m_loadAvg5 = 0.0, m_loadAvg15 = 0.0;
    uint64_t m_lastCpuIdle = 0;
    uint64_t m_lastCpuTotal = 0;

    // RAM state
    qreal m_ramUsage = 0.0;
    QString m_ramUsed = QStringLiteral("0.0");
    QString m_ramTotal = QStringLiteral("0.0");

    // Swap state
    qreal m_swapUsage = 0.0;
    QString m_swapUsed = QStringLiteral("0.0");
    QString m_swapTotal = QStringLiteral("0.0");
    bool m_hasSwap = false;

    // GPU state
    int m_gpuUsage = 0;
    int m_gpuTemp = 0;
    QString m_gpuModel;
    qreal m_gpuMemUsage = 0.0;
    QString m_gpuMemUsed;
    QString m_gpuMemTotal;
    int m_gpuClockMHz = 0;
    int m_gpuFanSpeed = 0;
    int m_gpuPowerWatts = 0;

    // Disk state
    qreal m_diskUsage = 0.0;
    QString m_diskUsed = QStringLiteral("0");
    QString m_diskTotal = QStringLiteral("0");
    double m_diskReadSpeed = 0.0;
    double m_diskWriteSpeed = 0.0;
    QString m_diskReadFormatted;
    QString m_diskWriteFormatted;
    bool m_hasDiskIo = false;

    // Network state
    double m_netRxSpeed = 0.0;
    double m_netTxSpeed = 0.0;
    QString m_netRxFormatted;
    QString m_netTxFormatted;
    QString m_netInterface;
    bool m_hasNet = false;

    // System info
    QString m_userName;
    QString m_osName;
    QString m_wmName;

    bool m_isMonitoring = false;
    bool m_hasCpuTemp = false;
    bool m_hasGpuStats = false;

    // Worker thread
    QThread m_workerThread;
    StatsWorker* m_worker = nullptr;
};
