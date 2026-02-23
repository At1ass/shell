import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.maintab_elements
import qs.src.features.dashboard.components.audiotab_elements

Item {
    GridLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        columns: 5
        rows: 4
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        UserInfoElement {
            Layout.row: 0
            Layout.column: 1
            Layout.columnSpan: 1
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        MediaPlayer {
            Layout.row: 1
            Layout.column: 0
            Layout.rowSpan: 2
            Layout.columnSpan: 2
            Layout.preferredWidth: 400
            Layout.preferredHeight: 250
            Layout.fillWidth: true
        }

        WeatherElement {
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 1
            Layout.columnSpan: 1
            Layout.fillHeight: true
            Layout.preferredWidth: 240
        }

        QuickActionsElement {
            Layout.row: 2
            Layout.column: 2
            Layout.columnSpan: 2
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        SystemMonitoringElement {
            Layout.row: 3
            Layout.column: 0
            Layout.rowSpan: 1
            Layout.columnSpan: 2
            Layout.preferredHeight: 100
            Layout.fillWidth: true
        }

        // Brightness slider
        MaterialCard {
            Layout.row: 0
            Layout.column: 2
            Layout.rowSpan: 2
            Layout.columnSpan: 1
            Layout.preferredWidth: 70
            Layout.fillHeight: true
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                MaterialIcon {
                    iconName: "brightness_6"
                    iconColor: Theme.primary
                    fontSize: Tokens.typography.headlineSmall.size
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                }

                MaterialSlider {
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    enabled: true
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: 0.8
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        // Volume slider
        MaterialCard {
            Layout.row: 0
            Layout.column: 3
            Layout.rowSpan: 2
            Layout.columnSpan: 1
            Layout.preferredWidth: 70
            Layout.fillHeight: true
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                MaterialIcon {
                    iconName: AudioService.masterMuted ? "volume_off" : "volume_up"
                    iconColor: Theme.onSurfaceVariant
                    fontSize: Tokens.typography.headlineSmall.size
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                    MouseArea {
                        anchors.fill: parent
                        onClicked: AudioService.toggleMasterMute()
                    }
                }

                MaterialSlider {
                    Layout.alignment: Qt.AlignHCenter
                    orientation: Qt.Vertical
                    enabled: AudioService.defaultSink !== null
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: AudioService.masterVolume
                    onMoved: AudioService.setMasterVolume(value)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
