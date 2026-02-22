import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Material Design 3 List Item
Rectangle {
    id: root

    // Content properties
    property string headline: ""
    property string supportingText: ""
    property string trailingSupportingText: ""

    // Leading element
    property alias leadingContent: leadingSlot.data
    property string leadingIcon: ""
    property color leadingIconColor: Theme.onSurfaceVariant

    // Trailing element
    property alias trailingContent: trailingSlot.data
    property string trailingIcon: ""
    property color trailingIconColor: Theme.onSurfaceVariant

    // Behavior
    property bool clickable: true
    property bool showStateLayer: true

    property real margin: Tokens.spacing.medium

    // Signals
    signal clicked()

    // MD3 List Item sizing
    implicitHeight: {
        if (supportingText !== "") return 72
        return 56
    }

    radius: Tokens.shape.none
    color: "transparent"

    // State layer
    StateLayer {
        visible: root.showStateLayer && root.clickable
        layerColor: Theme.onSurface
        hovered: mouseArea.containsMouse
        pressed: mouseArea.pressed
    }

    // Content
    RowLayout {
        anchors.fill: parent
        // anchors.leftMargin: Tokens.spacing.medium
        // anchors.rightMargin: Tokens.spacing.medium
        // spacing: Tokens.spacing.medium
        anchors.leftMargin: parent.margin
        anchors.rightMargin: parent.margin
        spacing: parent.margin

        // Leading element slot
        Item {
            id: leadingSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            visible: children.length > 0 || root.leadingIcon !== ""

            // Default leading icon if specified
            MaterialIcon {
                visible: root.leadingIcon !== "" && leadingSlot.children.length === 0
                iconName: root.leadingIcon
                fontSize: Tokens.iconSize.large
                iconColor: root.leadingIconColor
                backgroundColor: "transparent"
            }
        }

        // Text content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            MaterialText {
                visible: root.headline !== ""
                text: root.headline
                textStyle: "bodyLarge"
                colorRole: "onSurface"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            MaterialText {
                visible: root.supportingText !== ""
                text: root.supportingText
                textStyle: "bodyMedium"
                colorRole: "onSurfaceVariant"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        // Trailing supporting text
        MaterialText {
            visible: root.trailingSupportingText !== ""
            text: root.trailingSupportingText
            textStyle: "labelSmall"
            colorRole: "onSurfaceVariant"
            Layout.alignment: Qt.AlignVCenter
        }

        // Trailing element slot
        Item {
            id: trailingSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
            visible: children.length > 0 || root.trailingIcon !== ""

            // Default trailing icon if specified
            MaterialIcon {
                visible: root.trailingIcon !== "" && trailingSlot.children.length === 0
                iconName: root.trailingIcon
                fontSize: Tokens.iconSize.large
                iconColor: root.trailingIconColor
                backgroundColor: "transparent"
            }
        }
    }

    // Mouse area for interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
