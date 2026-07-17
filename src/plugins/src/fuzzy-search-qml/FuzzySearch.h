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

    // Score for a query/candidate pair (0.0-100.0).
    Q_INVOKABLE double score(const QString& query, const QString& candidate) const;

    // Batch search over one field: [{index, score}].
    Q_INVOKABLE QVariantList match(
        const QString& query,
        const QStringList& candidates,
        int maxResults = 10,
        double scoreCutoff = 30.0
    ) const;

    // Weighted search: a match in names weighs more than one in fullTexts.
    // For each element i:
    //   nameScore  = rapidfuzz(query, names[i])  with a prefix bonus
    //   textScore  = rapidfuzz(query, fullTexts[i])
    //   finalScore = max(nameScore * nameWeight, textScore)
    // Returns [{index, score}] - top maxResults.
    Q_INVOKABLE QVariantList matchWeighted(
        const QString& query,
        const QStringList& names,
        const QStringList& fullTexts,
        int maxResults = 10,
        double scoreCutoff = 30.0,
        double nameWeight = 2.5
    ) const;
};
