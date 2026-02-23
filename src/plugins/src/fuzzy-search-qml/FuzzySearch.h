#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QQmlEngine>

class FuzzySearch : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit FuzzySearch(QObject* parent = nullptr);

    // Возвращает score (0.0–100.0) для пары query/candidate.
    // 0.0 = нет совпадения.
    Q_INVOKABLE double score(const QString& query, const QString& candidate) const;

    // Batch-поиск: возвращает [{index, score}] — топ maxResults из candidates.
    // scoreCutoff — минимальный порог (по умолчанию 30.0).
    Q_INVOKABLE QVariantList match(
        const QString& query,
        const QStringList& candidates,
        int maxResults = 10,
        double scoreCutoff = 30.0
    ) const;
};
