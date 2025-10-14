#include "FileSearcher.h"
#include <QProcess>
#include <QFileInfo>
#include <QDir>
#include <QDebug>
#include <algorithm>
#include <rapidfuzz/fuzz.hpp>

// Инициализация статических переменных
QStringList FileSearcher::s_fileList;
QString FileSearcher::s_cachedPath;
QMutex FileSearcher::s_cacheMutex;
bool FileSearcher::s_cacheInitialized = false;

FileSearcher::FileSearcher(QObject* parent)
    : QObject(parent)
    , m_threadPool(new QThreadPool(this))
{
    // Ограничиваем количество потоков
    m_threadPool->setMaxThreadCount(2);
    qDebug() << "FileSearcher: Initialized with rapidfuzz";
}

FileSearcher::~FileSearcher() {
    cancel();
    m_threadPool->waitForDone();
}

void FileSearcher::initCache(const QString& searchPath) {
    QMutexLocker lock(&s_cacheMutex);

    // Если уже инициализирован для этого пути
    if (s_cacheInitialized && s_cachedPath == searchPath) {
        qDebug() << "FileSearcher: Cache already initialized for" << searchPath;
        lock.unlock();
        emit cacheReadyChanged();
        return;
    }

    // Если запрашивается другой путь - сбрасываем
    if (s_cacheInitialized && s_cachedPath != searchPath) {
        qDebug() << "FileSearcher: Resetting cache for new path" << searchPath;
        s_fileList.clear();
        s_cacheInitialized = false;
    }

    qDebug() << "FileSearcher: Initializing cache for" << searchPath;
    s_cachedPath = searchPath;

    // Создаем worker для инициализации
    auto* worker = new FileCacheWorker(this, searchPath);

    connect(worker, &FileCacheWorker::finished, this, [this]() {
        qDebug() << "FileSearcher: Cache ready with" << s_fileList.size() << "files";
    }, Qt::QueuedConnection);

    // Запускаем в thread pool
    m_threadPool->start(worker);
}

void FileSearcher::search(const QString& query, int maxResults) {
    if (query.isEmpty() || query.length() < 2) {
        emit resultsReady(QVariantList());
        return;
    }

    // Проверяем что кеш готов
    {
        QMutexLocker lock(&s_cacheMutex);
        if (!s_cacheInitialized || s_fileList.isEmpty()) {
            qDebug() << "FileSearcher: Cache not ready yet";
            emit resultsReady(QVariantList());
            return;
        }
    }

    // Отменяем предыдущий поиск
    cancel();

    setSearching(true);
    emit searchStarted();

    // Создаем worker для fuzzy search
    auto* worker = new FileSearchWorker(this, query, maxResults);

    connect(worker, &FileSearchWorker::resultsReady,
            this, &FileSearcher::resultsReady, Qt::QueuedConnection);

    connect(worker, &FileSearchWorker::finished, this, [this]() {
        setSearching(false);
    }, Qt::QueuedConnection);

    // Запускаем в thread pool
    QMutexLocker locker(&m_mutex);
    m_currentWorker = worker;
    m_threadPool->start(worker);
}

void FileSearcher::cancel() {
    QMutexLocker locker(&m_mutex);
    if (m_currentWorker) {
        m_currentWorker->cancel();
        m_currentWorker = nullptr;
    }
}

bool FileSearcher::cacheReady() const {
    QMutexLocker lock(&s_cacheMutex);
    return s_cacheInitialized;
}

void FileSearcher::setSearching(bool searching) {
    if (m_searching != searching) {
        m_searching = searching;
        emit searchingChanged();
    }
}

// ============================================================================
// FileCacheWorker - инициализация списка файлов через fd
// ============================================================================

FileCacheWorker::FileCacheWorker(FileSearcher* searcher, const QString& searchPath)
    : m_searcher(searcher)
    , m_searchPath(searchPath)
{
    setAutoDelete(true);
}

