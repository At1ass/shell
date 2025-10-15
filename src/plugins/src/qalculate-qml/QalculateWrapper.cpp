#include "QalculateWrapper.h"
#include <libqalculate/qalculate.h>
#include <QDebug>

QalculateWrapper::QalculateWrapper(QObject* parent)
    : QObject(parent)
{
    // Инициализируем глобальный CALCULATOR если еще не создан
    if (!CALCULATOR) {
        new Calculator();
        CALCULATOR->loadExchangeRates();
        CALCULATOR->loadGlobalDefinitions();
        CALCULATOR->loadLocalDefinitions();

        qDebug() << "QalculateWrapper: Initialized with libqalculate";
    }
}

QString QalculateWrapper::eval(const QString& expression, bool printExpr) const {
    if (expression.isEmpty()) {
        return QString();
    }

    EvaluationOptions eo;
    PrintOptions po;

    std::string parsed;

    // calculateAndPrint делает все в одном вызове
    std::string result = CALCULATOR->calculateAndPrint(
        CALCULATOR->unlocalizeExpression(expression.toStdString(), eo.parse_options),
        100,  // max time in ms
        eo,
        po,
        &parsed  // сюда запишется распарсенное выражение
    );

    // Собираем ошибки и предупреждения
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

    // Если есть ошибки - возвращаем их
    if (!error.empty()) {
        return QString::fromStdString(error);
    }

    // Возвращаем результат
    if (printExpr) {
        return QString("%1 = %2")
            .arg(QString::fromStdString(parsed))
            .arg(QString::fromStdString(result));
    }

    return QString::fromStdString(result);
}
