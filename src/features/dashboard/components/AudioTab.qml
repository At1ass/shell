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
        anchors.margins: Config.spacing.large
        spacing: Config.spacing.large

        // Выбор устройств (MD3)
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            // Устройство вывода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sinkMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.surfaceContainerHigh
                radius: Config.shape.large

                Behavior on color {
                    ColorAnimation { duration: Config.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: Config.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sinkMouseArea.containsMouse ? Config.colors.onSecondaryContainer : Config.colors.primaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "volume_up"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: sinkMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
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
                        fontSize: Config.typography.headlineSmall.size
                        iconColor: Config.colors.onSurfaceVariant
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
                color: sourceMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.surfaceContainerHigh
                radius: Config.shape.large

                Behavior on color {
                    ColorAnimation { duration: Config.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: Config.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sourceMouseArea.containsMouse ? Config.colors.onSecondaryContainer : Config.colors.tertiaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "mic"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: sourceMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.onTertiaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
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
                        fontSize: Config.typography.headlineSmall.size
                        iconColor: Config.colors.onSurfaceVariant
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
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.large
                spacing: Config.spacing.medium

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
                    spacing: Config.spacing.medium

                        Repeater {
                            model: AudioService.streamNodes

                            delegate: MaterialCard {
                                required property var modelData
                                property var stream: modelData
                                property string appIcon: AudioService.getAppIcon(stream)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                color: Config.colors.surfaceContainer
                                radius: Config.shape.medium

                                data: [
                                    PwObjectTracker {
                                        objects: stream ? [stream] : []
                                    }
                                ]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Config.spacing.medium
                                    spacing: Config.spacing.medium

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
                                            Layout.topMargin: Config.spacing.extraSmall
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

                                    // Mute button (MD3 IconButton style)
                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: 24
                                        color: (stream && stream.audio && stream.audio.muted) ?
                                               Config.colors.errorContainer :
                                               (muteMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : "transparent")

                                        Behavior on color {
                                            ColorAnimation { duration: Config.motion.duration.short4 }
                                        }

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                            fontSize: Config.typography.titleLarge.size
                                            iconColor: (stream && stream.audio && stream.audio.muted) ?
                                                      Config.colors.onErrorContainer :
                                                      Config.colors.onSurfaceVariant
                                            backgroundColor: "transparent"

                                            Behavior on iconColor {
                                                ColorAnimation { duration: Config.motion.duration.short4 }
                                            }
                                        }

                                        MouseArea {
                                            id: muteMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !!(stream && stream.audio)
                                            onClicked: if (stream && stream.audio)
                                                stream.audio.muted = !stream.audio.muted
                                        }
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
                    radius: Config.shape.full
                    color: pavuMouseArea.pressed ? Config.colors.primary :
                           pavuMouseArea.containsMouse ? Qt.lighter(Config.colors.primaryContainer, 1.1) :
                           Config.colors.primaryContainer

                    // M3 Filled Button - без outline
                    outlined: false

                    // M3 elevation через surface tint (вместо DropShadow)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: Config.colors.primary
                        opacity: pavuMouseArea.containsMouse ? 0.08 : 0.03
                        z: -1
                        visible: !pavuMouseArea.pressed

                        Behavior on opacity {
                            NumberAnimation { duration: Config.motion.duration.short4 }
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "tune"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: pavuMouseArea.pressed ? Config.colors.onPrimary : Config.colors.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
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
                        radius: Config.shape.full
                        color: Config.colors.onPrimaryContainer
                        opacity: pavuMouseArea.pressed ? 0.12 : (pavuMouseArea.containsMouse ? 0.08 : 0)

                        Behavior on opacity {
                            NumberAnimation { duration: Config.motion.duration.short4 }
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
