#include <QAbstractListModel>
#include <QtTest>

#include "HistoryFilterModel.h"

class Rows : public QAbstractListModel {
   public:
    QList<QVariantMap> rows;
    QHash<int, QByteArray> roleNames() const override {
        return {{256, "notificationId"},
                {257, "appName"},
                {258, "summary"},
                {259, "body"},
                {260, "timestamp"}};
    }
    int rowCount(QModelIndex const& parent = {}) const override {
        return parent.isValid() ? 0 : rows.size();
    }
    QVariant data(QModelIndex const& index, int role) const override {
        return index.isValid() && index.row() < rows.size()
                   ? rows[index.row()].value(
                         QString::fromUtf8(roleNames().value(role)))
                   : QVariant();
    }
    void reset(QList<QVariantMap> values) {
        beginResetModel();
        rows = std::move(values);
        endResetModel();
    }
    void replaceBody(int row, QString const& value) {
        rows[row]["body"] = value;
        emit dataChanged(index(row), index(row), {259});
    }
};
class HistoryFilterTests : public QObject {
    Q_OBJECT
   private slots:
    void identityAndUpdates() {
        Rows source;
        source.reset({{{"notificationId", "first"},
                       {"appName", "Mail"},
                       {"summary", "Meeting"},
                       {"body", "Tomorrow"},
                       {"timestamp", 10.0}},
                      {{"notificationId", "second"},
                       {"appName", "Chat"},
                       {"summary", "News"},
                       {"body", "A <b>meeting</b> today"},
                       {"timestamp", 20.0}}});
        HistoryFilterModel proxy;
        proxy.setSourceModel(&source);
        proxy.setQuery("MEETING");
        QCOMPARE(proxy.count(), 2);
        proxy.setSince(15);
        QCOMPARE(proxy.count(), 1);
        QCOMPARE(proxy.sourceRow(0), 1);
        QCOMPARE(proxy.get(0).value("notificationId").toString(),
                 QString("second"));
        QCOMPARE(proxy.groupCount("Chat"), 1);
        QCOMPARE(proxy.groupCount("Mail"), 0);
        source.replaceBody(1, "No match");
        QCOMPARE(proxy.count(), 0);
        proxy.setQuery("mail meeting");
        proxy.setSince(0);
        QCOMPARE(proxy.count(), 1);
        QCOMPARE(source.rowCount(), 2);
        QCOMPARE(proxy.sourceRow(-1), -1);
        QVERIFY(proxy.get(3).isEmpty());
        proxy.setSourceModel(nullptr);
        QCOMPARE(proxy.count(), 0);
    }
    void unicodeAndReset() {
        Rows source;
        HistoryFilterModel proxy;
        proxy.setSourceModel(&source);
        proxy.setQuery(QString::fromUtf8("встреча"));
        source.reset({{{"notificationId", "ru"},
                       {"appName", "Mail"},
                       {"summary", QString::fromUtf8("ВСТРЕЧА")},
                       {"timestamp", 30.0}}});
        QCOMPARE(proxy.count(), 1);
        QCOMPARE(proxy.groupCount("Mail"), 1);
        source.reset({});
        QCOMPARE(proxy.count(), 0);
        QCOMPARE(proxy.groupCount("Mail"), 0);
    }
    void malformedMarkupStaysSearchable() {
        Rows source;
        source.reset({{{"notificationId", "literal"},
                       {"appName", "Math"},
                       {"body", QString(10000, QLatin1Char('<')) + "marker"}}});
        HistoryFilterModel proxy;
        proxy.setSourceModel(&source);
        proxy.setQuery("marker");
        QCOMPARE(proxy.count(), 1);
    }
};
QTEST_GUILESS_MAIN(HistoryFilterTests)
#include "HistoryFilterTests.moc"
