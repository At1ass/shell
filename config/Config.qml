pragma Singleton
import QtQuick

QtObject {
    id: config

    // Material Design 3 Colors
    property QtObject colors: QtObject {
        // Dark theme colors following Material Design 3
        property color background: "#0f0f13"
        property color surface: "#1c1b1f"
        property color surfaceVariant: "#49454f"
        property color primary: "#d0bcff"
        property color primaryContainer: "#4f378b"
        property color secondary: "#ccc2dc"
        property color tertiary: "#efb8c8"
        property color onBackground: "#e6e1e5"
        property color onSurface: "#e6e1e5"
        property color onPrimary: "#371e73"
        property color onPrimaryContainer: "#eaddff"
        property color onSurfaceVariant: "#cab6cf"
        property color outline: "#938f99"
        property color outlineVariant: "#49454f"
        property color error: "#f2b8b5"
        property color warning: "#ffd8e4"
        property color success: "#b3e5fc"
    }

    // Material Design spacing
    property QtObject spacing: QtObject {
        property int extraSmall: 4
        property int small: 8
        property int medium: 12
        property int large: 16
        property int extraLarge: 24
        property int huge: 32
    }

    // Material Design radius
    property QtObject radius: QtObject {
        property int small: 4
        property int medium: 8
        property int large: 12
        property int extraLarge: 16
        property int full: 28
    }

    // Bar configuration
    property QtObject bar: QtObject {
        property string position: "left"
        property int width: 56  // Material Design FAB width
        property int height: 48
        property color background: config.colors.surface
        property real backgroundOpacity: 0.96
        property int cornerRadius: config.radius.large
        property int margin: config.spacing.large

        property var entries: [
            {"id": "workspaces", "enabled": true},
            {"id": "spacer", "enabled": true},
            {"id": "tray", "enabled": true},
            {"id": "system", "enabled": true},
            {"id": "clock", "enabled": true}
        ]
    }

    // Typography following Material Design 3
    property QtObject typography: QtObject {
        property string fontFamily: "Inter, Roboto, system-ui, sans-serif"
        property int displayLarge: 57
        property int displayMedium: 45
        property int displaySmall: 36
        property int headlineLarge: 32
        property int headlineMedium: 28
        property int headlineSmall: 24
        property int titleLarge: 22
        property int titleMedium: 16
        property int titleSmall: 14
        property int labelLarge: 14
        property int labelMedium: 12
        property int labelSmall: 11
        property int bodyLarge: 16
        property int bodyMedium: 14
        property int bodySmall: 12
    }

    // Animations following Material Motion
    property QtObject animations: QtObject {
        property int durationShort: 150
        property int durationMedium: 300
        property int durationLong: 500
        property int durationExtraLong: 700

        // Material Design 3 easing curves
        property var emphasized: [0.2, 0.0, 0, 1.0]
        property var standard: [0.2, 0.0, 0, 1.0]
        property var decelerated: [0.0, 0.0, 0.2, 1.0]
        property var accelerated: [0.3, 0.0, 1.0, 1.0]
    }
}