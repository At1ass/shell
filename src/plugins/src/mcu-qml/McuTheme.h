#pragma once
#include <QObject>
#include <QColor>
#include <QUrl>
#include <QVariant>
#include <QVariantMap>
#include <QQmlEngine>
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

public:
    explicit McuTheme(QObject* parent = nullptr);

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

signals:
    void sourceChanged();
    void darkModeChanged();
    void variantChanged();
    void contrastChanged();
    void colorsChanged();
    void validChanged();
    void loadingChanged();

private:
    enum class SourceKind { None, Color, Image };

    // Внутренние утилиты
    static uint32_t qcolorToArgb(const QColor& c);
    static QString  argbToHex(uint32_t argb);

    // Основные шаги пайплайна
    void applySeed();                              // Пересчитать схему из m_seedArgb (без повторного чтения)
    bool makeSeedFromImageUrl(const QUrl& url);    // Посчитать m_seedArgb из URL
    bool makeSeedFromImagePath(const QString& path);
    void generateColorScheme(uint32_t seedArgb);   // Заполняет m_colors и дёргает signals

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

    // Результат
    QVariantMap m_colors;
};
