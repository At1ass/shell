import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
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
        Repeater {
            model: [
                {
                    iconName: "brightness_6",
                    value: 100,
                    suffix: "",
                    col: 8
                },
                {
                    iconName: "volume_up",
                    value: 80,
                    suffix: "",
                    col: 9
                }
            ]

            delegate: MaterialCard {
                Layout.row: 0
                Layout.column: modelData.col
                Layout.rowSpan: 3
                Layout.columnSpan: 1
                Layout.preferredWidth: 70
                Layout.fillHeight: true
                color: Config.colors.surfaceContainerHigh
                radius: Config.shape.large

                ColumnLayout {
                    property real sliderValue: modelData.value
                    anchors.fill: parent
                    anchors.margins: Config.spacing.small
                    spacing: 4

                    MaterialIcon {
                        iconName: modelData.iconName
                        iconColor: Config.colors.primary
                        fontSize: Config.typography.titleLarge.size
                        backgroundColor: "transparent"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    MaterialText {
                        text: Math.round(parent.sliderValue).toString()
                        textStyle: "titleMedium"
                        colorRole: "onSurface"
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Vertical slider
                    Rectangle {
                        width: 6
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        radius: 3
                        color: Config.colors.surfaceContainerHighest

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 6
                            height: parent.height * (parent.parent.sliderValue / 100)
                            radius: 3
                            color: Config.colors.primary

                            Behavior on height {
                                NumberAnimation {
                                    duration: Config.motion.duration.short4
                                    easing.type: Config.motion.easing.emphasizedDecelerate
                                }
                            }
                        }
                    }

                    MaterialText {
                        text: modelData.suffix
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                        Layout.alignment: Qt.AlignHCenter
                        visible: modelData.suffix !== ""
                    }
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
            // Layout.fillWidth: true
            Layout.preferredWidth: 400
        }

        // ===== ROW 2, COL 6-8: SCHEDULE =====
        SheduleElement {
            Layout.row: 3
            Layout.column: 3
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
            Layout.row: 5
            Layout.column: 0
            Layout.rowSpan: 1
            Layout.columnSpan: 3
            Layout.preferredHeight: 50
            Layout.preferredWidth: 400
        }
    }
}
