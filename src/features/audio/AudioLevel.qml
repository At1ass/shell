pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

ColumnLayout {
    id: root
    property string title: "Output"
    property string deviceName: "No device"
    property string icon: "volume_up"
    property string mutedIcon: "volume_off"
    property real volume: 0
    property bool muted: false
    property bool available: false
    signal volumeRequested(real value)
    signal muteRequested()
    signal deviceRequested()
    function focusInitial() { muteButton.forceActiveFocus(Qt.TabFocusReason) }
    spacing: Tokens.spacing.extraSmall
    ListItem {
        Layout.fillWidth: true
        headline: root.title
        supportingText: root.deviceName
        leadingIcon: root.icon
        trailingIcon: "chevron_right"
        margin: Tokens.spacing.small
        radius: Tokens.shape.small
        onClicked: root.deviceRequested()
    }
    RowLayout {
        visible: root.available
        Layout.fillWidth: true
        spacing: Tokens.spacing.small
        IconButton {
            id: muteButton
            enabled: root.available
            iconName: root.muted ? root.mutedIcon : root.icon
            iconSize: Tokens.iconSize.medium
            iconColor: root.muted ? Theme.primary : Theme.onSurfaceVariant
            Accessible.name: (root.muted ? "Unmute " : "Mute ") + root.title
            onClicked: root.muteRequested()
        }
        MaterialSlider {
            Layout.fillWidth: true
            enabled: root.available
            Accessible.name: root.title + " volume"
            from: 0; to: 1; stepSize: 0.01
            value: root.volume
            onMoved: root.volumeRequested(value)
        }
        MaterialText {
            text: root.available ? Math.round(root.volume * 100) + "%" : "—"
            textStyle: "labelMedium"
            colorRole: "onSurfaceVariant"
            Layout.minimumWidth: percentage.advanceWidth
            horizontalAlignment: Text.AlignRight
        }
        TextMetrics {
            id: percentage
            text: "100%"
            font.family: Tokens.typography.fontFamily
            font.pixelSize: Tokens.typography.labelMedium.size
        }
    }
}
