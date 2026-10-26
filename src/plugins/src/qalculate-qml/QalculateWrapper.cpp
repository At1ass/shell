#include "QalculateWrapper.h"
#include <libqalculate/qalculate.h>
#include <QFutureWatcher>
#include <QMutex>
#include <QMutexLocker>
#include <QtConcurrent>
#include <memory>
#include <mutex>

// CALCULATOR is a process-global libqalculate singleton and is not
// thread-safe: one static mutex serializes every evaluation (a per-instance
// mutex would guard nothing across engines). Initialization is lazy and
// happens on the first evaluating thread — never on the GUI thread.
static QMutex s_calcMutex;
static std::once_flag s_calcInitFlag;

static void ensureCalculator() {
    std::call_once(s_calcInitFlag, []() {
        static std::unique_ptr<Calculator> s_calculator(new Calculator());
        CALCULATOR = s_calculator.get();
        CALCULATOR->loadExchangeRates();
        CALCULATOR->loadGlobalDefinitions();
        CALCULATOR->loadLocalDefinitions();
    });
}

static QString evalInternal(const QString& expression, bool printExpr) {
    if (expression.isEmpty())
        return QString();

    QMutexLocker locker(&s_calcMutex);
    ensureCalculator();

    EvaluationOptions eo;
    PrintOptions po;

    std::string parsed;
    std::string result = CALCULATOR->calculateAndPrint(
        CALCULATOR->unlocalizeExpression(expression.toStdString(), eo.parse_options),
        100,  // max calculation time in ms
        eo,
        po,
        &parsed
    );

    std::string error;
    while (CALCULATOR->message()) {
        if (!CALCULATOR->message()->message().empty()) {
            if (CALCULATOR->message()->type() == MESSAGE_ERROR) {
                error += "error: ";
            } else if (CALCULATOR->message()->type() == MESSAGE_WARNING) {
                error += "warning: ";
            }
            error += CALCULATOR->message()->message();
        }
        CALCULATOR->nextMessage();
    }

    if (!error.empty()) {
        return QString::fromStdString(error);
    }

    if (printExpr) {
        return QString("%1 = %2")
            .arg(QString::fromStdString(parsed))
            .arg(QString::fromStdString(result));
    }

    return QString::fromStdString(result);
}

QalculateWrapper::QalculateWrapper(QObject* parent)
    : QObject(parent)
{
    // Deliberately empty: the calculator initializes lazily on the first
    // evaluation, on whichever pool thread performs it.
}

void QalculateWrapper::evalAsync(const QString& expression, bool printExpr) {
    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, expression]() {
        const auto result = watcher->result();
        watcher->deleteLater();
        emit evaluated(expression, result);
    });
    watcher->setFuture(QtConcurrent::run([expression, printExpr]() {
        return evalInternal(expression, printExpr);
    }));
}

QString QalculateWrapper::eval(const QString& expression, bool printExpr) {
    return evalInternal(expression, printExpr);
}