void FileCacheWorker::run() {
    qDebug() << "FileCacheWorker: Building file list for" << m_searchPath;

    // Запускаем fd для получения всех файлов и директорий
    QProcess process;
    QStringList args;

    args << "--type" << "f"
         << "--type" << "d"
         << "--follow"
         << "--hidden"
         << "--max-depth" << "5"  // Ограничиваем глубину
         << "."  // Все файлы
         << m_searchPath;

    process.start("fd", args);

    if (!process.waitForStarted(2000)) {
        qWarning() << "FileCacheWorker: Failed to start fd";
        emit finished();
        return;
    }

    // Даем время для сканирования всего HOME (30 секунд)
    if (!process.waitForFinished(30000)) {
        qWarning() << "FileCacheWorker: fd timeout";
        process.kill();
        emit finished();
        return;
    }

    if (process.exitCode() != 0) {
        qWarning() << "FileCacheWorker: fd failed:" << process.readAllStandardError();
        emit finished();
        return;
    }

    // Парсим результаты
    QString output = QString::fromUtf8(process.readAllStandardOutput());
    QStringList files = output.split('\n', Qt::SkipEmptyParts);

    qDebug() << "FileCacheWorker: Found" << files.size() << "files";

    // Сохраняем в статический список
    QMutexLocker lock(&FileSearcher::s_cacheMutex);
    FileSearcher::s_fileList = files;
    FileSearcher::s_cacheInitialized = true;
    lock.unlock();

    // Уведомляем что кеш готов (emit в главном потоке)
    QMetaObject::invokeMethod(m_searcher, [searcher = m_searcher]() {
        emit searcher->cacheReadyChanged();
    }, Qt::QueuedConnection);

    emit finished();
}

// ============================================================================
// FileSearchWorker - fuzzy поиск по готовому списку
// ============================================================================

FileSearchWorker::FileSearchWorker(FileSearcher* searcher,
                                   const QString& query,
                                   int maxResults)
    : m_searcher(searcher)
    , m_query(query.toLower())
    , m_maxResults(maxResults)
{
    setAutoDelete(true);
}

static bool isSubsequence(const QString& query, const QString& target) {
    int qLen = query.length();
    int tLen = target.length();
    if (qLen == 0) return true;
    if (qLen > tLen) return false;

    int qIndex = 0;
    for(QChar ch : target) {
        if (query[qIndex] == ch) {
            qIndex++;
            if (qIndex == qLen) return true;
        }
    }
    return false;
}

void FileSearchWorker::run() {
    // Структура для хранения результата с score
    struct ScoredResult {
        QString path;
        double score;
        bool isDir;
    };

    QVector<ScoredResult> scoredResults;

    // Получаем копию списка файлов
    QStringList fileList;
    {
        QMutexLocker lock(&FileSearcher::s_cacheMutex);
        fileList = FileSearcher::s_fileList;
    }

    qDebug() << "FileSearchWorker: Fuzzy searching" << m_query << "in" << fileList.size() << "files";

    std::string queryStr = m_query.toStdString();
    // Fuzzy match с rapidfuzz для каждого файла
    for (const QString& filePath : fileList) {
        // Проверяем отмену
        {
            QMutexLocker locker(&m_cancelMutex);
            if (m_cancelled) {
                qDebug() << "FileSearchWorker: Search cancelled";
                emit finished();
                return;
            }
        }

        // QString fileName = QFileInfo(filePath).fileName().toLower();
        QString fileName = QFileInfo(filePath).filePath().toLower();

        // Быстрый фильтр по subsequence
        if (!isSubsequence(m_query, fileName)) {
            continue;
        }

        // Используем rapidfuzz для вычисления similarity score
        double score = std::max (
            rapidfuzz::fuzz::partial_ratio(queryStr, fileName.toStdString()),
            rapidfuzz::fuzz::token_set_ratio(queryStr, fileName.toStdString())
        );

        // Фильтруем по минимальному threshold (40% similarity)
        if (score >= 40.0) {
            bool isDir = isDirectory(filePath);
            scoredResults.append({filePath, score, isDir});
        }
    }

    qDebug() << "FileSearchWorker: Found" << scoredResults.size() << "matches";

    // Сортируем по score (descending)
    std::sort(scoredResults.begin(), scoredResults.end(),
              [](const ScoredResult& a, const ScoredResult& b) {
                  return a.score > b.score;
              });

    // Берем топ результаты и конвертируем в QVariantList
    QVariantList results;
    int count = std::min(scoredResults.size(), (qsizetype)m_maxResults);
    for (int i = 0; i < count; ++i) {
        const auto& result = scoredResults[i];

        QVariantMap item;
        item["path"] = result.path;
        item["name"] = QFileInfo(result.path).fileName();
        item["isDirectory"] = result.isDir;
        item["icon"] = getFileIcon(result.path, result.isDir);
        item["score"] = (int)result.score;

        results.append(item);
    }

    emit resultsReady(results);
    emit finished();
}

