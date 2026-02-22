pragma Singleton

import QtQuick
import Quickshell
import Mcu 1.0
import qs.src.core.services

Singleton {
    id: root

    McuTheme {
        id: mcuTheme
        source: WallpaperService.currentWallpaper !== "" ? WallpaperService.currentWallpaper : Qt.alpha("#6200EE", 0)
        darkMode: AppConfig.data.appearance?.theme?.darkMode ?? GlobalStates.darkMode
        variant: AppConfig.data.appearance?.theme?.variant ?? "tonalspot"
        contrast: 0.5
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
