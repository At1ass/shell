#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QQmlEngine>
#include <QThreadPool>
#include <QMutex>
#include <QRunnable>

// Forward declarations
class FileSearchWorker;
class FileCacheWorker;

class FileSearcher : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool searching READ searching NOTIFY searchingChanged)
    Q_PROPERTY(bool cacheReady READ cacheReady NOTIFY cacheReadyChanged)

public:
    explicit FileSearcher(QObject* parent = nullptr);
    ~FileSearcher();

    // Инициализировать список файлов через fd (вызывается при первом "?")
    Q_INVOKABLE void initCache(const QString& searchPath);

    // Fuzzy поиск по закешированному списку
    Q_INVOKABLE void search(const QString& query, int maxResults = 10);

    // Отменить текущий поиск
    Q_INVOKABLE void cancel();

    bool searching() const { return m_searching; }
    bool cacheReady() const;

signals:
    // Результаты поиска готовы
    void resultsReady(const QVariantList& results);

    // Начало поиска
    void searchStarted();

    // Изменение статуса поиска
    void searchingChanged();

    // Кеш готов (fd завершил сканирование)
    void cacheReadyChanged();

private:
    friend class FileSearchWorker;
    friend class FileCacheWorker;

    void setSearching(bool searching);

    // Статический список файлов (живет пока работает quickshell)
    static QStringList s_fileList;
    static QString s_cachedPath;
    static QMutex s_cacheMutex;
    static bool s_cacheInitialized;

    bool m_searching = false;
    QThreadPool* m_threadPool;
    QMutex m_mutex;
    FileSearchWorker* m_currentWorker = nullptr;
};

// Worker для инициализации списка файлов через fd (один раз)
class FileCacheWorker : public QObject, public QRunnable {
    Q_OBJECT

public:
    FileCacheWorker(FileSearcher* searcher, const QString& searchPath);

    void run() override;

signals:
    void finished();

private:
    FileSearcher* m_searcher;
    QString m_searchPath;
};

// Worker для fuzzy поиска по готовому списку (rapidfuzz)
class FileSearchWorker : public QObject, public QRunnable {
    Q_OBJECT

public:
    FileSearchWorker(FileSearcher* searcher,
                     const QString& query,
                     int maxResults);

    void run() override;
    void cancel();

signals:
    void resultsReady(const QVariantList& results);
    void finished();

private:
    // Определяет является ли путь директорией
    bool isDirectory(const QString& path) const;

    // Получить иконку для файла
    QString getFileIcon(const QString& filePath, bool isDirectory) const;

    FileSearcher* m_searcher;
    QString m_query;
    int m_maxResults;
    bool m_cancelled = false;
    QMutex m_cancelMutex;
};
