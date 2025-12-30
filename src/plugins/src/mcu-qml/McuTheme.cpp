#include "McuTheme.h"

#include <QImage>
#include <QImageReader>
#include <QFileInfo>
#include <QUrl>
#include <QMetaObject>
#include <qlogging.h>
#include <QtConcurrent>
#include <vector>
#include <algorithm>

// MCU headers (как у тебя)
#include <cpp/scheme/scheme_tonal_spot.h>
#include <cpp/scheme/scheme_vibrant.h>
#include <cpp/scheme/scheme_expressive.h>
#include <cpp/scheme/scheme_content.h>
#include <cpp/dynamiccolor/material_dynamic_colors.h>
#include <cpp/dynamiccolor/dynamic_scheme.h>
#include <cpp/cam/hct.h>
#include <cpp/quantize/celebi.h>
#include <cpp/score/score.h>

using namespace material_color_utilities;

static QImage readDownscaled(const QString& path, int maxSide = 160) {
    QImageReader r(path);
    r.setAutoTransform(true);
#if QT_VERSION >= QT_VERSION_CHECK(6,0,0)
    r.setAllocationLimit(128); // МБ — защита от гигантов
#endif
    const QSize s = r.size();  // может быть (0,0) для некоторых форматов
    if (s.isValid()) {
        QSize t = s;
        t.scale(QSize(maxSide, maxSide), Qt::KeepAspectRatio);
        r.setScaledSize(t);    // даунскейл на этапе декодирования
    }
    QImage img = r.read();
    if (img.isNull()) {
        qWarning() << "QImageReader error:" << r.errorString();
        return img;
    }
    if (img.format() != QImage::Format_ARGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);
    return img;
}

McuTheme::McuTheme(QObject* parent) : QObject(parent) {
    // дефолт: цвет-«семя»
    setSource(QColor("#6750A4"));
}

uint32_t McuTheme::qcolorToArgb(const QColor& c) {
    QColor rgba = c.isValid() ? c : QColor(Qt::magenta);
    return (uint32_t(rgba.alpha()) << 24)
         | (uint32_t(rgba.red())   << 16)
         | (uint32_t(rgba.green()) << 8)
         |  uint32_t(rgba.blue());
}

QString McuTheme::argbToHex(uint32_t argb) {
    int r = (argb >> 16) & 0xFF;
    int g = (argb >> 8 ) & 0xFF;
    int b =  argb        & 0xFF;
    return QString("#%1%2%3")
            .arg(r,2,16,QLatin1Char('0'))
            .arg(g,2,16,QLatin1Char('0'))
            .arg(b,2,16,QLatin1Char('0'))
            .toUpper();
}

void McuTheme::setSource(const QVariant& v) {
    if (m_source == v) return;

    const int id = v.metaType().id();

    if (id == QMetaType::QColor) {
        // Цвет — быстрый путь
        const QColor c = v.value<QColor>();
        if (!c.isValid()) {
            qWarning() << "McuTheme: invalid QColor in source";
            return;
        }
        m_source   = v;
        m_kind     = SourceKind::Color;
        m_seedArgb = qcolorToArgb(c);
        m_valid    = false; // будет true после generateColorScheme
        emit sourceChanged();
        applySeed();
        return;
    }

    if (id == QMetaType::QUrl) {
        const QUrl u = v.toUrl();
        if (!u.isValid()) {
            qWarning() << "McuTheme: invalid QUrl in source";
            return;
        }
        m_source = v;
        m_kind   = SourceKind::Image;
        m_valid  = false;
        emit sourceChanged();

        const auto requestId = ++m_seedRequest;
        if (!m_loading) {
            m_loading = true;
            emit loadingChanged();
        }

        m_seedFuture = QtConcurrent::run([this, requestId, u]() {
            uint32_t seed = 0;
            const bool ok = extractSeedFromImage(u, seed);
            QMetaObject::invokeMethod(this, [this, requestId, ok, seed, u]() {
                if (requestId != m_seedRequest)
                    return;
                if (!ok) {
                    qWarning() << "McuTheme: failed to extract seed from image" << u;
                    if (m_loading) {
                        m_loading = false;
                        emit loadingChanged();
                    }
                    return;
                }
                m_seedArgb = seed;
                applySeed();
            }, Qt::QueuedConnection);
        });
        return;
    }

    // Никаких строк: это основная причина двусмысленности.
    qWarning() << "McuTheme: source must be QColor or QUrl; QString not supported."
               << "Got type:" << v.metaType().name();
}

