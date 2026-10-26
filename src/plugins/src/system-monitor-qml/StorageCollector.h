#pragma once

#include <QHash>
#include <QVariantList>
#include <QStringList>
#include <functional>

// Worker-only collector. Pure grouping/counter helpers also accept fixture data.
class StorageCollector {
public:
    struct Mount {
        QString path, source, fileSystem;
        bool readOnly = false;
    };
    struct Space {
        qint64 total = -1, available = -1;
        QString label;
        bool readOnly = false;
    };
    using Probe = std::function<Space(const Mount&)>;

    explicit StorageCollector(QString sysRoot = QStringLiteral("/sys"));
    void setOptions(const QVariantMap& options);
    void discover();
    void sampleIo(const QByteArray& diskstats, double elapsedSeconds);
    void resetIo();
    QVariantList volumes() const { return m_volumes; }
    QVariantList drives() const { return m_drives; }
    QVariantMap summary() const;
    double readSpeed() const { return m_readSpeed; }
    double writeSpeed() const { return m_writeSpeed; }
    bool hasIo() const { return m_hasIo; }
    static QList<Mount> parseMountInfo(const QByteArray& data);
    static QVariantList groupVolumes(const QList<Mount>& mounts, const Probe& probe,
                                    const QVariantMap& options = {});
    static QVariantMap summarizeVolumes(const QVariantList& volumes);
    static QString formatBytes(double bytes);
    static QString formatSpeed(double bytes);
    static QVariantMap defaultOptions();

private:
    struct Counters { quint64 read = 0, write = 0; QString generation; };
    QString m_sysRoot;
    QVariantMap m_options;
    QVariantList m_volumes, m_drives;
    QHash<QString, Counters> m_previous;
    double m_readSpeed = 0, m_writeSpeed = 0;
    bool m_hasIo = false;
};
