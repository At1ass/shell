// pragma Singleton

import QtQuick
import Quickshell
import qs.src.core.services

Singleton {
    id: root

    property bool light: false
    property bool transparencyEnabled: true
    property real transparencyBase: 0.85
    property real transparencyLayers: 0.40

    readonly property real wallLuminance: WallpaperAnalyzer.luminance
    readonly property QtObject palette: M3Palette {}
    readonly property QtObject tPalette: M3TPalette {}

    function applyPalette(map) {
        if (!map) {
            return
        }

        for (let key in map) {
            if (palette.hasOwnProperty(key)) {
                palette[key] = map[key]
            }
        }
    }

    function getLuminance(c) {
        if (c.r === 0 && c.g === 0 && c.b === 0) {
            return 0
        }
        return Math.sqrt(
            0.299 * Math.pow(c.r, 2)
            + 0.587 * Math.pow(c.g, 2)
            + 0.114 * Math.pow(c.b, 2)
        )
    }

    function effectiveBaseAlpha() {
        const base = transparencyBase - (light ? 0.1 : 0.0)
        return Math.max(0.0, Math.min(1.0, base))
    }

    function alterColor(c, alpha, layer) {
        const luminance = getLuminance(c)
        if (luminance <= 0) {
            return Qt.rgba(c.r, c.g, c.b, alpha)
        }

        const offset = (!light || layer === 1 ? 1 : -layer / 2)
            * (light ? 0.2 : 0.3)
            * (1 - effectiveBaseAlpha())
            * (1 + wallLuminance * (light ? (layer === 1 ? 3 : 1) : 2.5))

        const scale = (luminance + offset) / luminance
        const r = Math.max(0, Math.min(1, c.r * scale))
        const g = Math.max(0, Math.min(1, c.g * scale))
        const b = Math.max(0, Math.min(1, c.b * scale))

        return Qt.rgba(r, g, b, alpha)
    }

    function layer(c, level) {
        if (!transparencyEnabled) {
            return c
        }

        const resolvedLevel = (level === undefined || level === null) ? 1 : level
        return resolvedLevel === 0
            ? Qt.alpha(c, effectiveBaseAlpha())
            : alterColor(c, transparencyLayers, resolvedLevel)
    }

    function on(c) {
        if (c.hslLightness < 0.5) {
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1)
        }
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1)
    }

    component M3TPalette: QtObject {
        readonly property color primary: root.palette.primary
        readonly property color onPrimary: root.palette.onPrimary
        readonly property color primaryContainer: root.layer(root.palette.primaryContainer, 1)
        readonly property color onPrimaryContainer: root.palette.onPrimaryContainer

        readonly property color secondary: root.palette.secondary
        readonly property color onSecondary: root.palette.onSecondary
        readonly property color secondaryContainer: root.layer(root.palette.secondaryContainer, 1)
        readonly property color onSecondaryContainer: root.palette.onSecondaryContainer

        readonly property color tertiary: root.palette.tertiary
        readonly property color onTertiary: root.palette.onTertiary
        readonly property color tertiaryContainer: root.layer(root.palette.tertiaryContainer, 1)
        readonly property color onTertiaryContainer: root.palette.onTertiaryContainer

        readonly property color error: root.palette.error
        readonly property color onError: root.palette.onError
        readonly property color errorContainer: root.layer(root.palette.errorContainer, 1)
        readonly property color onErrorContainer: root.palette.onErrorContainer

        readonly property color background: root.layer(root.palette.background, 0)
        readonly property color onBackground: root.palette.onBackground

        readonly property color surface: root.layer(root.palette.surface, 0)
        readonly property color surfaceDim: root.layer(root.palette.surfaceDim, 0)
        readonly property color surfaceBright: root.layer(root.palette.surfaceBright, 0)
        readonly property color surfaceContainerLowest: root.layer(root.palette.surfaceContainerLowest, 1)
        readonly property color surfaceContainerLow: root.layer(root.palette.surfaceContainerLow, 1)
        readonly property color surfaceContainer: root.layer(root.palette.surfaceContainer, 1)
        readonly property color surfaceContainerHigh: root.layer(root.palette.surfaceContainerHigh, 2)
        readonly property color surfaceContainerHighest: root.layer(root.palette.surfaceContainerHighest, 3)

        readonly property color onSurface: root.palette.onSurface
        readonly property color surfaceVariant: root.layer(root.palette.surfaceVariant, 0)
        readonly property color onSurfaceVariant: root.palette.onSurfaceVariant

        readonly property color outline: root.palette.outline
        readonly property color outlineVariant: root.palette.outlineVariant

        readonly property color inverseSurface: root.layer(root.palette.inverseSurface, 0)
        readonly property color inverseOnSurface: root.palette.inverseOnSurface
        readonly property color inversePrimary: root.palette.inversePrimary

        readonly property color shadow: root.palette.shadow
        readonly property color scrim: root.palette.scrim
        readonly property color surfaceTint: root.palette.surfaceTint

        readonly property color primaryPaletteKeyColor: root.palette.primaryPaletteKeyColor
        readonly property color secondaryPaletteKeyColor: root.palette.secondaryPaletteKeyColor
        readonly property color tertiaryPaletteKeyColor: root.palette.tertiaryPaletteKeyColor
        readonly property color neutralPaletteKeyColor: root.palette.neutralPaletteKeyColor
        readonly property color neutralVariantPaletteKeyColor: root.palette.neutralVariantPaletteKeyColor

        readonly property color primaryFixed: root.palette.primaryFixed
        readonly property color primaryFixedDim: root.palette.primaryFixedDim
        readonly property color onPrimaryFixed: root.palette.onPrimaryFixed
        readonly property color onPrimaryFixedVariant: root.palette.onPrimaryFixedVariant
        readonly property color secondaryFixed: root.palette.secondaryFixed
        readonly property color secondaryFixedDim: root.palette.secondaryFixedDim
        readonly property color onSecondaryFixed: root.palette.onSecondaryFixed
        readonly property color onSecondaryFixedVariant: root.palette.onSecondaryFixedVariant
        readonly property color tertiaryFixed: root.palette.tertiaryFixed
        readonly property color tertiaryFixedDim: root.palette.tertiaryFixedDim
        readonly property color onTertiaryFixed: root.palette.onTertiaryFixed
        readonly property color onTertiaryFixedVariant: root.palette.onTertiaryFixedVariant
    }

    component M3Palette: QtObject {
        property color primary: "#000000"
        property color onPrimary: "#ffffff"
        property color primaryContainer: "#000000"
        property color onPrimaryContainer: "#ffffff"

        property color secondary: "#000000"
        property color onSecondary: "#ffffff"
        property color secondaryContainer: "#000000"
        property color onSecondaryContainer: "#ffffff"

        property color tertiary: "#000000"
        property color onTertiary: "#ffffff"
        property color tertiaryContainer: "#000000"
        property color onTertiaryContainer: "#ffffff"

        property color error: "#000000"
        property color onError: "#ffffff"
        property color errorContainer: "#000000"
        property color onErrorContainer: "#ffffff"

        property color surface: "#000000"
        property color onSurface: "#ffffff"
        property color surfaceVariant: "#000000"
        property color onSurfaceVariant: "#ffffff"
        property color outline: "#000000"
        property color outlineVariant: "#000000"

        property color background: "#000000"
        property color onBackground: "#ffffff"

        property color inverseSurface: "#ffffff"
        property color inverseOnSurface: "#000000"
        property color inversePrimary: "#000000"

        property color surfaceDim: "#000000"
        property color surfaceBright: "#000000"
        property color surfaceContainerLowest: "#000000"
        property color surfaceContainerLow: "#000000"
        property color surfaceContainer: "#000000"
        property color surfaceContainerHigh: "#000000"
        property color surfaceContainerHighest: "#000000"

        property color primaryPaletteKeyColor: "#000000"
        property color secondaryPaletteKeyColor: "#000000"
        property color tertiaryPaletteKeyColor: "#000000"
        property color neutralPaletteKeyColor: "#000000"
        property color neutralVariantPaletteKeyColor: "#000000"
        property color shadow: "#000000"
        property color scrim: "#000000"
        property color surfaceTint: "#000000"
        property color primaryFixed: "#000000"
        property color primaryFixedDim: "#000000"
        property color onPrimaryFixed: "#ffffff"
        property color onPrimaryFixedVariant: "#ffffff"
        property color secondaryFixed: "#000000"
        property color secondaryFixedDim: "#000000"
        property color onSecondaryFixed: "#ffffff"
        property color onSecondaryFixedVariant: "#ffffff"
        property color tertiaryFixed: "#000000"
        property color tertiaryFixedDim: "#000000"
        property color onTertiaryFixed: "#ffffff"
        property color onTertiaryFixedVariant: "#ffffff"
    }
}
