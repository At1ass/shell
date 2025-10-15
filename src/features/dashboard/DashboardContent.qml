import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components

Item {
    id: root

    // Сигнал для изменения высоты окна
    signal requestHeightChange(int newHeight)

    MaterialCard {
        anchors.fill: parent
        color: Config.colors.surfaceContainer
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
                            {icon: "dashboard", label: "Main"},
                            {icon: "music_note", label: "Media"},
                            {icon: "calendar_month", label: "Calendar"},
                            {icon: "volume_up", label: "Audio"}
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
                        root.requestHeightChange(640)
                    } else if (currentIndex === 1) {
                        root.requestHeightChange(600)
                    } else if (currentIndex === 2) {
                        root.requestHeightChange(600)
                    } else if (currentIndex === 3) {
                        root.requestHeightChange(700)
                    }
                }

                MainTab {}
                MediaTab {}
                CalendarTab {}
                AudioTab {}
            }
        }
    }
}
