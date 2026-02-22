import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.maintab_elements
import qs.src.features.dashboard.components

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // ===== ROW 1: WEATHER & SYSTEM MONITORING =====
        // RowLayout {
        //     Layout.fillWidth: true
        //     Layout.preferredHeight: 140
        //     spacing: Tokens.spacing.medium
        //
        //     // Weather (detailed)
        //     WeatherElement {
        //         Layout.preferredWidth: 200
        //         Layout.fillHeight: true
        //     }
        //
        //     // System Monitor
        //     SystemMonitoringElement {
        //         Layout.fillWidth: true
        //         Layout.fillHeight: true
        //     }
        // }

        // ===== ROW 2+: AUDIO ADVANCED (from AudioTab) =====
        // Выбор устройств
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            // Устройство вывода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                color: sinkMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

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
                Layout.preferredHeight: 84
                color: sourceMouseArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

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

        // Микшер приложений (компактная версия)
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.medium
                spacing: Tokens.spacing.small

                SectionHeader {
                    Layout.fillWidth: true
                    title: "Application Volume Mixer"
                    icon: "graphic_eq"
                    badgeText: AudioService.streamNodes.length > 0 ? AudioService.streamNodes.length.toString() : ""
                }

                ScrollableList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: ScriptModel {
                            values: AudioService.streamNodes
                        }

                        delegate: MaterialCard {
                            required property var modelData
                            property var stream: modelData
                            property string appIcon: AudioService.getAppIcon(stream)

                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            color: Theme.surfaceContainer
                            radius: Tokens.shape.medium

                            data: [
                                PwObjectTracker {
                                    objects: stream ? [stream] : []
                                }
                            ]

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.spacing.small
                                spacing: Tokens.spacing.small

                                CircleAvatar {
                                    size: "medium"
                                    imageSource: appIcon
                                    fallbackText: stream && stream.properties && stream.properties["application.name"] ?
                                                 stream.properties["application.name"] : "AP"
                                    customRadius: 6
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        MaterialText {
                                            text: stream && stream.properties && stream.properties["application.name"] ?
                                            stream.properties["application.name"] :
                                            (stream.appName || stream.name || stream.clientName || "Application")
                                            textStyle: "labelLarge"
                                            colorRole: "onSurface"
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                        }
                                        MaterialText {
                                            text: AudioService.formatVolume(stream && stream.audio ? stream.audio.volume : null) + "%"
                                            textStyle: "labelMedium"
                                            colorRole: "onSurfaceVariant"
                                            font.weight: Font.Medium
                                            Layout.preferredWidth: 40
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }

                                    MaterialSlider {
                                        Layout.fillWidth: true
                                        enabled: !!(stream && stream.audio)
                                        from: 0
                                        to: 1
                                        stepSize: 0.01
                                        value: (stream && stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                        onMoved: if (stream && stream.audio)
                                            stream.audio.volume = value
                                    }
                                }

                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: (stream && stream.audio && stream.audio.muted) ?
                                           Theme.errorContainer :
                                           (muteMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent")

                                    Behavior on color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                        // fontSize: Tokens.typography.titleMedium.size
                                        fontSize: Tokens.typography.headlineSmall.size
                                        iconColor: (stream && stream.audio && stream.audio.muted) ?
                                                  Theme.onErrorContainer :
                                                  Theme.onSurfaceVariant
                                        backgroundColor: "transparent"

                                        Behavior on iconColor {
                                            ColorAnimation { duration: Tokens.motion.duration.short4 }
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

                    EmptyState {
                        visible: AudioService.streamNodes.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160

                        iconName: "music_off"
                        title: "No active audio streams"
                        subtitle: "Play something to see it here"
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
