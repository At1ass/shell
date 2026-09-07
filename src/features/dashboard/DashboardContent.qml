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

    // Extra height the ACTIVE tab is asking for right now -- a section it has
    // unfolded, say. The window is sized per tab from a fixed table, so without
    // this an expanding section has nowhere to grow and is simply clipped.
    readonly property int tabExtraHeight: (_tabLoaders[tabView.currentIndex]?.item?.extraHeight) ?? 0

    // A tab that measures itself, if it does. 0 means "use the fixed table".
    readonly property int tabContentHeight: (_tabLoaders[tabView.currentIndex]?.item?.contentHeight) ?? 0

    // Everything this component adds around a tab. A measuring tab reports only
    // its own content, so the window has to be told what sits above it.
    //
    // No divider under the header any more: the header IS the top of the panel
    // now, and a rule between it and the content only restated a boundary that
    // spacing already makes.
    readonly property int chromeHeight: root.headerHeight
    readonly property int headerHeight: clockText.implicitHeight + dateText.implicitHeight
                                        + Tokens.spacing.extraSmall
                                        + Tokens.panelPadding * 2
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
        color: Qt.alpha(Theme.surfaceContainer, AppConfig.panelOpacity)
        radius: Tokens.shape.large

        ColumnLayout {
            anchors.fill: parent
            // Layout.fillWidth: true
            spacing: 0

            // ===== HEADER: the hour, and where you are =====
            //
            // The clock earns the largest type in the panel and is the only
            // thing that does; everything below it sits in one narrow band of
            // sizes. That is the whole hierarchy -- one thing to land on, then
            // an even field. Navigation rides along the same line instead of
            // taking a storey of its own.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerHeight

                MonoText {
                    id: clockText
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.panelPadding
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.panelPadding
                    text: Qt.formatDateTime(DateTime.clock.date, "HH:mm")
                    textStyle: "headlineMedium"
                    colorRole: "onSurface"
                }

                MaterialText {
                    id: dateText
                    anchors.left: clockText.left
                    anchors.top: clockText.bottom
                    anchors.topMargin: Tokens.spacing.extraSmall
                    text: Qt.formatDateTime(DateTime.clock.date, "dddd, d MMMM")
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.panelPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.large

                    Repeater {
                        model: ["Quick", "Weather", "Calendar", "Audio", "Network"]

                        delegate: DashboardTabButton {
                            id: tabButton
                            // Declared HERE rather than on DashboardTabButton:
                            // the component is a plain button and should not
                            // carry model roles just to be used in a Repeater.
                            required property int index
                            required property string modelData

                            isActive: tabView.currentIndex === tabButton.index
                            label: tabButton.modelData
                            onClicked: GlobalStates.dashboardOpenIndex = tabButton.index
                        }
                    }
                }
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
