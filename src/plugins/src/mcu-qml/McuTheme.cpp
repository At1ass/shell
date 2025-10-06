#include "McuTheme.h"

#include <QImage>
#include <QImageReader>
#include <QFileInfo>
#include <QUrl>
#include <qlogging.h>
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

        // считаем seed один раз (с даунскейлом)
        if (makeSeedFromImageUrl(u)) {
            applySeed();
        } else {
            qWarning() << "McuTheme: failed to extract seed from image" << u;
        }
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

bool McuTheme::makeSeedFromImageUrl(const QUrl& url) {
    QString path;
    if (url.isLocalFile() || url.scheme() == "file")
        path = url.toLocalFile();
    else
        path = url.toString(); // если нужен non-file (http/https) — расширяй по желанию

    return makeSeedFromImagePath(path);
}

bool McuTheme::makeSeedFromImagePath(const QString& path) {
    m_loading = true; emit loadingChanged();

    QImage img = readDownscaled(path, 160);
    qDebug() << "McuTheme: read image" << path
             << "size:" << img.size();

    if (img.isNull()) {
        m_loading = false; emit loadingChanged();
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

    m_loading = false; emit loadingChanged();

    if (ranked.empty()) return false;

    m_seedArgb = ranked.front();
    return true;
}

void McuTheme::applySeed() {
    if (!m_seedArgb) return;
    generateColorScheme(m_seedArgb);
}

void McuTheme::generateColorScheme(uint32_t seedArgb) {
    using namespace material_color_utilities;

    Hct sourceHct(seedArgb);

    qDebug() << "McuTheme: generateColorScheme from ARGB"
             << QString("#%1").arg(seedArgb,8,16,QLatin1Char('0')).toUpper();

    std::unique_ptr<DynamicScheme> scheme;
    if (m_variant == "vibrant")
        scheme = std::make_unique<SchemeVibrant>(sourceHct, m_darkMode, m_contrast);
    else if (m_variant == "expressive")
        scheme = std::make_unique<SchemeExpressive>(sourceHct, m_darkMode, m_contrast);
    else if (m_variant == "content")
        scheme = std::make_unique<SchemeContent>(sourceHct, m_darkMode, m_contrast);
    else
        scheme = std::make_unique<SchemeTonalSpot>(sourceHct, m_darkMode, m_contrast);

    auto put = [&](const char* key, DynamicColor dc) {
        m_colors.insert(QString::fromLatin1(key),
                        argbToHex(dc.GetArgb(*scheme)));
    };

    m_colors.clear();

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

    qDebug() << "McuTheme: generated" << m_colors.size() << "colors";
    m_valid = true;
    emit validChanged();
    emit colorsChanged();
}
