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
    property string leadingImageSource: ""
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

    // Mouse area — z:0, sits UNDER content so trailing/leading interactive elements receive clicks
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 0
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    // State layer
    StateLayer {
        visible: root.showStateLayer && root.clickable
        layerColor: Theme.onSurface
        hovered: mouseArea.containsMouse
        pressed: mouseArea.pressed
    }

    // Content
    RowLayout {
        z: 1
        anchors.fill: parent
        anchors.leftMargin: parent.margin
        anchors.rightMargin: parent.margin
        spacing: parent.margin

        // Leading element slot
        // Inline children: MaterialIcon + Image (2 items).
        // External leadingContent adds more, so hide defaults when children > 2.
        Item {
            id: leadingSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            visible: children.length > 2 || root.leadingIcon !== "" || root.leadingImageSource !== ""

            // Default leading icon (Material icon font glyph)
            MaterialIcon {
                visible: root.leadingIcon !== "" && root.leadingImageSource === "" && leadingSlot.children.length <= 2
                iconName: root.leadingIcon
                fontSize: Tokens.iconSize.large
                iconColor: root.leadingIconColor
                backgroundColor: "transparent"
            }

            // Image-based leading icon (freedesktop theme icons via Quickshell.iconPath)
            Image {
                visible: root.leadingImageSource !== "" && leadingSlot.children.length <= 2
                source: root.leadingImageSource
                sourceSize.width: Tokens.iconSize.large
                sourceSize.height: Tokens.iconSize.large
                width: Tokens.iconSize.large
                height: Tokens.iconSize.large
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
        // Inline children: MaterialIcon (1 item).
        // External trailingContent adds more, so hide default when children > 1.
        Item {
            id: trailingSlot
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
            visible: children.length > 1 || root.trailingIcon !== ""

            // Default trailing icon if specified
            MaterialIcon {
                visible: root.trailingIcon !== "" && trailingSlot.children.length <= 1
                iconName: root.trailingIcon
                fontSize: Tokens.iconSize.large
                iconColor: root.trailingIconColor
                backgroundColor: "transparent"
            }
        }
    }
}
