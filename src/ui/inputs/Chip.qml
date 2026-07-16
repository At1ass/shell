import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Material Design 3 Chip (assist / filter / input / suggestion).
// `selectable` enables filter behaviour: when `selected`, fills secondaryContainer and
// shows a leading check.
Item {
    id: root

    property string label: ""
    property string icon: "" // leading icon (Material Symbols)
    property bool selectable: false
    property bool selected: false

    signal clicked()

    implicitHeight: 32
    implicitWidth: row.implicitWidth + Tokens.spacing.medium * 2

    opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity

    readonly property color _contentColor: selected ? Theme.onSecondaryContainer : Theme.onSurfaceVariant

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.shape.small
        color: root.selected ? Theme.secondaryContainer : "transparent"
        border.width: root.selected ? 0 : 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.duration.short3
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
            }
        }

        StateLayer {
            target: bg
            layerColor: root._contentColor
            hovered: mouseArea.containsMouse
            pressed: mouseArea.pressed
            showFocusRing: false
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: (root.selectable && root.selected) || root.icon !== ""
            iconName: (root.selectable && root.selected) ? "check" : root.icon
            fontSize: Tokens.iconSize.small
            iconColor: root._contentColor
            backgroundColor: "transparent"
        }

        MaterialText {
            text: root.label
            textStyle: "labelLarge"
            color: root._contentColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
