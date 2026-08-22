pragma Singleton

import QtQuick
import Quickshell
import Mcu 1.0

Singleton {
    id: root

    // Palette seed (wallpaper URL). Pushed by WallpaperManager via Binding —
    // config never imports services (one-way dependency graph, AGENTS §3).
    property url seed

    McuTheme {
        id: mcuTheme
        source: root.seed.toString() !== "" ? root.seed : Qt.alpha("#6200EE", 0)
        darkMode: AppConfig.darkMode
        variant: AppConfig.themeVariant
        // Was hardcoded 0.5 with no comment and no config key. That is MCU's
        // accessibility high-contrast level, not "a bit more punch": in a dark
        // scheme it flips every *Container role light and its on* color black,
        // so tonal buttons, chips, the active workspace pill and critical
        // notifications all rendered as glaring blocks. Standard M3 is 0.0;
        // users who want the accessibility variant now opt in via config.
        contrast: AppConfig.themeContrast
    }

    // Color roles — flat access: Theme.primary, Theme.onSurface, etc.
    property color primary
    property color onPrimary
    property color primaryContainer
    property color onPrimaryContainer

    property color secondary
    property color onSecondary
    property color secondaryContainer
    property color onSecondaryContainer

    property color tertiary
    property color onTertiary
    property color tertiaryContainer
    property color onTertiaryContainer

    property color error
    property color onError
    property color errorContainer
    property color onErrorContainer

    property color surface
    property color onSurface
    property color surfaceVariant
    property color onSurfaceVariant
    property color outline
    property color outlineVariant

    property color background
    property color onBackground

    property color inverseSurface
    property color inverseOnSurface
    property color inversePrimary

    property color surfaceDim
    property color surfaceBright
    property color surfaceContainerLowest
    property color surfaceContainerLow
    property color surfaceContainer
    property color surfaceContainerHigh
    property color surfaceContainerHighest

    property color primaryPaletteKeyColor
    property color secondaryPaletteKeyColor
    property color tertiaryPaletteKeyColor
    property color neutralPaletteKeyColor
    property color neutralVariantPaletteKeyColor
    property color shadow
    property color scrim
    // M3 defines no on-scrim role; the scrim is always dark.
    readonly property color scrimForeground: "#FFFFFF"
    property color surfaceTint
    property color primaryFixed
    property color primaryFixedDim
    property color onPrimaryFixed
    property color onPrimaryFixedVariant
    property color secondaryFixed
    property color secondaryFixedDim
    property color onSecondaryFixed
    property color onSecondaryFixedVariant
    property color tertiaryFixed
    property color tertiaryFixedDim
    property color onTertiaryFixed
    property color onTertiaryFixedVariant

    function apply(map) {
        for (var k in map) {
            if (root.hasOwnProperty(k)) {
                root[k] = map[k];
            }
        }
    }

    // --- Contrast ---------------------------------------------------------------
    // WCAG 2.1 relative luminance. Qt exposes colour channels as sRGB in 0..1.
    function _channel(v) {
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    }

    function _luminance(c) {
        return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);
    }

    function contrastRatio(a, b) {
        const la = root._luminance(a);
        const lb = root._luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // An outline that is guaranteed to stay visible on `bg`.
    //
    // MCU re-derives the entire palette from every wallpaper, so `outlineVariant`
    // sits at no fixed distance from the surface it is drawn on: on one wallpaper
    // it is a clean edge, on the next it collapses into the fill. A design that
    // separates surfaces with a hairline instead of a shadow cannot survive that,
    // so the colour is stepped toward black or white until it clears `minRatio`.
    function outlineOn(bg, minRatio) {
        const base = root.outlineVariant;
        if (root.contrastRatio(base, bg) >= minRatio)
            return base;
        // Step away from the surface, not toward a fixed colour: a light surface
        // needs a darker line and a dark one needs a lighter line.
        const toward = root._luminance(bg) > 0.18 ? 0.0 : 1.0;
        for (let t = 0.15; t < 1.0; t += 0.15) {
            const c = Qt.rgba(base.r + (toward - base.r) * t,
                              base.g + (toward - base.g) * t,
                              base.b + (toward - base.b) * t,
                              1.0);
            if (root.contrastRatio(c, bg) >= minRatio)
                return c;
        }
        return Qt.rgba(toward, toward, toward, 1.0);
    }

    Component.onCompleted: {
        root.apply(mcuTheme.colors);
    }

    Connections {
        target: mcuTheme
        function onColorsChanged() {
            root.apply(mcuTheme.colors);
        }
    }
}
