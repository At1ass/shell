#pragma once
#include <QObject>
#include <QColor>
#include <QUrl>
#include <QVariant>
#include <QVariantMap>
#include <QQmlEngine>
#include <QFuture>
#include <QList>
#include <QPointer>
#include <memory>

class McuTheme : public QObject {
    Q_OBJECT
    QML_ELEMENT

    // The only input: QColor (seed) or QUrl (image). QString is rejected —
    // it is the main source of ambiguity between the two.
    Q_PROPERTY(QVariant source   READ source   WRITE setSource   NOTIFY sourceChanged)

    // Scheme parameters
    Q_PROPERTY(bool     darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString  variant  READ variant  WRITE setVariant  NOTIFY variantChanged)
    Q_PROPERTY(double   contrast READ contrast WRITE setContrast NOTIFY contrastChanged)

    // Resulting color scheme (role name -> "#RRGGBB")
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)

    // State
    Q_PROPERTY(bool valid   READ valid   NOTIFY validChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

    // Source image luminance (Rec. 709, 0.0-1.0)
    Q_PROPERTY(qreal luminance READ luminance NOTIFY luminanceChanged)

public:
    explicit McuTheme(QObject* parent = nullptr);
    ~McuTheme() override;

    QVariant source() const { return m_source; }
    Q_INVOKABLE void setSource(const QVariant& v);

    bool darkMode() const { return m_darkMode; }
    Q_INVOKABLE void setDarkMode(bool dark);

    QString variant() const { return m_variant; }
    Q_INVOKABLE void setVariant(const QString& variant);

    double contrast() const { return m_contrast; }
    Q_INVOKABLE void setContrast(double contrast);

    QVariantMap colors() const { return m_colors; }

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

    static uint32_t qcolorToArgb(const QColor& c);
    static QString  argbToHex(uint32_t argb);
    static bool     extractSeedFromImage(const QUrl& url, uint32_t& outSeed, qreal& outLuminance);

    // Recompute the scheme from m_seedArgb (no image re-read).
    void applySeed();
    static QVariantMap buildScheme(uint32_t seedArgb, bool dark, const QString& variant, double contrast);

    // valid is bound in QML — every transition must notify.
    void setValidInternal(bool v);

    // Remember every started future so the destructor can wait for ALL of
    // them, not just the most recent (superseded tasks otherwise outlive
    // the object into application teardown).
    void trackFuture(const QFuture<void>& f);

private:
    QVariant m_source;                // last valid input (QColor or QUrl)
    bool     m_darkMode = false;
    QString  m_variant  = QStringLiteral("tonalSpot");
    double   m_contrast = 0.0;

    bool       m_valid    = false;
    bool       m_loading  = false;
    SourceKind m_kind     = SourceKind::None;
    uint32_t   m_seedArgb = 0;        // cached seed (from color or image)
    qreal      m_luminance = 0.5;

    QVariantMap m_colors;

    // Async generation bookkeeping
    quint64 m_generation = 0;         // scheme-generation request version
    quint64 m_seedRequest = 0;        // image-seed-extraction request version
    QList<QFuture<void>> m_inflight;  // every not-yet-finished task
};
