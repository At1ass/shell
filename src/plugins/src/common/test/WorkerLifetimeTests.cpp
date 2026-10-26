#include "../WorkerLifetime.h"
#include <QElapsedTimer>
#include <QPointer>
#include <QSemaphore>
#include <QTest>

class WorkerLifetimeTests : public QObject {
    Q_OBJECT
private slots:
    void retirementDoesNotWaitForBusyWorker() {
        QSemaphore entered, release;
        auto* worker = new QObject;
        QPointer<QObject> workerGuard(worker);
        auto* thread = WorkerLifetime::create(worker);
        QPointer<QThread> threadGuard(thread);
        QMetaObject::invokeMethod(worker, [&] {
            entered.release();
            release.acquire();
        }, Qt::QueuedConnection);
        thread->start();
        QVERIFY(entered.tryAcquire(1, 2000));
        QElapsedTimer timer;
        timer.start();
        WorkerLifetime::retire(thread);
        const auto elapsed = timer.elapsed();
        // Release before assertions so a failed assertion never strands a worker.
        release.release();
        QVERIFY(thread == nullptr);
        QVERIFY2(elapsed < 100, "Retirement blocked the caller");
        QTRY_VERIFY_WITH_TIMEOUT(workerGuard.isNull(), 2000);
        QTRY_VERIFY_WITH_TIMEOUT(threadGuard.isNull(), 2000);
    }
};
QTEST_GUILESS_MAIN(WorkerLifetimeTests)
#include "WorkerLifetimeTests.moc"
