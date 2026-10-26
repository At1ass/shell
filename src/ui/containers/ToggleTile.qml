import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// A labelled on/off tile.
//
// State is carried by FILL and by a status dot, on one axis of value. It used to
// be carried by a permanent outline as well, and a grid of these was the single
// biggest source of visual noise in the dashboard: eight full-strength rectangles
// competing with their own labels, the active ones outlined in the accent colour
// so that "on" read as "focused" instead.
//
// The dot is what an outline was standing in for -- a mark that says on/off
// without restating the whole shape. Accent appears there and nowhere else on the
// tile, which is what makes it visible at all.
//
// The label is not optional. The panel this replaces used icon-only buttons with
// a hover tooltip, so what a toggle did was learned by memory or by waiting.
AbstractButton {
    id: root

    property string iconName: ""
    property string label: ""
    property string supportingText: ""
    property bool active: false
    property bool showStateIndicator: true
    property string trailingIcon: ""
    property bool showLabel: true

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return
        if (root.enabled && !event.isAutoRepeat) root.clicked()
        event.accepted = true
    }
    Accessible.name: root.label
    Accessible.description: root.supportingText
    Accessible.role: root.showStateIndicator ? Accessible.CheckBox : Accessible.Button
    Accessible.checked: root.active
    Accessible.onToggleAction: if (root.enabled && root.showStateIndicator) root.clicked()
    opacity: enabled ? 1 : Tokens.state.disabledContentOpacity

    leftPadding: Tokens.spacing.small
    rightPadding: Tokens.spacing.small
    topPadding: Tokens.spacing.extraSmall
    bottomPadding: Tokens.spacing.extraSmall

    implicitWidth: Math.max(Tokens.size.tileMinimumWidth, row.implicitWidth + Tokens.spacing.small * 2)
    implicitHeight: Math.max(Tokens.size.control, row.implicitHeight + topPadding + bottomPadding)

    background: Rectangle {
        id: surface
        anchors.fill: parent
        radius: Tokens.shape.small
        // Two steps of the same neutral, so an inactive tile is still a tile and
        // an active one is simply nearer. Under MD3 the border tokens are 0 and
        // this is the whole story; a pack that still wants an edge sets one.
        color: Qt.alpha(Theme.onSurface, root.enabled && root.active ? Tokens.stateLayer.draggedOpacity
                                                     : Tokens.stateLayer.hoverOpacity * 0.7)
        border.width: Tokens.border.width
        border.color: border.width > 0
            ? Qt.alpha(Theme.onSurface, Tokens.border.restAlpha)
            : "transparent"

        Behavior on color {
            MotionColorAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }

        StateLayer {
            target: surface
            hovered: root.enabled && root.hovered
            pressed: root.enabled && root.down
            focused: root.visualFocus
        }

    }

    contentItem: RowLayout {
        id: row
        spacing: Tokens.spacing.small

        // The state mark. An icon says WHAT the tile is; this says whether it
        // is on, and it is the only accent on the control.
        MaterialIndicator {
            Layout.alignment: Qt.AlignVCenter
            visible: root.showStateIndicator
            size: "extraSmall"
            colorRole: root.active ? "primary" : "outline"
            animated: true
        }

        MaterialIcon {
            iconName: root.iconName
            visible: root.iconName !== ""
            fontSize: Tokens.iconSize.medium
            backgroundColor: "transparent"
            iconColor: root.active ? Theme.onSurface : Theme.onSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showLabel && (root.label !== "" || root.supportingText !== "")
            spacing: Tokens.spacing.extraSmall
            MaterialText {
                Layout.fillWidth: true
                visible: root.label !== ""
                text: root.label
                textStyle: "labelMedium"
                colorRole: root.active ? "onSurface" : "onSurfaceVariant"
                elide: Text.ElideRight
            }
            MaterialText {
                Layout.fillWidth: true
                visible: root.supportingText !== ""
                text: root.supportingText
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
            }
        }
        MaterialIcon {
            visible: root.trailingIcon !== ""
            iconName: root.trailingIcon
            fontSize: Tokens.iconSize.small
            iconColor: Theme.onSurfaceVariant
            backgroundColor: "transparent"
        }
    }
}
