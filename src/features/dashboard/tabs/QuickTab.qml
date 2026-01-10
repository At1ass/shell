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
        columns: 10
        rows: 6
        columnSpacing: Config.spacing.small
        rowSpacing: Config.spacing.small

        // ===== ROW 0, COL 0: CLOCK =====
        ClockElement {
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 3
            Layout.columnSpan: 1
            Layout.fillHeight: true
            Layout.preferredWidth: 80
        }

        // ===== ROW 0-1, COL 1-4: USER INFO =====
        UserInfoElement {
            Layout.row: 0
            Layout.column: 1
            Layout.columnSpan: 4
            Layout.rowSpan: 2
            Layout.preferredWidth: 400
            Layout.fillHeight: true
        }

        // ===== ROW 0-2, COL 5-7: QUICK ACTIONS =====
        QuickActionsElement {
            Layout.row: 0
            Layout.column: 5
            Layout.columnSpan: 3
            Layout.rowSpan: 3
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ===== ROW 0-2, COL 8: BRIGHTNESS SLIDER =====
        MaterialCard {
            Layout.row: 0
            Layout.column: 8
            Layout.rowSpan: 3
            Layout.columnSpan: 1
            Layout.preferredWidth: 70
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

        // ===== ROW 0-2, COL 9: VOLUME SLIDER =====
        MaterialCard {
            Layout.row: 0
            Layout.column: 9
            Layout.rowSpan: 3
            Layout.columnSpan: 1
            Layout.preferredWidth: 70
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

        // ===== ROW 3-4, COL 0-4: MEDIA PLAYER =====
        MediaPlayerElement {
            Layout.row: 3
            Layout.column: 0
            Layout.rowSpan: 2
            Layout.columnSpan: 5
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // ===== ROW 3-4, COL 5-9: UPCOMING EVENTS =====
        SheduleElement {
            Layout.row: 3
            Layout.column: 5
            Layout.rowSpan: 2
            Layout.columnSpan: 5
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
