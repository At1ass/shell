#include "FuzzySearch.h"

#include <algorithm>
#include <vector>
#include <string>
#include <cmath>

#include <rapidfuzz/fuzz.hpp>

FuzzySearch::FuzzySearch(QObject* parent) : QObject(parent) {}

// ─── Helpers ────────────────────────────────────────────────────────────────

namespace {

struct Hit {
    int index;
    double score;
};

inline bool startsWith(const std::wstring& str, const std::wstring& prefix)
{
    return str.size() >= prefix.size()
        && str.compare(0, prefix.size(), prefix) == 0;
}

inline int clampMax(int v, int lo, int hi) { return std::max(lo, std::min(v, hi)); }
inline double clampCutoff(double v) { return std::isfinite(v) ? std::max(0.0, std::min(v, 100.0)) : 0.0; }

} // namespace

// ─── score() ────────────────────────────────────────────────────────────────

double FuzzySearch::score(const QString& query, const QString& candidate) const
{
    if (query.isEmpty() || candidate.isEmpty()) return 0.0;

    const std::wstring q = query.toLower().toStdWString();
    const std::wstring c = candidate.toLower().toStdWString();

    if (startsWith(c, q))
        return 100.0;

    return rapidfuzz::fuzz::partial_ratio(q, c);
}

// ─── match() — single-field ─────────────────────────────────────────────────

QVariantList FuzzySearch::match(
    const QString& query,
    const QStringList& candidates,
    int maxResults,
    double scoreCutoff
) const
{
    if (query.isEmpty() || candidates.isEmpty()) return {};

    maxResults = clampMax(maxResults, 1, 1000);
    scoreCutoff = clampCutoff(scoreCutoff);

    const std::wstring q = query.toLower().toStdWString();
    rapidfuzz::fuzz::CachedPartialRatio<wchar_t> scorer(q);

    std::vector<Hit> hits;
    hits.reserve(std::min(candidates.size(), qsizetype(256)));

    for (int i = 0; i < candidates.size(); ++i) {
        const std::wstring c = candidates[i].toLower().toStdWString();

        double s;
        if (startsWith(c, q)) {
            s = 100.0;
        } else {
            s = scorer.similarity(c, scoreCutoff);
            if (s < scoreCutoff) continue;
        }
        hits.push_back({i, s});
    }

    const auto n = std::min(static_cast<size_t>(maxResults), hits.size());
    std::partial_sort(hits.begin(), hits.begin() + static_cast<ptrdiff_t>(n), hits.end(),
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

// ─── matchWeighted() — name vs fullText ─────────────────────────────────────

QVariantList FuzzySearch::matchWeighted(
    const QString& query,
    const QStringList& names,
    const QStringList& fullTexts,
    int maxResults,
    double scoreCutoff,
    double nameWeight
) const
{
    if (query.isEmpty() || names.isEmpty()) return {};

    maxResults = clampMax(maxResults, 1, 1000);
    scoreCutoff = clampCutoff(scoreCutoff);
    if (!std::isfinite(nameWeight) || nameWeight < 1.0) nameWeight = 1.0;

    const int count = names.size();
    const bool hasFullTexts = fullTexts.size() == count;

    const std::wstring q = query.toLower().toStdWString();
    rapidfuzz::fuzz::CachedPartialRatio<wchar_t> scorer(q);

    std::vector<Hit> hits;
    hits.reserve(std::min(count, 256));

    for (int i = 0; i < count; ++i) {
        const std::wstring name = names[i].toLower().toStdWString();

        // Бонус за точный prefix в имени — максимальный приоритет
        double nameScore;
        if (startsWith(name, q)) {
            // Бонус за точность: точное совпадение имени > prefix > partial
            nameScore = (name.size() == q.size()) ? 110.0 : 100.0;
        } else {
            nameScore = scorer.similarity(name, 0.0);
        }

        // Применяем вес к name score
        double finalScore = nameScore * nameWeight;

        // Проверяем fullText только если name score недостаточен
        if (hasFullTexts && finalScore < scoreCutoff) {
            const std::wstring text = fullTexts[i].toLower().toStdWString();
            double textScore = startsWith(text, q)
                ? 100.0
                : scorer.similarity(text, scoreCutoff);
            finalScore = std::max(finalScore, textScore);
        }

        if (finalScore < scoreCutoff) continue;
        hits.push_back({i, finalScore});
    }

    const auto n = std::min(static_cast<size_t>(maxResults), hits.size());
    std::partial_sort(hits.begin(), hits.begin() + static_cast<ptrdiff_t>(n), hits.end(),
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
