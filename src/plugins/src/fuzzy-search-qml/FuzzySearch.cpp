#include "FuzzySearch.h"

#include <algorithm>
#include <vector>
#include <string>

#include <rapidfuzz/fuzz.hpp>

FuzzySearch::FuzzySearch(QObject* parent) : QObject(parent) {}

double FuzzySearch::score(const QString& query, const QString& candidate) const
{
    if (query.isEmpty()) return 0.0;
    if (candidate.isEmpty()) return 0.0;

    const std::wstring q = query.toLower().toStdWString();
    const std::wstring c = candidate.toLower().toStdWString();

    // Бонус за точное вхождение подстроки с начала
    if (c.compare(0, q.size(), q) == 0)
        return 100.0;

    // partial_ratio отлично работает для substring + subsequence
    return rapidfuzz::fuzz::partial_ratio(q, c);
}

QVariantList FuzzySearch::match(
    const QString& query,
    const QStringList& candidates,
    int maxResults,
    double scoreCutoff
) const
{
    if (query.isEmpty() || candidates.isEmpty())
        return {};

    const std::wstring q = query.toLower().toStdWString();
    rapidfuzz::fuzz::CachedPartialRatio<wchar_t> scorer(q);

    struct Hit {
        int index;
        double score;
    };

    std::vector<Hit> hits;
    hits.reserve(std::min(candidates.size(), qsizetype(256)));

    for (int i = 0; i < candidates.size(); ++i) {
        const std::wstring c = candidates[i].toLower().toStdWString();

        double s;
        // Prefix bonus — максимальный приоритет
        if (c.compare(0, q.size(), q) == 0) {
            s = 100.0;
        } else {
            s = scorer.similarity(c, scoreCutoff);
            if (s < scoreCutoff)
                continue;
        }

        hits.push_back({i, s});
    }

    // partial_sort для top-N без полной сортировки
    const auto n = std::min(static_cast<size_t>(maxResults), hits.size());
    std::partial_sort(hits.begin(), hits.begin() + n, hits.end(),
        [](const Hit& a, const Hit& b) { return a.score > b.score; });

    QVariantList result;
    result.reserve(static_cast<int>(n));
    for (size_t i = 0; i < n; ++i) {
        QVariantMap entry;
        entry[QStringLiteral("index")] = hits[i].index;
        entry[QStringLiteral("score")] = hits[i].score;
        result.append(entry);
    }
    return result;
}
