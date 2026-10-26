pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

MaterialCard {
    id: root
    property PwNode stream: null
    readonly property string appName: root.stream?.properties["application.name"] || root.stream?.name || "Application"
    readonly property string mediaName: root.stream?.properties["media.name"] || ""
    implicitHeight: row.implicitHeight + Tokens.spacing.small * 2
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.small
    data: PwObjectTracker { objects: root.stream ? [root.stream] : [] }
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        spacing: Tokens.spacing.small
        CircleAvatar {
            size: "small"
            imageSource: root.stream ? AudioService.getAppIcon(root.stream) : ""
            fallbackText: root.appName
            customRadius: Tokens.shape.small
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            RowLayout {
                Layout.fillWidth: true
                MaterialText {
                    Layout.fillWidth: true
                    text: root.appName
                    textStyle: "labelLarge"
                    elide: Text.ElideRight
                }
                MaterialText {
                    text: Math.round((root.stream?.audio?.volume ?? 0) * 100) + "%"
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                }
            }
            MaterialText {
                Layout.fillWidth: true
                visible: text !== "" && text !== root.appName
                text: root.mediaName
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
            }
            MaterialSlider {
                Layout.fillWidth: true
                enabled: !!root.stream?.audio
                from: 0; to: 1; stepSize: 0.01
                value: root.stream?.audio?.volume ?? 0
                Accessible.name: root.appName + " volume"
                onMoved: AudioService.setStreamVolume(root.stream, value)
            }
        }
        IconButton {
            enabled: !!root.stream?.audio
            iconName: root.stream?.audio?.muted ? "volume_off" : "volume_up"
            iconSize: Tokens.iconSize.medium
            Accessible.name: (root.stream?.audio?.muted ? "Unmute " : "Mute ") + root.appName
            onClicked: AudioService.toggleStreamMute(root.stream)
        }
    }
}
