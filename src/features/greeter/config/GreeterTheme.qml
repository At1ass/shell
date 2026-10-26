pragma Singleton

import QtQuick
import Quickshell
import Mcu 1.0

Singleton {
    id: root

    // McuTheme.source accepts QColor or QUrl and REJECTS a QString outright
    // ("source must be QColor or QUrl; QString not supported"). GreeterConfig
    // exposes wallpaperPath as a plain string, so the greeter was silently
    // losing its wallpaper-derived palette and falling back to the seed colour
    // on every boot. Assigning through a `url` property is what makes QML
    // coerce it — this mirrors Theme.seed in the main shell.
    // A BARE PATH IS NOT A URL. wallpaperPath comes out of greeter.json as
    // "/etc/greetd/wallpaper.jpg"; coercing that to `url` yields a scheme-less relative
    // URL that McuTheme cannot open, so the palette stayed at its uninitialised
    // #000000 for every role. WallpaperManager._asUrl does the same conversion
    // on the main-shell side — this is the greeter's copy of it.
    readonly property url seed: {
        const p = GreeterConfig.wallpaperPath
        if (!p || p.length === 0)
            return ""
        return p.startsWith("file://") ? p : Qt.resolvedUrl(p)
    }

    McuTheme {
        id: mcuTheme
        source: root.seed.toString() !== ""
            ? root.seed
            : Qt.alpha(GreeterConfig.themeColor, 0)
        darkMode: GreeterConfig.darkMode
        variant: GreeterConfig.themeVariant
        // Same fix as the main shell: 0.5 is MCU's accessibility high-contrast
        // level, which flips every *Container role light and its on* colour
        // black. Standard M3 is 0.0; opt in via greeter.json instead.
        contrast: GreeterConfig.themeContrast
    }

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

    function outlineOn(bg, minRatio) { return root.outline }

    function apply(map) {
        for (var k in map) {
            if (root.hasOwnProperty(k)) {
                root[k] = map[k];
            }
        }
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
