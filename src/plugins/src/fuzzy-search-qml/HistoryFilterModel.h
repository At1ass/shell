#pragma once
#include <QQmlEngine>
#include <QSortFilterProxyModel>
#include <QVariantMap>

// A read-only proxy: visible row indices never become history identities.
class HistoryFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(double since READ since WRITE setSince NOTIFY sinceChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
   public:
    explicit HistoryFilterModel(QObject* parent = nullptr);
    void setSourceModel(QAbstractItemModel* source) override;
    QString query() const { return m_query; }
    void setQuery(QString const& value);
    double since() const { return m_since; }
    void setSince(double value);
    int count() const { return rowCount(); }
    int revision() const { return m_revision; }
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int sourceRow(int row) const;
    Q_INVOKABLE int groupCount(QString const& app) const;
   signals:
    void queryChanged();
    void sinceChanged();
    void countChanged();
    void revisionChanged();

   protected:
    bool filterAcceptsRow(int row, QModelIndex const& parent) const override;

   private:
    void changed();
    int role(QByteArray const& name) const;
    QString m_query;
    QStringList m_terms;
    double m_since = 0;
    int m_revision = 0;
    mutable bool m_groupsDirty = true;
    mutable QHash<QString, int> m_groups;
};