void McuTheme::setDarkMode(bool dark) {
    if (m_darkMode == dark) return;
    m_darkMode = dark;
    emit darkModeChanged();
    applySeed(); // без повторного квантования
}

void McuTheme::setVariant(const QString& variant) {
    if (m_variant == variant) return;
    m_variant = variant;
    emit variantChanged();
    applySeed();
}

void McuTheme::setContrast(double contrast) {
    if (qAbs(m_contrast - contrast) < 0.001) return;
    m_contrast = contrast;
    emit contrastChanged();
    applySeed();
}

bool McuTheme::extractSeedFromImage(const QUrl& url, uint32_t& outSeed) {
    QString path;
    if (url.isLocalFile() || url.scheme() == "file")
        path = url.toLocalFile();
    else
        path = url.toString();

    QImage img = readDownscaled(path, 160);
    qDebug() << "McuTheme: read image" << path
             << "size:" << img.size();

    if (img.isNull()) {
        return false;
    }

    const int w = img.width(), h = img.height();
    std::vector<uint32_t> pixels(size_t(w) * size_t(h));
    for (int y = 0; y < h; ++y) {
        const uint32_t* row = reinterpret_cast<const uint32_t*>(img.constScanLine(y));
        std::copy(row, row + w, pixels.begin() + size_t(y) * size_t(w));
    }

    auto quant  = QuantizeCelebi(pixels, 128);
    auto ranked = material_color_utilities::RankedSuggestions(quant.color_to_count);

    if (ranked.empty()) return false;

    outSeed = ranked.front();
    return true;
}

void McuTheme::applySeed() {
    if (!m_seedArgb) return;
    const auto requestId = ++m_generation;
    const uint32_t seed = m_seedArgb;
    const bool dark = m_darkMode;
    const QString variant = m_variant;
    const double contrast = m_contrast;

    if (!m_loading) {
        m_loading = true;
        emit loadingChanged();
    }

    // Генерация в пуле потоков, чтобы не блокировать GUI
    m_future = QtConcurrent::run([this, requestId, seed, dark, variant, contrast]() {
        const QVariantMap colors = buildScheme(seed, dark, variant, contrast);

        QMetaObject::invokeMethod(this, [this, requestId, colors]() {
            if (requestId != m_generation) {
                return; // устаревший результат
            }

            m_colors = colors;
            m_valid = true;
            emit validChanged();
            emit colorsChanged();

            if (m_loading) {
                m_loading = false;
                emit loadingChanged();
            }
        }, Qt::QueuedConnection);
    });
}

