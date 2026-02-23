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

    // Score для пары query/candidate (0.0–100.0).
    Q_INVOKABLE double score(const QString& query, const QString& candidate) const;

    // Batch-поиск по одному полю: [{index, score}].
    Q_INVOKABLE QVariantList match(
        const QString& query,
        const QStringList& candidates,
        int maxResults = 10,
        double scoreCutoff = 30.0
    ) const;

    // Взвешенный поиск: совпадение в names весит больше, чем в fullTexts.
    // Для каждого элемента i:
    //   nameScore  = rapidfuzz(query, names[i])  — с бонусом за prefix
    //   textScore  = rapidfuzz(query, fullTexts[i])
    //   finalScore = max(nameScore * nameWeight, textScore)
    // Возвращает [{index, score}] — топ maxResults.
    Q_INVOKABLE QVariantList matchWeighted(
        const QString& query,
        const QStringList& names,
        const QStringList& fullTexts,
        int maxResults = 10,
        double scoreCutoff = 30.0,
        double nameWeight = 2.5
    ) const;
};
