import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

Item {
    id: root

    readonly property var sinkNodes: AudioService.sinkNodes
    readonly property var sourceNodes: AudioService.sourceNodes
    readonly property var streamNodes: AudioService.streamNodes

    readonly property var defaultSink: AudioService.defaultSink
    readonly property var defaultSource: AudioService.defaultSource

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.large

        // Выбор устройств (MD3)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            // Устройство вывода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sinkMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sinkMouseArea.containsMouse ? Theme.onSecondaryContainer : Theme.primaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "volume_up"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: sinkMouseArea.containsMouse ? Theme.secondaryContainer : Theme.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: "Output Device"
                            textStyle: "labelLarge"
                            colorRole: "onSurfaceVariant"
                            font.weight: Font.Medium
                        }

                        MaterialText {
                            text: AudioService.defaultSink ? (AudioService.defaultSink.description || AudioService.defaultSink.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Tokens.typography.headlineSmall.size
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sinkMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sinkDialog.openDialog(AudioService.sinkNodes, AudioService.defaultSink, "Select Output Device", "output")
                    }
                }
            }

            // Устройство ввода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sourceMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sourceMouseArea.containsMouse ? Theme.onSecondaryContainer : Theme.tertiaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "mic"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: sourceMouseArea.containsMouse ? Theme.secondaryContainer : Theme.onTertiaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: "Input Device"
                            textStyle: "labelLarge"
                            colorRole: "onSurfaceVariant"
                            font.weight: Font.Medium
                        }

                        MaterialText {
                            text: AudioService.defaultSource ? (AudioService.defaultSource.description || AudioService.defaultSource.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Tokens.typography.headlineSmall.size
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sourceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sourceDialog.openDialog(AudioService.sourceNodes, AudioService.defaultSource, "Select Input Device", "input")
                    }
                }
            }
        }

        // Микшер приложений
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
                spacing: Tokens.spacing.medium

                // Header (MD3)
                SectionHeader {
                    Layout.fillWidth: true
                    title: "Application Volume Mixer"
                    icon: "graphic_eq"
                    badgeText: AudioService.streamNodes.length > 0 ? AudioService.streamNodes.length.toString() : ""
                }

                // ScrollView для списка приложений
                ScrollableList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.medium

                        Repeater {
                            // ScriptModel для эффективного обновления (без пересоздания делегатов)
                            model: ScriptModel {
                                values: AudioService.streamNodes
                            }

                            delegate: MaterialCard {
                                required property var modelData
                                property var stream: modelData
                                property string appIcon: AudioService.getAppIcon(stream)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                color: Theme.surfaceContainer
                                radius: Tokens.shape.medium

                                data: [
                                    PwObjectTracker {
                                        objects: stream ? [stream] : []
                                    }
                                ]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.spacing.medium
                                    spacing: Tokens.spacing.medium

                                    // App icon (real or fallback)
                                    CircleAvatar {
                                        size: "large"
                                        imageSource: appIcon
                                        fallbackText: stream && stream.properties && stream.properties["application.name"] ?
                                                     stream.properties["application.name"] : "AP"
                                        customRadius: 8
                                    }

                                    // Name and slider
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        // Application name
                                        MaterialText {
                                            text: stream && stream.properties && stream.properties["application.name"] ?
                                                  stream.properties["application.name"] :
                                                  (stream.appName || stream.name || stream.clientName || "Application")
                                            textStyle: "titleSmall"
                                            colorRole: "onSurface"
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Media name (tab title, etc.)
                                        MaterialText {
                                            property string mediaName: stream && stream.properties && stream.properties["media.name"] ? stream.properties["media.name"] : ""
                                            visible: mediaName !== ""
                                            text: mediaName
                                            textStyle: "bodySmall"
                                            colorRole: "onSurfaceVariant"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        MaterialSlider {
                                            Layout.fillWidth: true
                                            Layout.topMargin: Tokens.spacing.extraSmall
                                            enabled: !!(stream && stream.audio)
                                            from: 0
                                            to: 1
                                            stepSize: 0.01
                                            value: (stream && stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                            onMoved: if (stream && stream.audio)
                                                stream.audio.volume = value
                                        }
                                    }

                                    // Volume percentage
                                    MaterialText {
                                        text: AudioService.formatVolume(stream && stream.audio ? stream.audio.volume : null) + "%"
                                        textStyle: "labelLarge"
                                        colorRole: "onSurfaceVariant"
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 48
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    IconButton {
                                        iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                        iconSize: Tokens.typography.titleLarge.size
                                        iconColor: (stream && stream.audio && stream.audio.muted) ?
                                                  Theme.onErrorContainer : Theme.onSurfaceVariant
                                        containerSize: 48
                                        variant: "standard"
                                        enabled: !!(stream && stream.audio)
                                        onClicked: if (stream && stream.audio)
                                            stream.audio.muted = !stream.audio.muted
                                    }
                                }
                            }
                        }

                    // Empty state (MD3)
                    EmptyState {
                        visible: AudioService.streamNodes.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 240

                        iconName: "music_off"
                        title: "No active audio streams"
                        subtitle: "Play something to see it here"
                    }
                }

                // Кнопка pavucontrol (MD3 Filled Button)
                MaterialCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Tokens.shape.full
                    color: pavuMouseArea.pressed ? Theme.primary :
                           pavuMouseArea.containsMouse ? Qt.lighter(Theme.primaryContainer, 1.1) :
                           Theme.primaryContainer

                    // M3 Filled Button - без outline
                    outlined: false

                    // M3 elevation через surface tint (вместо DropShadow)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: Theme.primary
                        opacity: pavuMouseArea.containsMouse ? 0.08 : 0.03
                        z: -1
                        visible: !pavuMouseArea.pressed

                        Behavior on opacity {
                            NumberAnimation { duration: Tokens.motion.duration.short4 }
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: "tune"
                            fontSize: Tokens.typography.titleLarge.size
                            iconColor: pavuMouseArea.pressed ? Theme.onPrimary : Theme.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }
                        }

                        MaterialText {
                            text: "Advanced Audio Settings"
                            textStyle: "labelLarge"
                            colorRole: pavuMouseArea.pressed ? "onPrimary" : "onPrimaryContainer"
                            font.weight: Font.Medium
                        }
                    }

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        // radius: parent.radius
                        radius: Tokens.shape.full
                        color: Theme.onPrimaryContainer
                        opacity: pavuMouseArea.pressed ? 0.12 : (pavuMouseArea.containsMouse ? 0.08 : 0)

                        Behavior on opacity {
                            NumberAnimation { duration: Tokens.motion.duration.short4 }
                        }
                    }

                    MouseArea {
                        id: pavuMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Launch pavucontrol
                            Qt.openUrlExternally("pavucontrol")
                        }
                    }
                }
            }
        }
    }

    // Device Selection Dialogs
    DeviceSelectionDialog {
        id: sinkDialog
        anchors.fill: parent

        onDeviceSelected: (device) => {
            AudioService.setDefaultSink(device)
        }
    }

    DeviceSelectionDialog {
        id: sourceDialog
        anchors.fill: parent

        onDeviceSelected: (device) => {
            AudioService.setDefaultSource(device)
        }
    }
}