QVariantMap McuTheme::buildScheme(uint32_t seedArgb, bool dark, const QString& variant, double contrast) const {
    using namespace material_color_utilities;

    Hct sourceHct(seedArgb);

    qDebug() << "McuTheme: generateColorScheme from ARGB"
             << QString("#%1").arg(seedArgb,8,16,QLatin1Char('0')).toUpper();

    std::unique_ptr<DynamicScheme> scheme;
    if (variant == "vibrant")
        scheme = std::make_unique<SchemeVibrant>(sourceHct, dark, contrast);
    else if (variant == "expressive")
        scheme = std::make_unique<SchemeExpressive>(sourceHct, dark, contrast);
    else if (variant == "content")
        scheme = std::make_unique<SchemeContent>(sourceHct, dark, contrast);
    else
        scheme = std::make_unique<SchemeTonalSpot>(sourceHct, dark, contrast);

    QVariantMap result;

    auto put = [&](const char* key, DynamicColor dc) {
        result.insert(QString::fromLatin1(key),
                      argbToHex(dc.GetArgb(*scheme)));
    };

    // Material 3 roles
    put("primary",              MaterialDynamicColors::Primary());
    put("onPrimary",            MaterialDynamicColors::OnPrimary());
    put("primaryContainer",     MaterialDynamicColors::PrimaryContainer());
    put("onPrimaryContainer",   MaterialDynamicColors::OnPrimaryContainer());

    put("secondary",            MaterialDynamicColors::Secondary());
    put("onSecondary",          MaterialDynamicColors::OnSecondary());
    put("secondaryContainer",   MaterialDynamicColors::SecondaryContainer());
    put("onSecondaryContainer", MaterialDynamicColors::OnSecondaryContainer());

    put("tertiary",             MaterialDynamicColors::Tertiary());
    put("onTertiary",           MaterialDynamicColors::OnTertiary());
    put("tertiaryContainer",    MaterialDynamicColors::TertiaryContainer());
    put("onTertiaryContainer",  MaterialDynamicColors::OnTertiaryContainer());

    put("error",                MaterialDynamicColors::Error());
    put("onError",              MaterialDynamicColors::OnError());
    put("errorContainer",       MaterialDynamicColors::ErrorContainer());
    put("onErrorContainer",     MaterialDynamicColors::OnErrorContainer());

    put("surface",              MaterialDynamicColors::Surface());
    put("onSurface",            MaterialDynamicColors::OnSurface());
    put("surfaceVariant",       MaterialDynamicColors::SurfaceVariant());
    put("onSurfaceVariant",     MaterialDynamicColors::OnSurfaceVariant());
    put("outline",              MaterialDynamicColors::Outline());
    put("outlineVariant",       MaterialDynamicColors::OutlineVariant());

    put("inverseSurface",       MaterialDynamicColors::InverseSurface());
    put("inverseOnSurface",     MaterialDynamicColors::InverseOnSurface());
    put("inversePrimary",       MaterialDynamicColors::InversePrimary());

    put("background",           MaterialDynamicColors::Background());
    put("onBackground",         MaterialDynamicColors::OnBackground());

    put("surfaceDim",           MaterialDynamicColors::SurfaceDim());
    put("surfaceBright",        MaterialDynamicColors::SurfaceBright());
    put("surfaceContainerLowest",MaterialDynamicColors::SurfaceContainerLowest());
    put("surfaceContainerLow",  MaterialDynamicColors::SurfaceContainerLow());
    put("surfaceContainer",     MaterialDynamicColors::SurfaceContainer());
    put("surfaceContainerHigh", MaterialDynamicColors::SurfaceContainerHigh());
    put("surfaceContainerHighest", MaterialDynamicColors::SurfaceContainerHighest());
    put("primaryPaletteKeyColor", MaterialDynamicColors::PrimaryPaletteKeyColor());
    put("secondaryPaletteKeyColor", MaterialDynamicColors::SecondaryPaletteKeyColor());
    put("tertiaryPaletteKeyColor", MaterialDynamicColors::TertiaryPaletteKeyColor());
    put("neutralPaletteKeyColor", MaterialDynamicColors::NeutralPaletteKeyColor());
    put("neutralVariantPaletteKeyColor", MaterialDynamicColors::NeutralVariantPaletteKeyColor());
    put("shadow", MaterialDynamicColors::Shadow());
    put("scrim", MaterialDynamicColors::Scrim());
    put("surfaceTint", MaterialDynamicColors::SurfaceTint());
    put("primaryFixed", MaterialDynamicColors::PrimaryFixed());
    put("primaryFixedDim", MaterialDynamicColors::PrimaryFixedDim());
    put("onPrimaryFixed", MaterialDynamicColors::OnPrimaryFixed());
    put("onPrimaryFixedVariant", MaterialDynamicColors::OnPrimaryFixedVariant());
    put("secondaryFixed", MaterialDynamicColors::SecondaryFixed());
    put("secondaryFixedDim", MaterialDynamicColors::SecondaryFixedDim());
    put("onSecondaryFixed", MaterialDynamicColors::OnSecondaryFixed());
    put("onSecondaryFixedVariant", MaterialDynamicColors::OnSecondaryFixedVariant());
    put("tertiaryFixed", MaterialDynamicColors::TertiaryFixed());
    put("tertiaryFixedDim", MaterialDynamicColors::TertiaryFixedDim());
    put("onTertiaryFixed", MaterialDynamicColors::OnTertiaryFixed());
    put("onTertiaryFixedVariant", MaterialDynamicColors::OnTertiaryFixedVariant());

    qDebug() << "McuTheme: generated" << result.size() << "colors";
    return result;
}
