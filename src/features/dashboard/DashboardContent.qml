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
    focus: true

    // Сигнал для изменения высоты окна
    signal requestHeightChange(int newHeight)

    // ═══════════════════════════════════════════════════════════════
    // KEYBOARD NAVIGATION
    // ═══════════════════════════════════════════════════════════════

    Keys.onTabPressed: (event) => {
        tabView.currentIndex = (tabView.currentIndex + 1) % 4
        event.accepted = true
    }

    Keys.onBacktabPressed: (event) => {
        tabView.currentIndex = (tabView.currentIndex + 3) % 4
        event.accepted = true
    }

    Keys.onPressed: (event) => {
        // Direct tab jump (1-4)
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            tabView.currentIndex = event.key - Qt.Key_1
            event.accepted = true
            return
        }

        // Escape closes dashboard
        if (event.key === Qt.Key_Escape) {
            GlobalStates.dashboardOpen = false
            event.accepted = true
            return
        }

        // Space — media play/pause (any tab)
        if (event.key === Qt.Key_Space) {
            if (typeof MprisController !== "undefined" && MprisController.canTogglePlaying) {
                MprisController.togglePlaying()
                event.accepted = true
            }
            return
        }

        // Vi-like tab switching: H/L (shifted) when NOT on calendar tab
        if (tabView.currentIndex !== 2) {
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                tabView.currentIndex = Math.max(0, tabView.currentIndex - 1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                tabView.currentIndex = Math.min(3, tabView.currentIndex + 1)
                event.accepted = true
                return
            }
        }

        // Route to active tab
        if (tabView.currentIndex === 2) _handleCalendarKey(event)
    }

    function _handleCalendarKey(event) {
        const cal = calendarLoader.item
        if (!cal) return
        const shift = !!(event.modifiers & Qt.ShiftModifier)

        // Shift+key: month nav / jump to last
        if (shift) {
            if (event.key === Qt.Key_H) { cal.goToPrevMonth(); event.accepted = true }
            else if (event.key === Qt.Key_L) { cal.goToNextMonth(); event.accepted = true }
            else if (event.key === Qt.Key_G) { cal.goToLastDay(); event.accepted = true }
            return
        }

        switch (event.key) {
            // Arrows + vi h/j/k/l
            case Qt.Key_Left:
            case Qt.Key_H:       cal.moveFocusBy(-1); event.accepted = true; break
            case Qt.Key_Right:
            case Qt.Key_L:       cal.moveFocusBy(1); event.accepted = true; break
            case Qt.Key_Up:
            case Qt.Key_K:       cal.moveFocusBy(-7); event.accepted = true; break
            case Qt.Key_Down:
            case Qt.Key_J:       cal.moveFocusBy(7); event.accepted = true; break

            case Qt.Key_Return:
            case Qt.Key_Enter:   cal.selectFocused(); event.accepted = true; break

            // Month navigation
            case Qt.Key_PageUp:  cal.goToPrevMonth(); event.accepted = true; break
            case Qt.Key_PageDown: cal.goToNextMonth(); event.accepted = true; break

            // First/last day
            case Qt.Key_Home:    cal.goToFirstDay(); event.accepted = true; break
            case Qt.Key_End:     cal.goToLastDay(); event.accepted = true; break

            // g = first day (G handled above with shift)
            case Qt.Key_G:       cal.goToFirstDay(); event.accepted = true; break
        }
    }

    MaterialCard {
        anchors.fill: parent
        color: Qt.alpha(Theme.surfaceContainer, 0.85)
        radius: Tokens.shape.large
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
                    anchors.margins: Tokens.spacing.medium
                    spacing: 0

                    Repeater {
                        model: [
                            {
                                icon: "dashboard",
                                label: "Quick"
                            },
                            {
                                icon: "partly_cloudy_day",
                                label: "Weather"
                            },
                            {
                                icon: "calendar_month",
                                label: "Calendar"
                            },
                            {
                                icon: "settings",
                                label: "System"
                            }
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

                onVisibleChanged: {
                    if (!visible) currentIndexChanged()
                }
                onCurrentIndexChanged: {
                    // Изменяем высоту окна в зависимости от вкладки
                    if (currentIndex === 0) {
                        root.requestHeightChange(AppConfig.dashboardHeight);       // QuickTab
                    } else if (currentIndex === 1) {
                        root.requestHeightChange(AppConfig.dashboardHeight + 20);  // WeatherTab
                    } else if (currentIndex === 2) {
                        root.requestHeightChange(AppConfig.dashboardHeight - 40);  // CalendarTab
                    } else if (currentIndex === 3) {
                        root.requestHeightChange(AppConfig.dashboardHeight + 100);  // SystemTab
                    }
                }

                Loader {
                    id: quickLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 0
                    sourceComponent: Component { QuickTab {} }
                }
                Loader {
                    id: weatherLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 1
                    sourceComponent: Component { WeatherTab {} }
                }
                Loader {
                    id: calendarLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 2
                    sourceComponent: Component { CalendarTab {} }
                }
                Loader {
                    id: systemLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 3
                    sourceComponent: Component { SystemTab {} }
                }
            }
        }
    }
}
