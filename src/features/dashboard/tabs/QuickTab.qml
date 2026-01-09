import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.maintab_elements

Item {
    GridLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        columns: 4
        rows: 3
        columnSpacing: Config.spacing.small
        rowSpacing: Config.spacing.small

        // ===== ROW 0, COL 0-1: BRIGHTNESS SLIDER =====
        MaterialCard {
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 2
            Layout.columnSpan: 1
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                MaterialIcon {
                    iconName: "brightness_6"
                    iconColor: Config.colors.primary
                    fontSize: Config.typography.headlineSmall.size
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

        // ===== ROW 0, COL 1: VOLUME SLIDER =====
        MaterialCard {
            Layout.row: 0
            Layout.column: 1
            Layout.rowSpan: 2
            Layout.columnSpan: 1
            Layout.preferredWidth: 80
            Layout.fillHeight: true
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                MaterialIcon {
                    iconName: "volume_up"
                    iconColor: Config.colors.primary
                    fontSize: Config.typography.headlineSmall.size
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
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

        // ===== ROW 0-2, COL 2-3: QUICK ACTIONS =====
        QuickActionsElement {
            Layout.row: 0
            Layout.column: 2
            Layout.columnSpan: 2
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ===== ROW 2, COL 0-3: UPCOMING EVENTS =====
        SheduleElement {
            Layout.row: 2
            Layout.column: 0
            Layout.columnSpan: 4
            Layout.fillWidth: true
            Layout.preferredHeight: 200
        }
    }
}
