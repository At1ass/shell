import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Empty State
Item {
    id: root

    property string iconName: "info"
    property string title: "No data"
    property string subtitle: ""
    property int iconContainerSize: 80
    property int iconSize: 48

    // Publishes its own size. Without this it was a bare Item measuring 0x0 with
    // its content anchored to the centre of nothing: usable only where a caller
    // gave it explicit bounds, and silently zero for anyone trying to lay it
    // out, wrap it, or put a backdrop behind it.
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        // Icon container (MD3 spec: 64-80dp circle)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            // Layout.preferred*, not width/height — see QtQuick.Layouts docs.
            Layout.preferredWidth: root.iconContainerSize
            Layout.preferredHeight: root.iconContainerSize
            radius: root.iconContainerSize / 2
            color: Theme.surfaceContainerHighest

            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.iconName
                fontSize: root.iconSize
                iconColor: Theme.onSurfaceVariant
                backgroundColor: "transparent"
                // Placeholder art is deliberately recessive; the disabled-content
                // token is the scale the rest of the kit uses for that.
                opacity: Tokens.state.disabledContentOpacity
            }
        }

        MaterialText {
            visible: root.title !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            textStyle: "titleMedium"
            colorRole: "onSurface"
            font.weight: Font.Medium
        }

        MaterialText {
            visible: root.subtitle !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.subtitle
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
        }
    }
}
