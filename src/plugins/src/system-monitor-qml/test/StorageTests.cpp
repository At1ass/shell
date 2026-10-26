#include "StorageCollector.h"
#include <QTest>
#include <QTemporaryDir>
#include <QDir>
#include <QFile>

class StorageTests : public QObject {
    Q_OBJECT
    static void write(const QString& path, const QByteArray& content) {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(content), content.size());
    }
    static StorageCollector::Space space(const StorageCollector::Mount& mount) {
        return {1000, mount.path == QStringLiteral("/mnt/games") ? 20 : 500, {}, false};
    }
private slots:
    void mountEscapesAndFiltering() {
        const auto mounts = StorageCollector::parseMountInfo(
            "1 0 8:1 / / rw - btrfs /dev/sda1 rw\n"
            "2 0 8:2 / /media/My\\040Disk rw - ext4 /dev/sdb1 rw\n"
            "3 0 0:2 / /remote rw - nfs server:/dir rw\n"
            "4 0 0:3 / /run rw - tmpfs tmpfs rw\n"
            "5 0 7:0 / /image ro - squashfs /dev/loop0 ro\n"
            "bad data\n");
        QCOMPARE(mounts.size(), 2);
        QCOMPARE(mounts[1].path, QStringLiteral("/media/My Disk"));
    }
    void aliasesDoNotDuplicateCapacity() {
        const QList<StorageCollector::Mount> mounts{
            {"/home", "/dev/nvme1n1p2", "btrfs", false},
            {"/.snapshots", "/dev/nvme1n1p2", "btrfs", true},
            {"/", "/dev/nvme1n1p2", "btrfs", false},
            {"/efi", "/dev/nvme1n1p1", "vfat", false},
            {"/mnt/games", "/dev/nvme0n1p1", "xfs", false}};
        const auto volumes = StorageCollector::groupVolumes(mounts, space);
        QCOMPARE(volumes.size(), 2);
        const auto root = volumes[0].toMap();
        QCOMPARE(root["mountPoint"].toString(), QStringLiteral("/"));
        QCOMPARE(root["mountPoints"].toStringList().size(), 3);
        QCOMPARE(root["severity"].toInt(), 0);
        QCOMPARE(volumes[1].toMap()["severity"].toInt(), 2);
    }
    void labelsOrderAndThresholds() {
        const QList<StorageCollector::Mount> mounts{{"/", "/dev/a", "ext4", false}, {"/mnt/games", "/dev/b", "xfs", false}};
        const QVariantMap options{{"order", QStringList{"/mnt/games", "/"}},
            {"labels", QVariantMap{{"/mnt/games", "Games"}}}, {"warningFreePercent", 1}, {"criticalFreePercent", 5}};
        const auto volumes = StorageCollector::groupVolumes(mounts, space, options);
        QCOMPARE(volumes[0].toMap()["name"].toString(), QStringLiteral("Games"));
        QCOMPARE(volumes[0].toMap()["severity"].toInt(), 0);
    }
    void missingAndReadOnlyNeverWarn() {
        const QList<StorageCollector::Mount> mounts{{"/ro", "/dev/a", "ext4", true}, {"/missing", "/dev/b", "ext4", false}};
        const auto volumes = StorageCollector::groupVolumes(mounts, [](const auto& mount) {
            return mount.readOnly ? StorageCollector::Space{100, 0, {}, true} : StorageCollector::Space{};
        });
        for (const auto& volume : volumes) QCOMPARE(volume.toMap()["severity"].toInt(), 0);
    }
    void warningsSelectMostUrgentVolume() {
        const QList<StorageCollector::Mount> mounts{{"/", "/dev/a", "btrfs", false},
            {"/mnt/games", "/dev/b", "xfs", false}, {"/mnt/other", "/dev/c", "ext4", false}};
        auto volumes = StorageCollector::groupVolumes(mounts, [](const auto& mount) {
            return StorageCollector::Space{1000, mount.path == "/" ? 500 : mount.path == "/mnt/games" ? 20 : 80, {}, false};
        });
        const auto summary = StorageCollector::summarizeVolumes(volumes);
        QCOMPARE(summary["mountPoint"].toString(), QStringLiteral("/mnt/games"));
        QCOMPARE(summary["criticalCount"].toInt(), 1);
        QCOMPARE(summary["warningCount"].toInt(), 1);
        QVERIFY(summary["available"].toBool());
        QVERIFY(!StorageCollector::summarizeVolumes({})["available"].toBool());
    }
    void thresholdBoundaries_data() {
        QTest::addColumn<qint64>("free");
        QTest::addColumn<int>("severity");
        QTest::newRow("empty") << qint64(0) << 2;
        QTest::newRow("critical-boundary") << qint64(50) << 2;
        QTest::newRow("warning") << qint64(80) << 1;
        QTest::newRow("warning-boundary") << qint64(100) << 1;
        QTest::newRow("healthy") << qint64(110) << 0;
        QTest::newRow("missing") << qint64(-1) << 0;
    }
    void thresholdBoundaries() {
        QFETCH(qint64, free);
        QFETCH(int, severity);
        const auto volumes = StorageCollector::groupVolumes({{"/", "/dev/a", "ext4", false}},
            [&](const auto&) { return StorageCollector::Space{1000, free, {}, false}; });
        QCOMPARE(volumes.first().toMap()["severity"].toInt(), severity);
    }
    void aggregateLeafDevicesAndReset() {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        for (const auto& name : {QStringLiteral("sda"), QStringLiteral("sdb")}) {
            write(temp.path() + "/block/" + name + "/size", "10000");
            write(temp.path() + "/block/" + name + "/diskseq", "1");
        }
        StorageCollector collector(temp.path());
        collector.discover();
        QCOMPARE(collector.drives().size(), 2);
        collector.sampleIo("8 0 sda 1 0 100 0 1 0 200 0 0 0 0\n8 16 sdb 1 0 100 0 1 0 200 0 0 0 0\n", 2);
        QCOMPARE(collector.readSpeed(), 0);
        collector.sampleIo("8 0 sda 1 0 104 0 1 0 208 0 0 0 0\n8 1 sda1 1 0 99999 0 1 0 99999 0 0 0 0\n8 16 sdb 1 0 106 0 1 0 210 0 0 0 0\n", 2);
        QCOMPARE(collector.readSpeed(), 2560);
        QCOMPARE(collector.writeSpeed(), 4608);
        collector.sampleIo("8 0 sda 1 0 1 0 1 0 2 0 0 0 0\n", 2);
        QCOMPARE(collector.readSpeed(), 0);
        write(temp.path() + "/block/sda/diskseq", "2");
        collector.sampleIo("8 0 sda 1 0 99999 0 1 0 99999 0 0 0 0\n", 2);
        QCOMPARE(collector.readSpeed(), 0);
        collector.resetIo();
        collector.sampleIo("8 0 sda 1 0 100001 0 1 0 100001 0 0 0 0\n", 2);
        QCOMPARE(collector.readSpeed(), 0);
        collector.sampleIo({}, 2);
        QVERIFY(!collector.hasIo());
    }
};
QTEST_GUILESS_MAIN(StorageTests)
#include "StorageTests.moc"
