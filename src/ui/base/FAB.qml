import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.src.core.config
import qs.src.ui.feedback

// Material Design 3 Floating Action Button. Regular/small/large; extended when `label` is set.
Item {
    id: root

    property string iconName: "add"
    property string label: "" // non-empty → extended FAB
    property string size: "regular" // "small" | "regular" | "large"

    signal clicked()

    readonly property bool extended: label !== ""
    readonly property int _dim: size === "small" ? 40 : (size === "large" ? 96 : 56)
    readonly property int _radius: size === "small" ? Tokens.shape.medium
                                 : (size === "large" ? Tokens.shape.extraLarge : Tokens.shape.large)
    readonly property int _iconSize: size === "large" ? Tokens.iconSize.extraLarge : Tokens.iconSize.large

    implicitHeight: _dim
    implicitWidth: extended ? content.implicitWidth + Tokens.spacing.medium * 2 : _dim

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    MultiEffect {
        source: bg
        anchors.fill: bg
        z: -1
        visible: root.enabled
        shadowEnabled: root.enabled
        shadowColor: Qt.alpha(Theme.shadow, Tokens.elevation.level3.shadowOpacity)
        blurMax: 64
        shadowBlur: Tokens.elevation.level3.shadowRadius / 64
        shadowVerticalOffset: Tokens.elevation.level3.shadowVerticalOffset
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root._radius
        color: Theme.primaryContainer

        StateLayer {
            target: bg
            layerColor: Theme.onPrimaryContainer
            hovered: mouse.containsMouse
            pressed: mouse.pressed
            showFocusRing: false
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            iconName: root.iconName
            fontSize: root._iconSize
            iconColor: Theme.onPrimaryContainer
            backgroundColor: "transparent"
        }

        MaterialText {
            visible: root.extended
            text: root.label
            textStyle: "labelLarge"
            color: Theme.onPrimaryContainer
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
