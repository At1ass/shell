import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components
import qs.src.features.dashboard.tabs

Item {
    id: root

    // Сигнал для изменения высоты окна
    signal requestHeightChange(int newHeight)

    MaterialCard {
        anchors.fill: parent
        color: Qt.alpha(Config.colors.surfaceContainer, 0.85)
        radius: Config.shape.large
        outlined: false

        ColumnLayout {
            anchors.fill: parent
            // Layout.fillWidth: true
            spacing: 0

            // ===== TAB BAR =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: 0

                    Repeater {
                        model: [
                            {icon: "dashboard", label: "Quick"},
                            {icon: "partly_cloudy_day", label: "Weather"},
                            {icon: "calendar_month", label: "Calendar"},
                            {icon: "settings", label: "System"}
                        ]

                        delegate: TabButton {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            isActive: tabView.currentIndex === index
                            nameIcon: modelData.icon
                            label: modelData.label
                            onClicked: tabView.currentIndex = index
                        }
                    }
                }
            }

            // Разделитель
            Divider {
                Layout.fillWidth: true
            }

            // ===== TAB CONTENT =====
            StackLayout {
                id: tabView
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: GlobalStates.dashboardOpenIndex

                onCurrentIndexChanged: {
                    // Изменяем высоту окна в зависимости от вкладки
                    if (currentIndex === 0) {
                        root.requestHeightChange(640)  // QuickTab
                    } else if (currentIndex === 1) {
                        root.requestHeightChange(660)  // WeatherTab
                    } else if (currentIndex === 2) {
                        root.requestHeightChange(600)  // CalendarTab
                    } else if (currentIndex === 3) {
                        root.requestHeightChange(700)  // SystemTab
                    }
                }

                QuickTab {}
                WeatherTab {}
                CalendarTab {}
                SystemTab {}
            }
        }
    }
}
