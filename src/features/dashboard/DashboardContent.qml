pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.inputs
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.tabs

Item {
    id: root
    focus: true

    // Active tab's modal state: while a dialog is up, dashboard-level keys
    // must not switch tabs or close the panel (Escape used to bypass the
    // EventDialog dirty-discard prompt and nuke the whole dashboard).
    readonly property var _tabLoaders: [quickLoader, weatherLoader, calendarLoader]

    // Extra height the ACTIVE tab is asking for right now -- a section it has
    // unfolded, say. The window is sized per tab from a fixed table, so without
    // this an expanding section has nowhere to grow and is simply clipped.
    readonly property int tabExtraHeight: (_tabLoaders[tabView.currentIndex]?.item?.extraHeight) ?? 0

    // A replacement lazy tab briefly has no item or measured geometry. Keep
    // the previous target during that handover instead of resizing the window
    // to its configured fallback and then back to the new tab's height.
    readonly property int _rawTabContentHeight: (_tabLoaders[tabView.currentIndex]?.item?.contentHeight) ?? 0
    property int _lastMeasuredHeight: 0
    on_RawTabContentHeightChanged: if (_rawTabContentHeight > 0) _lastMeasuredHeight = _rawTabContentHeight
    readonly property int tabContentHeight: _rawTabContentHeight > 0 ? _rawTabContentHeight : _lastMeasuredHeight

    // Everything this component adds around a tab. A measuring tab reports only
    // its own content, so the window has to be told what sits above it.
    //
    // No divider under the header any more: the header IS the top of the panel
    // now, and a rule between it and the content only restated a boundary that
    // spacing already makes.
    readonly property int chromeHeight: root.headerHeight
    readonly property bool _stackedHeader: root.width < clockColumn.naturalWidth
        + tabBar.implicitWidth + Tokens.spacing.large + Tokens.panelPadding * 2
    readonly property int headerHeight: Math.max(clockColumn.implicitHeight,
        root._stackedHeader ? 0 : tabBar.implicitHeight)
        + (root._stackedHeader ? tabBar.implicitHeight + Tokens.spacing.small : 0)
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

    function _cycleTab(delta) {
        GlobalStates.dashboardOpenIndex = (GlobalStates.dashboardOpenIndex + delta + 3) % 3
        tabBar.forceActiveFocus(Qt.ShortcutFocusReason)
    }
    // Shortcut delivery precedes a child's Tab focus traversal. Bubbling Keys
    // handlers cannot guarantee Ctrl+Tab from buttons, sliders and text fields.
    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.WindowShortcut
        enabled: root.visible && GlobalStates.dashboardOpen && !root._modalOpen
        onActivated: root._cycleTab(1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        context: Qt.WindowShortcut
        enabled: root.visible && GlobalStates.dashboardOpen && !root._modalOpen
        onActivated: root._cycleTab(-1)
    }

    Keys.onPressed: (event) => {
        // Physical keys keep background shortcuts independent of layout.
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

        // Unmodified shortcuts belong to the panel background. Controls and
        // the tab strip own their own arrows, digits and activation keys.
        if (!root.activeFocus || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return

        // Direct tab jump (keys 1-3)
        if (key >= Qt.Key_1 && key <= Qt.Key_3) {
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
                GlobalStates.dashboardOpenIndex = Math.min(2, tabView.currentIndex + 1)
                event.accepted = true
                return
            }
        }

        // Route to active tab
        if (tabView.currentIndex === 2) (calendarLoader.item as CalendarTab)?.handleNavigationKey(event)
    }

    MaterialCard {
        anchors.fill: parent
        color: Qt.alpha(Theme.surfaceContainer, AppConfig.panelOpacity)
        radius: Tokens.shape.large

        ColumnLayout {
            anchors.fill: parent
            // Layout.fillWidth: true
            spacing: 0

            // The header reserves exactly the date and tab navigation it contains.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerHeight

                Column {
                    id: clockColumn
                    readonly property real naturalWidth: dateText.implicitWidth
                    width: Math.min(naturalWidth, Math.max(0, parent.width - Tokens.panelPadding * 2))
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.panelPadding
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.panelPadding
                    spacing: Tokens.spacing.extraSmall
                    MaterialText {
                        id: dateText
                        width: clockColumn.width
                        elide: Text.ElideRight
                        text: Qt.formatDateTime(DateTime.clock.date, "dddd, d MMMM")
                        textStyle: "titleSmall"
                        colorRole: "onSurfaceVariant"
                    }
                }
                MaterialTabs {
                    id: tabBar
                    objectName: "dashboardTabs"
                    width: Math.min(implicitWidth, Math.max(0, parent.width - Tokens.panelPadding * 2))
                    height: implicitHeight
                    x: root._stackedHeader ? Tokens.panelPadding
                        : parent.width - Tokens.panelPadding - width
                    y: root._stackedHeader ? clockColumn.y + clockColumn.height + Tokens.spacing.small
                        : (parent.height - height) / 2
                    labels: ["Quick", "Weather", "Calendar"]
                    currentIndex: GlobalStates.dashboardOpenIndex
                    accessibleName: "Dashboard sections"
                    enabled: !root._modalOpen
                    onActivated: index => GlobalStates.dashboardOpenIndex = index
                }
            }


            // ===== TAB CONTENT =====
            // One active Loader; inactive tabs do not contribute geometry.
            Item {
                id: tabView
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property int currentIndex: GlobalStates.dashboardOpenIndex
                implicitHeight: root._tabLoaders[currentIndex]?.implicitHeight ?? 0

                Loader {
                    id: quickLoader
                    anchors.fill: parent
                    active: tabView.currentIndex === 0
                    sourceComponent: Component { QuickTab {} }
                }
                Loader {
                    id: weatherLoader
                    anchors.fill: parent
                    active: tabView.currentIndex === 1
                    sourceComponent: Component { WeatherTab {} }
                }
                Loader {
                    id: calendarLoader
                    anchors.fill: parent
                    active: tabView.currentIndex === 2
                    sourceComponent: Component { CalendarTab {objectName: "dashboardCalendar"} }
                }


            }
        }
    }
}
