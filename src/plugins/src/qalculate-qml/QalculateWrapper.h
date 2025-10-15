#pragma once
#include <QObject>
#include <QString>
#include <QQmlEngine>

class QalculateWrapper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit QalculateWrapper(QObject* parent = nullptr);

    // Основной метод для вычислений
    // printExpr - включить выражение в результат (например: "2+2 = 4")
    Q_INVOKABLE QString eval(const QString& expression, bool printExpr = false) const;
};
