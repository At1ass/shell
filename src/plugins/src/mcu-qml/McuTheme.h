#pragma once
#include <QObject>
#include <QColor>
#include <QUrl>
#include <QVariant>
#include <QVariantMap>
#include <QQmlEngine>
#include <QFuture>
#include <QPointer>
#include <memory>

class McuTheme : public QObject {
    Q_OBJECT
    QML_ELEMENT

    // Единственный вход: ТОЛЬКО QColor (семя) или QUrl (картинка). QString не поддерживаем.
    Q_PROPERTY(QVariant source   READ source   WRITE setSource   NOTIFY sourceChanged)

    // Параметры схемы
    Q_PROPERTY(bool     darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString  variant  READ variant  WRITE setVariant  NOTIFY variantChanged)
    Q_PROPERTY(double   contrast READ contrast WRITE setContrast NOTIFY contrastChanged)

    // Итоговая цветовая схема (как JSON-словарь для удобного биндинга в QML)
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)

    // Состояние
    Q_PROPERTY(bool valid   READ valid   NOTIFY validChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

    // Яркость изображения-источника (Rec. 709, диапазон 0.0–1.0)
    Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)

public:
    explicit McuTheme(QObject* parent = nullptr);
    ~McuTheme() override;

    // Source
    QVariant source() const { return m_source; }
    Q_INVOKABLE void setSource(const QVariant& v);

    // Параметры
    bool darkMode() const { return m_darkMode; }
    Q_INVOKABLE void setDarkMode(bool dark);

    QString variant() const { return m_variant; }
    Q_INVOKABLE void setVariant(const QString& variant);

    double contrast() const { return m_contrast; }
    Q_INVOKABLE void setContrast(double contrast);

    // Цвета
    QVariantMap colors() const { return m_colors; }

    // Состояние
    bool valid()   const { return m_valid; }
    bool loading() const { return m_loading; }
    qreal luminance() const { return m_luminance; }

signals:
    void sourceChanged();
    void darkModeChanged();
    void variantChanged();
    void contrastChanged();
    void colorsChanged();
    void validChanged();
    void loadingChanged();
    void luminanceChanged();

private:
    enum class SourceKind { None, Color, Image };

    // Внутренние утилиты
    static uint32_t qcolorToArgb(const QColor& c);
    static QString  argbToHex(uint32_t argb);
    static bool     extractSeedFromImage(const QUrl& url, uint32_t& outSeed, qreal& outLuminance);

    // Основные шаги пайплайна
    void applySeed();                              // Пересчитать схему из m_seedArgb (без повторного чтения)
    static QVariantMap buildScheme(uint32_t seedArgb, bool dark, const QString& variant, double contrast);

private:
    // Входные параметры
    QVariant m_source;                // хранит последний валидный вход (QColor или QUrl)
    bool     m_darkMode = false;
    QString  m_variant  = QStringLiteral("tonalSpot"); // единый стиль имени (без дефиса)
    double   m_contrast = 0.0;

    // Состояние
    bool       m_valid    = false;
    bool       m_loading  = false;
    SourceKind m_kind     = SourceKind::None;
    uint32_t   m_seedArgb = 0;        // кэш «семени» (из цвета или картинки)
    qreal      m_luminance = 0.5;    // яркость источника (Rec. 709)

    // Результат
    QVariantMap m_colors;

    // Асинхронная генерация
    quint64 m_generation = 0;         // версия запроса для генерации схемы
    quint64 m_seedRequest = 0;        // версия запроса извлечения семени из картинки
    QFuture<void> m_future;           // генерация цветовой схемы
    QFuture<void> m_seedFuture;       // извлечение семени из картинки
};
