#include "HistoryFilterModel.h"

#include <QRegularExpression>
#include <cmath>
#include <limits>

HistoryFilterModel::HistoryFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent) {
    connect(this, &QAbstractItemModel::rowsInserted, this,
            [this] { changed(); });
    connect(this, &QAbstractItemModel::rowsRemoved, this,
            [this] { changed(); });
    connect(this, &QAbstractItemModel::rowsMoved, this, [this] { changed(); });
    connect(this, &QAbstractItemModel::modelReset, this, [this] { changed(); });
    connect(this, &QAbstractItemModel::layoutChanged, this,
            [this] { changed(); });
    connect(this, &QAbstractItemModel::dataChanged, this,
            [this] { changed(); });
}
void HistoryFilterModel::changed() {
    m_groupsDirty = true;
    m_revision =
        m_revision == std::numeric_limits<int>::max() ? 0 : m_revision + 1;
    emit countChanged();
    emit revisionChanged();
}
void HistoryFilterModel::setSourceModel(QAbstractItemModel* source) {
    QSortFilterProxyModel::setSourceModel(source);
    changed();
}
void HistoryFilterModel::setQuery(QString const& value) {
    if (value == m_query) return;
    beginFilterChange();
    m_query = value;
    m_terms = value.toCaseFolded().split(
        QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    endFilterChange(Direction::Rows);
    changed();
    emit queryChanged();
}
void HistoryFilterModel::setSince(double value) {
    if (!std::isfinite(value) || value < 0 || m_since == value) return;
    beginFilterChange();
    m_since = value;
    endFilterChange(Direction::Rows);
    changed();
    emit sinceChanged();
}
int HistoryFilterModel::role(QByteArray const& name) const {
    return sourceModel() ? sourceModel()->roleNames().key(name, -1) : -1;
}
bool HistoryFilterModel::filterAcceptsRow(int row,
                                          QModelIndex const& parent) const {
    auto const* source = sourceModel();
    if (!source) return false;
    auto const index = source->index(row, 0, parent);
    if (m_since > 0 &&
        source->data(index, role("timestamp")).toDouble() < m_since)
        return false;
    if (m_terms.isEmpty()) return true;
    QString text =
        source->data(index, role("appName")).toString() + QLatin1Char(' ') +
        source->data(index, role("summary")).toString() + QLatin1Char(' ');
    auto const body = source->data(index, role("body")).toString();
    // Linear markup removal; malformed repeated '<' must not make a regex
    // backtrack over an untrusted notification body on the UI thread.
    qsizetype position = 0;
    while (position < body.size()) {
        auto const open = body.indexOf(QLatin1Char('<'), position);
        if (open < 0) {
            text += body.mid(position);
            break;
        }
        text += body.mid(position, open - position);
        auto const close = body.indexOf(QLatin1Char('>'), open + 1);
        if (close < 0) {
            text += body.mid(open);
            break;
        }
        position = close + 1;
    }
    text = text.toCaseFolded();
    for (auto const& term : m_terms)
        if (!text.contains(term)) return false;
    return true;
}
QVariantMap HistoryFilterModel::get(int row) const {
    QVariantMap result;
    if (row < 0 || row >= rowCount()) return result;
    auto const item = index(row, 0);
    auto const roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it)
        result.insert(QString::fromUtf8(it.value()), data(item, it.key()));
    return result;
}
int HistoryFilterModel::sourceRow(int row) const {
    return row >= 0 && row < rowCount() ? mapToSource(index(row, 0)).row() : -1;
}
int HistoryFilterModel::groupCount(QString const& app) const {
    if (m_groupsDirty) {
        m_groups.clear();
        auto const appRole = role("appName");
        for (int row = 0; row < rowCount(); ++row)
            ++m_groups[data(index(row, 0), appRole).toString()];
        m_groupsDirty = false;
    }
    return m_groups.value(app);
}
