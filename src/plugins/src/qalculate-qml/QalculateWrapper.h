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

    // Asynchronous evaluation on a pool thread — the UI thread never pays
    // for libqalculate init (~100-300 ms) or the per-call timeout budget.
    // The result arrives via evaluated(expression, result); expression is
    // echoed verbatim so callers can match request and response.
    Q_INVOKABLE void evalAsync(const QString& expression, bool printExpr = false);

    // Synchronous evaluation. Blocks the CALLING thread up to the internal
    // calculation timeout; avoid on the UI thread — prefer evalAsync.
    Q_INVOKABLE QString eval(const QString& expression, bool printExpr = false);

signals:
    void evaluated(const QString& expression, const QString& result);
};
