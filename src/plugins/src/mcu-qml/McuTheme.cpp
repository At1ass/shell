#include "McuTheme.h"

#include <QImage>
#include <QImageReader>
#include <QFileInfo>
#include <QUrl>
#include <QMetaObject>
#include <QCoreApplication>
#include <qlogging.h>
#include <QtConcurrent>
#include <vector>
#include <algorithm>

// MCU headers
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
    r.setAllocationLimit(128); // MB — guard against gigantic images
#endif
    const QSize s = r.size();  // may be (0,0) for some formats
    if (s.isValid()) {
        QSize t = s;
        t.scale(QSize(maxSide, maxSide), Qt::KeepAspectRatio);
        r.setScaledSize(t);    // downscale during decode
    }
    QImage img = r.read();
    if (img.isNull()) {
        return img;
    }
    // Formats that cannot report their size upfront decode at full
    // resolution — scale down before quantization runs on megapixels.
    if (!s.isValid() && (img.width() > maxSide || img.height() > maxSide)) {
        img = img.scaled(maxSide, maxSide, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (img.format() != QImage::Format_ARGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);
    return img;
}

McuTheme::McuTheme(QObject* parent) : QObject(parent) {
    // Default seed color
    setSource(QColor("#6750A4"));
}

McuTheme::~McuTheme() {
    // Invalidate generation counters so queued callbacks do no work
    // (QPointer protects against use-after-free, the generation guard
    // against stale updates).
    m_generation = UINT64_MAX;
    m_seedRequest = UINT64_MAX;

    // Wait for EVERY in-flight task for a clean shutdown — superseded
    // futures included (their lambdas only touch QPointer + statics).
    for (auto& f : m_inflight) {
        if (f.isRunning())
            f.waitForFinished();
    }
}

void McuTheme::setValidInternal(bool v) {
    if (m_valid == v) return;
    m_valid = v;
    emit validChanged();
}

void McuTheme::trackFuture(const QFuture<void>& f) {
    m_inflight.removeIf([](const QFuture<void>& g) { return g.isFinished(); });
    m_inflight.append(f);
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
        // Color — fast path
        const QColor c = v.value<QColor>();
        if (!c.isValid()) {
            qWarning() << "McuTheme: invalid QColor in source";
            return;
        }
        m_source   = v;
        m_kind     = SourceKind::Color;
        m_seedArgb = qcolorToArgb(c);
        setValidInternal(false); // true again after generateColorScheme

        // Luminance from QColor (Rec. 709)
        const qreal lum = 0.2126 * c.redF() + 0.7152 * c.greenF() + 0.0722 * c.blueF();
        if (!qFuzzyCompare(m_luminance, lum)) {
            m_luminance = lum;
            emit luminanceChanged();
        }

        emit sourceChanged();
        applySeed();
        return;
    }

    if (id == QMetaType::QUrl) {
        const QUrl u = v.toUrl();
        if (!u.isValid() || u.isEmpty()) {
            qWarning() << "McuTheme: invalid QUrl in source";
            return;
        }
        m_source = v;
        m_kind   = SourceKind::Image;
        setValidInternal(false);
        emit sourceChanged();

        const auto requestId = ++m_seedRequest;
        if (!m_loading) {
            m_loading = true;
            emit loadingChanged();
        }

        auto future = QtConcurrent::run([guard = QPointer<McuTheme>(this), requestId, u]() {
            uint32_t seed = 0;
            qreal luminance = 0.5;
            const bool ok = extractSeedFromImage(u, seed, luminance);
            auto* app = QCoreApplication::instance();
            if (!app) return;
            QMetaObject::invokeMethod(app, [guard, requestId, ok, seed, luminance, u]() {
                if (!guard) return;
                if (requestId != guard->m_seedRequest)
                    return;
                if (!ok) {
                    qWarning() << "McuTheme: failed to extract seed from image" << u;
                    if (guard->m_loading) {
                        guard->m_loading = false;
                        emit guard->loadingChanged();
                    }
                    return;
                }
                guard->m_seedArgb = seed;
                if (!qFuzzyCompare(guard->m_luminance, luminance)) {
                    guard->m_luminance = luminance;
                    emit guard->luminanceChanged();
                }
                guard->applySeed();
            }, Qt::QueuedConnection);
        });
        trackFuture(future);
        return;
    }

    // No strings: they are the main source of ambiguity.
    qWarning() << "McuTheme: source must be QColor or QUrl; QString not supported."
               << "Got type:" << v.metaType().name();
}

void McuTheme::setDarkMode(bool dark) {
    if (m_darkMode == dark) return;
    m_darkMode = dark;
    emit darkModeChanged();
    applySeed(); // no re-quantization needed
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

bool McuTheme::extractSeedFromImage(const QUrl& url, uint32_t& outSeed, qreal& outLuminance) {
    QString path;
    if (url.isLocalFile() || url.scheme() == "file")
        path = url.toLocalFile();
    else
        path = url.toString();

    QImage img = readDownscaled(path, 160);
    if (img.isNull()) {
        return false;
    }

    const int w = img.width(), h = img.height();
    const size_t pixelCount = size_t(w) * size_t(h);
    std::vector<uint32_t> pixels(pixelCount);

    // Copy pixels and accumulate luminance (Rec. 709) in one pass
    double lumSum = 0.0;
    size_t lumCount = 0;
    for (int y = 0; y < h; ++y) {
        const uint32_t* row = reinterpret_cast<const uint32_t*>(img.constScanLine(y));
        const size_t offset = size_t(y) * size_t(w);
        for (int x = 0; x < w; ++x) {
            const uint32_t px = row[x];
            pixels[offset + size_t(x)] = px;
            const uint8_t a = (px >> 24) & 0xFF;
            if (a == 0) continue;
            const double r = ((px >> 16) & 0xFF) / 255.0;
            const double g = ((px >> 8)  & 0xFF) / 255.0;
            const double b = ( px        & 0xFF) / 255.0;
            lumSum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
            ++lumCount;
        }
    }
    outLuminance = lumCount > 0 ? (lumSum / lumCount) : 0.5;

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

    // Generate in the thread pool to keep the GUI thread free. The QPointer
    // guard prevents use-after-free; the generation guard drops stale
    // results. buildScheme is static and never touches `this`.
    auto future = QtConcurrent::run([guard = QPointer<McuTheme>(this), requestId, seed, dark, variant, contrast]() {
        const QVariantMap colors = buildScheme(seed, dark, variant, contrast);

        auto* app = QCoreApplication::instance();
        if (!app) return;
        QMetaObject::invokeMethod(app, [guard, requestId, colors]() {
            if (!guard) return;
            if (requestId != guard->m_generation)
                return;

            guard->m_colors = colors;
            guard->setValidInternal(true);
            emit guard->colorsChanged();

            if (guard->m_loading) {
                guard->m_loading = false;
                emit guard->loadingChanged();
            }
        }, Qt::QueuedConnection);
    });
    trackFuture(future);
}

QVariantMap McuTheme::buildScheme(uint32_t seedArgb, bool dark, const QString& variant, double contrast) {
    using namespace material_color_utilities;

    Hct sourceHct(seedArgb);

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

    return result;
}