void FileSearchWorker::cancel() {
    QMutexLocker locker(&m_cancelMutex);
    m_cancelled = true;
}

bool FileSearchWorker::isDirectory(const QString& path) const {
    return QFileInfo(path).isDir();
}

QString FileSearchWorker::getFileIcon(const QString& filePath, bool isDirectory) const {
    if (isDirectory) {
        // Специальные иконки для известных директорий
        if (filePath.endsWith("/Documents")) return "folder-documents";
        if (filePath.endsWith("/Downloads")) return "folder-downloads";
        if (filePath.endsWith("/Pictures")) return "folder-pictures";
        if (filePath.endsWith("/Music")) return "folder-music";
        if (filePath.endsWith("/Videos")) return "folder-videos";
        return "folder";
    }

    // Определяем иконку по расширению
    QString ext = QFileInfo(filePath).suffix().toLower();

    static const QMap<QString, QString> iconMap = {
        {"txt", "text-plain"},
        {"md", "text-markdown"},
        {"pdf", "application-pdf"},
        {"doc", "x-office-document"},
        {"docx", "x-office-document"},
        {"odt", "x-office-document"},
        {"xls", "x-office-spreadsheet"},
        {"xlsx", "x-office-spreadsheet"},
        {"ods", "x-office-spreadsheet"},
        {"ppt", "x-office-presentation"},
        {"pptx", "x-office-presentation"},
        {"odp", "x-office-presentation"},
        {"jpg", "image-jpeg"},
        {"jpeg", "image-jpeg"},
        {"png", "image-png"},
        {"gif", "image-gif"},
        {"svg", "image-svg+xml"},
        {"bmp", "image-bmp"},
        {"webp", "image-webp"},
        {"mp3", "audio-mpeg"},
        {"wav", "audio-wav"},
        {"flac", "audio-flac"},
        {"ogg", "audio-ogg"},
        {"mp4", "video-mp4"},
        {"avi", "video-x-msvideo"},
        {"mkv", "video-x-matroska"},
        {"webm", "video-webm"},
        {"zip", "application-zip"},
        {"tar", "application-x-tar"},
        {"gz", "application-gzip"},
        {"7z", "application-x-7z-compressed"},
        {"rar", "application-x-rar"},
        {"py", "text-x-python"},
        {"js", "application-javascript"},
        {"ts", "application-typescript"},
        {"cpp", "text-x-c++src"},
        {"c", "text-x-csrc"},
        {"h", "text-x-chdr"},
        {"hpp", "text-x-c++hdr"},
        {"rs", "text-rust"},
        {"go", "text-x-go"},
        {"java", "text-x-java"},
        {"qml", "text-x-qml"},
        {"html", "text-html"},
        {"css", "text-css"},
        {"json", "application-json"},
        {"xml", "text-xml"},
        {"yaml", "text-yaml"},
        {"yml", "text-yaml"},
        {"sh", "application-x-shellscript"},
        {"bash", "application-x-shellscript"}
    };

    return iconMap.value(ext, "text-plain");
}
