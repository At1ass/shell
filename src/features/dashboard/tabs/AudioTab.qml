import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.features.dashboard.components

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // Device selection row
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // Output device
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sinkMouse.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Tokens.shape.full
                        color: sinkMouse.containsMouse ? Theme.onSecondaryContainer : Theme.primaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "volume_up"
                            fontSize: Tokens.iconSize.medium
                            iconColor: sinkMouse.containsMouse ? Theme.secondaryContainer : Theme.onPrimaryContainer
                            backgroundColor: "transparent"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MaterialText {
                            text: "Output"
                            textStyle: "labelSmall"
                            colorRole: "onSurfaceVariant"
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
                        fontSize: Tokens.iconSize.medium
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sinkDialog.openDialog(AudioService.sinkNodes, AudioService.defaultSink, "Select Output Device", "output")
                }
            }

            // Input device
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sourceMouse.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                radius: Tokens.shape.large

                Behavior on color {
                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Tokens.shape.full
                        color: sourceMouse.containsMouse ? Theme.onSecondaryContainer : Theme.tertiaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "mic"
                            fontSize: Tokens.iconSize.medium
                            iconColor: sourceMouse.containsMouse ? Theme.secondaryContainer : Theme.onTertiaryContainer
                            backgroundColor: "transparent"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        MaterialText {
                            text: "Input"
                            textStyle: "labelSmall"
                            colorRole: "onSurfaceVariant"
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
                        fontSize: Tokens.iconSize.medium
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sourceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sourceDialog.openDialog(AudioService.sourceNodes, AudioService.defaultSource, "Select Input Device", "input")
                }
            }
        }

        // Volume Mixer
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
                    title: "Volume Mixer"
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
                            Layout.preferredHeight: {
                                const hasMedia = stream && stream.properties &&
                                    stream.properties["media.name"] &&
                                    stream.properties["media.name"] !== (stream.properties["application.name"] || "")
                                return hasMedia ? 100 : 80
                            }
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
                                    fallbackText: stream && stream.properties && stream.properties["application.name"] ? stream.properties["application.name"] : "AP"
                                    customRadius: 6
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            MaterialText {
                                                text: stream && stream.properties && stream.properties["application.name"] ? stream.properties["application.name"] : (stream.appName || stream.name || stream.clientName || "Application")
                                                textStyle: "labelLarge"
                                                colorRole: "onSurface"
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            MaterialText {
                                                readonly property string mediaName: stream && stream.properties ? (stream.properties["media.name"] || "") : ""
                                                text: mediaName
                                                textStyle: "labelSmall"
                                                colorRole: "onSurfaceVariant"
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                visible: mediaName.length > 0 && mediaName !== (stream.properties["application.name"] || "")
                                            }
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

                                IconButton {
                                    iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                    iconSize: Tokens.typography.headlineSmall.size
                                    iconColor: (stream && stream.audio && stream.audio.muted) ? Theme.onErrorContainer : Theme.onSurfaceVariant
                                    variant: "standard"
                                    enabled: !!(stream && stream.audio)
                                    onClicked: if (stream && stream.audio)
                                        stream.audio.muted = !stream.audio.muted
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

    // Device selection dialogs
    DeviceSelectionDialog {
        id: sinkDialog
        anchors.fill: parent
        onDeviceSelected: device => AudioService.setDefaultSink(device)
    }

    DeviceSelectionDialog {
        id: sourceDialog
        anchors.fill: parent
        onDeviceSelected: device => AudioService.setDefaultSource(device)
    }
}
