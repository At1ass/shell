#include "../McuTheme.h"
#include <QImage>
#include <QElapsedTimer>
#include <QSemaphore>
#include <QtConcurrent>
#include <thread>
#include <chrono>
#include <QTemporaryDir>
#include <QThreadPool>
#include <QTest>

class McuThemeTests : public QObject {
    Q_OBJECT
private slots:
    void colorSupersedesImageExtraction() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QImage image(32, 32, QImage::Format_RGB32);
        image.fill(Qt::red);
        const auto path = dir.filePath("red.png");
        QVERIFY(image.save(path));
        McuTheme theme;
        theme.setSource(QUrl::fromLocalFile(path));
        theme.setSource(QColor(Qt::green));
        QVERIFY(QThreadPool::globalInstance()->waitForDone(5000));
        QTRY_VERIFY_WITH_TIMEOUT(!theme.loading() && theme.valid(), 5000);
        QCOMPARE(theme.source().value<QColor>(), QColor(Qt::green));
        QVERIFY(qAbs(theme.luminance() - 0.7152) < 0.0001);
    }
    void destructionDoesNotWaitForQueuedTask() {
        auto* pool = QThreadPool::globalInstance();
        const int previousLimit = pool->maxThreadCount();
        pool->setMaxThreadCount(1);
        QSemaphore entered, release;
        const auto blocker = QtConcurrent::run([&] {
            entered.release();
            release.acquire();
        });
        const bool started = entered.tryAcquire(1, 2000);
        auto* theme = new McuTheme;
        std::thread unblock([&] {
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            release.release();
        });
        QElapsedTimer timer;
        timer.start();
        delete theme;
        const auto elapsed = timer.elapsed();
        unblock.join();
        const bool drained = pool->waitForDone(5000);
        pool->setMaxThreadCount(previousLimit);
        QVERIFY(started);
        QVERIFY(drained);
        QVERIFY2(elapsed < 100, "Destruction waited for unrelated thread-pool work");
        QCoreApplication::processEvents();
    }
    void destructionAllowsOutstandingResultsToDrain() {
        auto* theme = new McuTheme;
        theme->setContrast(0.5);
        delete theme;
        QVERIFY(QThreadPool::globalInstance()->waitForDone(5000));
        QCoreApplication::processEvents(); // weak result receivers must be inert
    }
};
QTEST_GUILESS_MAIN(McuThemeTests)
#include "McuThemeTests.moc"
