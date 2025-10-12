import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.base
import qs.src.features.statusbar
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

        ClockElement {
            Layout.row: 0
            Layout.column: 0
            Layout.rowSpan: 3
            Layout.columnSpan: 1
            Layout.fillHeight: true
            Layout.preferredWidth: 80
        }

        // ===== ROW 0, COL 1-4: USER INFO =====
        UserInfoElement {
            Layout.row: 0
            Layout.column: 1
            Layout.columnSpan: 4
            Layout.rowSpan: 2
            Layout.preferredWidth: 400
            Layout.fillHeight: true
        }

        // ===== ROW 0-1, COL 5: WEATHER (вертикальная) =====
        WeatherElement {
            Layout.row: 0
            Layout.column: 5
            Layout.rowSpan: 2
            Layout.columnSpan: 3
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        // ===== ROW 0-1, COL 6-8: СЛАЙДЕРЫ (вертикальные) =====
        // Brightness slider
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

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                MaterialIcon {
                    iconName:  "brightness_6"
                    iconColor: Config.colors.primary
                    fontSize: Config.typography.titleLarge.size
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
            Layout.column: 9
            Layout.rowSpan: 3
            Layout.columnSpan: 1
            Layout.preferredWidth: 70
            Layout.fillHeight: true
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                MaterialIcon {
                    iconName:  "volume_up"
                    iconColor: Config.colors.primary
                    fontSize: Config.typography.titleLarge.size
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

        // ===== ROW 2, COL 1-7: SYSTEM MONITORING (circular progress) =====
        SystemMonitoringElement {
            Layout.row: 2
            Layout.column: 1
            Layout.rowSpan: 1
            Layout.columnSpan: 7
            Layout.fillWidth: true
            Layout.preferredHeight:90
        }

        // ===== ROW 2, COL 0-5: MEDIA PLAYER =====
        MediaPlayerElement {
            Layout.row: 3
            Layout.column: 0
            Layout.rowSpan: 2
            Layout.columnSpan: 3
            Layout.fillHeight: true
            Layout.preferredWidth: 400
        }

        // ===== ROW 2, COL 6-8: SCHEDULE =====
        SheduleElement {
            Layout.row: 3
            Layout.column: 3
            // Layout.column: 6
            Layout.rowSpan: 3
            Layout.columnSpan: 3
            Layout.preferredWidth: 200
            // Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ===== ROW 3, COL 6-9: AUDIO VISUALIZER (CAVA) =====
        CavaElement {
            Layout.row: 3
            Layout.column: 6
            Layout.columnSpan: 4
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            Layout.preferredWidth: 220
        }

        // ===== ROW 3, COL 4-8: QUICK ACTIONS =====
        QuickActionsElement {
            Layout.row: 4
            Layout.column: 6
            Layout.columnSpan: 4
            Layout.rowSpan: 2
            Layout.preferredHeight: 100
            Layout.fillWidth: true
        }

        // ===== ROW 4, COL 0-8: SYSTEM TRAY =====
        SystemTrayElement {
            id: trayItem
            Layout.row: 5
            Layout.column: 0
            Layout.rowSpan: 1
            Layout.columnSpan: 3
            Layout.preferredHeight: 50
            Layout.preferredWidth: 400
            trayTooltip: trayTooltip
            trayMenu: trayMenu
        }
    }

    TrayMenuOverlay {
        id: trayMenu
    }

    TrayTooltip {
        id: trayTooltip
    }
}
