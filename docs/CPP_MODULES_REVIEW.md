# Обзор существующих C++ модулей

**Дата:** 2025-12-09

---

## Существующие модули

### 1. mcu-qml (Material Color Utilities)

**Назначение:** Генерация Material Design 3 цветовых схем из цвета или изображения

**Качество:** ⭐⭐⭐⭐⭐ (9/10)

#### ✅ Сильные стороны

1. **Отличная архитектура**
   ```cpp
   // Чистый интерфейс
   Q_PROPERTY(QVariant source READ source WRITE setSource NOTIFY sourceChanged)
   Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)
   ```

2. **Асинхронная обработка изображений**
   ```cpp
   static QImage readDownscaled(const QString& path, int maxSide = 160)
   // Даунскейл на этапе декодирования - эффективно!
   ```

3. **Правильное использование материалов**
   - Material Color Utilities (Google's library)
   - Все MD3 роли (primary, secondary, tertiary, etc.)
   - 68 цветовых ролей

4. **Безопасность**
   ```cpp
   #if QT_VERSION >= QT_VERSION_CHECK(6,0,0)
       r.setAllocationLimit(128); // МБ — защита от гигантов
   #endif
   ```

5. **Производительность**
   - Кэширование seed (не пересчитывает при изменении darkMode/contrast)
   - Efficient color quantization (Celebi algorithm)
   - Даунскейл изображений до 160px

6. **Чистый код**
   - Хорошие комментарии
   - Понятные имена переменных
   - Разделение ответственности

#### ⚠️ Потенциальные улучшения

1. **Отсутствие отмены загрузки изображения**
   ```cpp
   // Если пользователь быстро меняет source, старая загрузка не отменяется
   // Можно добавить QFuture для отмены
   ```

2. **Нет прогресса загрузки**
   ```cpp
   // Можно добавить:
   Q_PROPERTY(qreal loadProgress READ loadProgress NOTIFY loadProgressChanged)
   ```

3. **Синхронная загрузка изображений**
   ```cpp
   // Сейчас: readDownscaled блокирует поток
   // Лучше: использовать QThreadPool для background loading
   ```

#### 🎯 Рекомендация
**Оставить как есть.** Модуль работает отлично. Можно добавить async image loading в будущем.

**Приоритет улучшений:** 🟢 Низкий (работает хорошо)

---

### 2. qalculate-qml

**Назначение:** Wrapper для libqalculate (калькулятор)

**Качество:** ⭐⭐⭐⭐ (7/10)

#### ✅ Сильные стороны

1. **Простота**
   ```cpp
   Q_INVOKABLE QString eval(const QString& expression, bool printExpr = false) const;
   ```

2. **Обработка ошибок**
   ```cpp
   while (CALCULATOR->message()) {
       if (CALCULATOR->message()->type() == MESSAGE_ERROR) {
           error += "error: ";
       }
   }
   ```

3. **Singleton pattern**
   ```cpp
   QML_SINGLETON
   ```

#### ⚠️ Проблемы

1. **Утечка памяти при инициализации**
   ```cpp
   if (!CALCULATOR) {
       new Calculator();  // ← УТЕЧКА! Нет delete
   }
   ```

   **Исправление:**
   ```cpp
   static std::unique_ptr<Calculator> s_calculator;
   if (!s_calculator) {
       s_calculator = std::make_unique<Calculator>();
       s_calculator->loadExchangeRates();
       // ...
   }
   ```

2. **Нет thread safety**
   ```cpp
   // Если eval() вызывается из разных потоков - race condition
   // Нужен QMutex
   ```

3. **Нет timeout защиты**
   ```cpp
   std::string result = CALCULATOR->calculateAndPrint(
       ...,
       100,  // max time in ms - ХОРОШО
       ...
   );
   // НО: если libqalculate зависнет, QML тоже зависнет
   ```

4. **Блокирующий вызов**
   ```cpp
   // eval() блокирует UI thread
   // Для сложных вычислений нужна асинхронность
   ```

#### 🎯 Рекомендация
**Улучшить.** Добавить async вычисления и исправить утечку памяти.

**Приоритет улучшений:** 🟡 Средний

#### Улучшенная версия

```cpp
// QalculateWrapper.h
class QalculateWrapper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool calculating READ calculating NOTIFY calculatingChanged)

public:
    explicit QalculateWrapper(QObject* parent = nullptr);
    ~QalculateWrapper();

    // Синхронный (для быстрых вычислений)
    Q_INVOKABLE QString eval(const QString& expression, bool printExpr = false);

    // Асинхронный (для сложных вычислений)
    Q_INVOKABLE void evalAsync(const QString& expression, bool printExpr = false);

    bool calculating() const { return m_calculating; }

signals:
    void calculatingChanged();
    void resultReady(const QString& result);
    void errorOccurred(const QString& error);

private:
    // Singleton calculator instance
    static std::unique_ptr<Calculator> s_calculator;
    static QMutex s_mutex;
    static bool s_initialized;

    bool m_calculating = false;
    QThreadPool* m_threadPool;

    QString evalInternal(const QString& expression, bool printExpr);
    void initCalculator();
};

// QalculateWrapper.cpp
std::unique_ptr<Calculator> QalculateWrapper::s_calculator;
QMutex QalculateWrapper::s_mutex;
bool QalculateWrapper::s_initialized = false;

QalculateWrapper::QalculateWrapper(QObject* parent)
    : QObject(parent)
    , m_threadPool(new QThreadPool(this))
{
    m_threadPool->setMaxThreadCount(1);
    initCalculator();
}

QalculateWrapper::~QalculateWrapper() {
    m_threadPool->waitForDone();
}

void QalculateWrapper::initCalculator() {
    QMutexLocker lock(&s_mutex);
    if (!s_initialized) {
        s_calculator = std::make_unique<Calculator>();
        s_calculator->loadExchangeRates();
        s_calculator->loadGlobalDefinitions();
        s_calculator->loadLocalDefinitions();
        s_initialized = true;
        qDebug() << "QalculateWrapper: Initialized";
    }
}

QString QalculateWrapper::eval(const QString& expression, bool printExpr) {
    QMutexLocker lock(&s_mutex);  // Thread safety
    return evalInternal(expression, printExpr);
}

void QalculateWrapper::evalAsync(const QString& expression, bool printExpr) {
    m_calculating = true;
    emit calculatingChanged();

    // Run in thread pool
    QRunnable* task = QRunnable::create([this, expression, printExpr]() {
        QMutexLocker lock(&s_mutex);
        QString result = evalInternal(expression, printExpr);

        // Emit result on main thread
        QMetaObject::invokeMethod(this, [this, result]() {
            emit resultReady(result);
            m_calculating = false;
            emit calculatingChanged();
        }, Qt::QueuedConnection);
    });

    m_threadPool->start(task);
}

QString QalculateWrapper::evalInternal(const QString& expression, bool printExpr) {
    // Existing implementation...
}
```

---

### 3. file-search-qml

**Назначение:** Fuzzy поиск файлов через fd + rapidfuzz

**Качество:** ⭐⭐⭐⭐ (8/10)

#### ✅ Сильные стороны

1. **Асинхронность**
   ```cpp
   QThreadPool* m_threadPool;
   m_threadPool->setMaxThreadCount(2);
   ```

2. **Fuzzy matching**
   ```cpp
   #include <rapidfuzz/fuzz.hpp>
   // Качественный fuzzy search
   ```

3. **Отмена поиска**
   ```cpp
   void cancel();
   bool m_cancelled = false;
   ```

4. **Thread safety**
   ```cpp
   static QMutex s_cacheMutex;
   QMutexLocker lock(&s_cacheMutex);
   ```

5. **Кэширование результатов fd**
   ```cpp
   static QStringList s_fileList;  // Один раз сканируем
   ```

#### ⚠️ Проблемы

1. **Зависимость от внешней команды `fd`**
   ```cpp
   process.start("fd", args);
   // Если fd не установлен - не работает
   // Fallback на find нет
   ```

2. **Статический кэш**
   ```cpp
   static QStringList s_fileList;
   // Если файлы изменяются - кэш устаревает
   // Нет механизма обновления
   ```

3. **Блокирующий waitForFinished**
   ```cpp
   if (!process.waitForFinished(30000)) {  // 30 секунд!
       qWarning() << "fd timeout";
   }
   ```

4. **Нет обработки больших директорий**
   ```cpp
   // Если в HOME миллион файлов - fd будет работать минуты
   // Нужен прогресс или ограничение
   ```

5. **Жесткое ограничение глубины**
   ```cpp
   args << "--max-depth" << "5";  // Может пропустить нужные файлы
   ```

#### 🎯 Рекомендация
**Улучшить.** Добавить fallback, file watching, прогресс сканирования.

**Приоритет улучшений:** 🟡 Средний

#### Улучшенная версия

```cpp
// FileSearcher.h
class FileSearcher : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool cacheReady READ cacheReady NOTIFY cacheReadyChanged)
    Q_PROPERTY(qreal cacheProgress READ cacheProgress NOTIFY cacheProgressChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY totalFilesChanged)

public:
    // ...existing methods...

    Q_INVOKABLE void refreshCache();  // Пересканировать
    Q_INVOKABLE void setCacheDepth(int depth);

    qreal cacheProgress() const { return m_cacheProgress; }
    int totalFiles() const;

signals:
    void cacheProgressChanged();
    void totalFilesChanged();

private:
    qreal m_cacheProgress = 0.0;
    QFileSystemWatcher* m_watcher = nullptr;  // Watch for changes
    int m_maxDepth = 5;

    // Fallback если fd не найден
    void scanWithFind(const QString& path);
    void scanNative(const QString& path);  // QDirIterator
};

// FileSearcher.cpp
void FileCacheWorker::run() {
    // Попробовать fd
    QProcess process;
    process.start("fd", args);

    if (!process.waitForStarted(2000)) {
        qWarning() << "fd not found, falling back to native scan";
        scanNative(m_searchPath);
        return;
    }

    // Incremental progress
    connect(&process, &QProcess::readyReadStandardOutput, [&]() {
        QString output = process.readAllStandardOutput();
        QStringList lines = output.split('\n', Qt::SkipEmptyParts);

        QMutexLocker lock(&FileSearcher::s_cacheMutex);
        FileSearcher::s_fileList.append(lines);

        // Report progress
        QMetaObject::invokeMethod(m_searcher, [this]() {
            emit m_searcher->cacheProgressChanged();
            emit m_searcher->totalFilesChanged();
        }, Qt::QueuedConnection);
    });

    process.waitForFinished(60000);  // Увеличено до 60 сек

    // ...
}

void FileSearcher::scanNative(const QString& path) {
    // Fallback using QDirIterator
    QDirIterator it(path,
                    QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);

    while (it.hasNext()) {
        QString file = it.next();
        s_fileList.append(file);

        // Report progress every 100 files
        if (s_fileList.size() % 100 == 0) {
            emit cacheProgressChanged();
        }
    }
}
```

---

## Общие замечания по всем модулям

### ✅ Что сделано хорошо

1. **Использование современных Qt практик**
   - `QML_ELEMENT`, `QML_SINGLETON`
   - Qt6 QML module system
   - Правильный CMakeLists.txt

2. **Разделение ответственности**
   - Каждый модуль решает одну задачу
   - Чистые интерфейсы

3. **Качественные зависимости**
   - material-color-utilities (Google)
   - libqalculate (mature library)
   - rapidfuzz (fast fuzzy matching)

### ⚠️ Общие проблемы

1. **Нет единого стиля error handling**
   - mcu-qml: qWarning()
   - qalculate-qml: возвращает строку с ошибкой
   - file-search-qml: qWarning()

   **Рекомендация:** Унифицировать через signals:
   ```cpp
   signals:
       void errorOccurred(const QString& error);
   ```

2. **Нет метрик производительности**
   ```cpp
   // Можно добавить:
   Q_PROPERTY(qint64 lastOperationTime READ lastOperationTime)
   ```

3. **Отсутствие unit tests**
   - Нет тестов ни для одного модуля
   - Нужно добавить Qt Test

4. **Нет документации использования**
   - Только комментарии в коде
   - Нужны примеры QML

---

## Рекомендации по приоритетам

### 🔴 КРИТИЧНО - Исправить сейчас

1. **qalculate-qml: Утечка памяти**
   ```cpp
   new Calculator();  // ← FIX THIS
   ```
   **Время:** 10 минут
   **Файл:** `src/plugins/src/qalculate-qml/QalculateWrapper.cpp:10`

### 🟡 ВАЖНО - Сделать в течение месяца

2. **qalculate-qml: Добавить async вычисления**
   - Для сложных выражений
   - **Время:** 2 часа

3. **file-search-qml: Добавить fallback на native scan**
   - Если fd не установлен
   - **Время:** 3 часа

4. **file-search-qml: File watching для обновления кэша**
   - QFileSystemWatcher
   - **Время:** 2 часа

### 🟢 ОПЦИОНАЛЬНО - По желанию

5. **mcu-qml: Async image loading**
   - QThreadPool для загрузки
   - **Время:** 4 часа

6. **Все модули: Добавить unit tests**
   - Qt Test framework
   - **Время:** 8 часов (все модули)

7. **Все модули: Документация + примеры QML**
   - Markdown docs
   - **Время:** 4 часа

---

## Что НЕ стоит переписывать

### ❌ mcu-qml
**Причина:** Работает отлично, хорошая архитектура

### ❌ file-search-qml (полностью)
**Причина:** Основа хорошая, нужны только улучшения

---

## Что стоит расширить

### ✅ qalculate-qml
**Добавить:**
- Async вычисления
- History вычислений
- Переменные (x = 5, y = x * 2)

```cpp
class QalculateWrapper : public QObject {
    // ...

    Q_INVOKABLE void defineVariable(const QString& name, const QString& value);
    Q_INVOKABLE QVariantList getHistory() const;
    Q_INVOKABLE void clearHistory();

private:
    QList<QPair<QString, QString>> m_history;  // expression → result
    QHash<QString, QString> m_variables;
};
```

### ✅ file-search-qml
**Добавить:**
- Фильтры (только изображения, только документы)
- Bookmarks (часто используемые файлы)
- Recent files

```cpp
class FileSearcher : public QObject {
    // ...

    Q_INVOKABLE void setFileTypeFilter(const QString& type);  // "images", "documents", etc.
    Q_INVOKABLE void addBookmark(const QString& path);
    Q_INVOKABLE QVariantList getBookmarks() const;
    Q_INVOKABLE QVariantList getRecentFiles(int count = 10) const;

private:
    QStringList m_bookmarks;
    QStringList m_recentFiles;
    QString m_currentFilter;
};
```

---

## Новые модули для добавления

На основе анализа проблем, рекомендую добавить:

### 1. SystemMonitor (Приоритет 1)
См. `CPP_MODULES_SPEC.md` для деталей

### 2. LauncherCache (Приоритет 2)
См. `CPP_MODULES_SPEC.md` для деталей

### 3. NotificationQueue (Приоритет 5)
См. `CPP_MODULES_SPEC.md` для деталей

---

## Структура будущих модулей

```
src/plugins/src/
├── mcu-qml/              ✅ Отлично
├── qalculate-qml/        ⚠️ Исправить утечку
├── file-search-qml/      ⚠️ Добавить fallback
├── system-monitor/       ← НОВЫЙ (приоритет 1)
├── launcher-cache/       ← НОВЫЙ (приоритет 2)
├── notification-queue/   ← НОВЫЙ (приоритет 5)
└── utils/                ← НОВЫЙ (ProcessManager, FileWatcher)
```

---

## Чек-лист действий

### Немедленно (10 минут)
- [ ] Исправить утечку памяти в qalculate-qml

### На этой неделе (5 часов)
- [ ] Добавить async в qalculate-qml
- [ ] Добавить fallback в file-search-qml
- [ ] Добавить file watching в file-search-qml

### В течение месяца (20 часов)
- [ ] Создать SystemMonitor модуль
- [ ] Создать LauncherCache модуль
- [ ] Добавить unit tests для всех модулей
- [ ] Написать документацию

---

## Итоговая оценка

| Модуль | Качество | Приоритет улучшений | Время на улучшения |
|--------|----------|---------------------|-------------------|
| **mcu-qml** | 9/10 ⭐⭐⭐⭐⭐ | 🟢 Низкий | 0-4ч (опц.) |
| **qalculate-qml** | 7/10 ⭐⭐⭐⭐ | 🟡 Средний | 2ч (async) |
| **file-search-qml** | 8/10 ⭐⭐⭐⭐ | 🟡 Средний | 5ч (fallback+watch) |

**Общий вывод:**
Модули в хорошем состоянии. Основные улучшения - добавить async и fallbacks. Критична только утечка памяти в qalculate-qml.

---

**Автор:** Claude Code Analysis
**Дата:** 2025-12-09
