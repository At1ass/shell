pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components
import qs.src.features.dashboard.tabs

Item {
    id: root
    focus: true

    // Active tab's modal state: while a dialog is up, dashboard-level keys
    // must not switch tabs or close the panel (Escape used to bypass the
    // EventDialog dirty-discard prompt and nuke the whole dashboard).
    readonly property var _tabLoaders: [quickLoader, weatherLoader, calendarLoader, audioLoader, networkLoader]
    readonly property bool _modalOpen: (_tabLoaders[tabView.currentIndex]?.item?.modalOpen) ?? false
    function _closeTopModal() {
        const item = _tabLoaders[tabView.currentIndex]?.item
        if (item && item.closeTopModal) item.closeTopModal()
    }

    // ═══════════════════════════════════════════════════════════════
    // KEYBOARD NAVIGATION
    // ═══════════════════════════════════════════════════════════════
    // The active tab lives in GlobalStates.dashboardOpenIndex — the ONLY
    // writable source. tabView.currentIndex stays a pure binding to it, so
    // openDashboardTab()/IPC keep working after manual tab switches
    // (imperative writes to currentIndex would sever the binding).

    Keys.onTabPressed: (event) => {
        if (root._modalOpen) { event.accepted = true; return }
        GlobalStates.dashboardOpenIndex = (GlobalStates.dashboardOpenIndex + 1) % 5
        event.accepted = true
    }

    Keys.onBacktabPressed: (event) => {
        if (root._modalOpen) { event.accepted = true; return }
        GlobalStates.dashboardOpenIndex = (GlobalStates.dashboardOpenIndex + 4) % 5
        event.accepted = true
    }

    Keys.onPressed: (event) => {
        // Physical key, not the layout's symbol — the H/L tab switch, the 1-5
        // jump and the whole calendar vi set below were dead on a Cyrillic
        // layout. See Keycodes.
        const key = Keycodes.key(event)

        // Escape: an open modal consumes it (dirty-guard prompt included);
        // otherwise it closes the dashboard.
        if (key === Qt.Key_Escape) {
            if (root._modalOpen) root._closeTopModal()
            else GlobalStates.closePanel("dashboard")
            event.accepted = true
            return
        }

        // Every other dashboard-level key is inert while a modal is up.
        if (root._modalOpen) return

        // Direct tab jump (keys 1-5)
        if (key >= Qt.Key_1 && key <= Qt.Key_5) {
            GlobalStates.dashboardOpenIndex = key - Qt.Key_1
            event.accepted = true
            return
        }

        // Space — media play/pause (any tab)
        if (key === Qt.Key_Space) {
            if (typeof MprisController !== "undefined" && MprisController.canTogglePlaying) {
                MprisController.togglePlaying()
                event.accepted = true
            }
            return
        }

        // Vi-like tab switching: H/L (no modifiers) when NOT on calendar tab
        if (tabView.currentIndex !== 2 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            if (key === Qt.Key_H || key === Qt.Key_Left) {
                GlobalStates.dashboardOpenIndex = Math.max(0, tabView.currentIndex - 1)
                event.accepted = true
                return
            }
            if (key === Qt.Key_L || key === Qt.Key_Right) {
                GlobalStates.dashboardOpenIndex = Math.min(4, tabView.currentIndex + 1)
                event.accepted = true
                return
            }
        }

        // Route to active tab
        if (tabView.currentIndex === 2) _handleCalendarKey(event)
    }

    function _handleCalendarKey(event) {
        const cal = calendarLoader.item as CalendarTab
        if (!cal) return
        const shift = !!(event.modifiers & Qt.ShiftModifier)
        const key = Keycodes.key(event)

        // Shift+key: month nav / jump to last
        if (shift) {
            if (key === Qt.Key_H) { cal.goToPrevMonth(); event.accepted = true }
            else if (key === Qt.Key_L) { cal.goToNextMonth(); event.accepted = true }
            else if (key === Qt.Key_G) { cal.goToLastDay(); event.accepted = true }
            return
        }

        switch (key) {
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

            // N = new event
            case Qt.Key_N:       cal.openNewEvent(); event.accepted = true; break
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
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 92

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: 0

                    Repeater {
                        model: [
                            { icon: "dashboard",         label: "Quick" },
                            { icon: "partly_cloudy_day", label: "Weather" },
                            { icon: "calendar_month",    label: "Calendar" },
                            { icon: "graphic_eq",        label: "Audio" },
                            { icon: "wifi",              label: "Network" }
                        ]

                        delegate: DashboardTabButton {
                            id: tabButton
                            // Declared HERE rather than on DashboardTabButton:
                            // the component is a plain button and should not
                            // carry model roles just to be used in a Repeater.
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            isActive: tabView.currentIndex === tabButton.index
                            nameIcon: tabButton.modelData.icon
                            label: tabButton.modelData.label
                            onClicked: GlobalStates.dashboardOpenIndex = tabButton.index
                        }
                    }
                }
            }

            // Divider
            Divider {
                Layout.fillWidth: true
            }

            // ===== TAB CONTENT =====
            // StackLayout here is a pure positioner: each tab sits behind a
            // Loader gated on the current index, so only ONE tab is alive at
            // a time (the §10.14 ban targets eager all-tabs instantiation).
            StackLayout {
                id: tabView
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: GlobalStates.dashboardOpenIndex

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
                    id: audioLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 3
                    sourceComponent: Component { AudioTab {} }
                }
                Loader {
                    id: networkLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: tabView.currentIndex === 4
                    sourceComponent: Component { NetworkTab {} }
                }
            }
        }
    }
}
