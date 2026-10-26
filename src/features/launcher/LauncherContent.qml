pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services
import qs.src.features.launcher.components as LauncherComponents

Item {
    id: root
    property bool _searchReady: false
    readonly property string mode: LauncherService.modeFor(searchField.text)
    readonly property bool searchPending: searchDebounce.running || LauncherService.busy
    readonly property real chromeHeight: searchField.implicitHeight + footer.implicitHeight
        + Tokens.panelPadding * 2 + Tokens.spacing.small * 2 + Tokens.focusRing.offset * 2
    // Fixed rows provide an exact preferred height without relying on the
    // ListView's changing content estimate while delegates are constructed.
    readonly property int resultCount: _searchReady ? LauncherService.filteredApps.length : 0
    readonly property real resultRowHeight: Math.max(Tokens.size.listItem,
        Math.ceil(Tokens.typography.titleMedium.lineHeight + Tokens.typography.bodySmall.lineHeight)
        + Tokens.spacing.small * 2 + Tokens.spacing.extraSmall)
    readonly property real resultsHeight: resultCount > 0
        ? Math.min(resultCount * resultRowHeight + (resultCount - 1) * Tokens.spacing.extraSmall,
            AppConfig.launcherListMaxHeight) : empty.implicitHeight
    implicitHeight: chromeHeight + resultsHeight

    function activateCurrent() {
        const index = searchDebounce.running ? 0 : appListView.currentIndex
        searchField.flushSearch()
        const result = LauncherService.filteredApps[index]
        if (!result?.action || LauncherService.busy) return
        LauncherService.launch(result)
    }
    function moveSelection(delta) {
        searchField.flushSearch()
        if (appListView.count) appListView.currentIndex = Math.max(0,
            Math.min(appListView.count - 1, appListView.currentIndex + delta))
    }
    function reset() {
        searchField.text = ""
        searchDebounce.stop()
        ClipboardService.refresh()
        LauncherService.search("")
        _searchReady = true
        appListView.currentIndex = 0
        appListView.contentY = 0
        searchField.inputItem.forceActiveFocus()
    }
    MaterialCard {
        anchors.fill: parent
        anchors.margins: Tokens.focusRing.offset
        color: Theme.surfaceContainer
        radius: Tokens.shape.large
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.panelPadding
            spacing: Tokens.spacing.small
            MaterialTextField {
                id: searchField
                Layout.fillWidth: true
                variant: "filled"
                leadingIcon: root.mode === "calculator" ? "calculate" : root.mode === "clipboard" ? "content_paste"
                    : root.mode === "actions" ? "bolt" : "search"
                trailingIcon: text.length > 0 ? "close" : ""
                placeholderText: "Search applications"
                onTrailingClicked: { text = ""; inputItem.forceActiveFocus() }
                onAccepted: root.activateCurrent()
                onTextChanged: { appListView.currentIndex = 0; searchDebounce.restart() }
                Timer {
                    id: searchDebounce
                    interval: 120
                    onTriggered: LauncherService.search(searchField.text)
                }
                function flushSearch() {
                    if (!searchDebounce.running) return
                    searchDebounce.stop()
                    LauncherService.search(text)
                }
                // Handle navigation on the editor before Qt's default Tab
                // traversal can move focus to the clear button.
                Connections {
                    target: searchField.inputItem.Keys
                    function onPressed(event) {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                            root.moveSelection(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                        else if (event.key === Qt.Key_Down) root.moveSelection(1)
                        else if (event.key === Qt.Key_Up) root.moveSelection(-1)
                        else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
                            root.moveSelection((event.key === Qt.Key_PageDown ? 1 : -1)
                                * Math.max(1,Math.floor(appListView.height / (appListView.currentItem?.height ?? Tokens.size.listItem))))
                        else if (event.key === Qt.Key_Escape) GlobalStates.closePanel("launcher")
                        else return
                        event.accepted = true
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(root.resultsHeight, Math.max(0, root.height - root.chromeHeight))
                ListView {
                    id: appListView
                    anchors.fill: parent
                    visible: count > 0
                    reuseItems: true
                    clip: true
                    spacing: Tokens.spacing.extraSmall
                    currentIndex: 0
                    highlightFollowsCurrentItem: false
                    model: ScriptModel {
                        objectProp: "resultId"
                        values: root._searchReady ? LauncherService.filteredApps : []
                        onValuesChanged: appListView.currentIndex = 0
                    }
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: LauncherComponents.AppListItem {
                        width: appListView.width
                        height: root.resultRowHeight
                        isCurrentItem: appListView.currentIndex === index && !!modelData?.action
                        enabled: !root.searchPending && !!modelData?.action
                        onClicked: {
                            if (root.searchPending) return
                            LauncherService.launch(modelData)
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                ListItem {
                    id: empty
                    anchors.left: parent.left
                    anchors.right: parent.right
                    visible: appListView.count === 0
                    clickable: false
                    leadingIcon: root.searchPending ? "hourglass_empty" : "search_off"
                    headline: root.searchPending ? "Searching…"
                        : root.mode === "calculator" ? "Enter an expression"
                        : root.mode === "clipboard" ? "No clipboard entries"
                        : root.mode === "actions" ? "No matching actions" : "No applications found"
                    supportingText: root.mode === "calculator" ? "= 2 + 2"
                        : root.mode === "clipboard" ? "Use > followed by text to search history"
                        : root.mode === "actions" ? "Try : audio or : calendar" : "Try a different name"
                }
            }
            MaterialText {
                id: footer
                Layout.fillWidth: true
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
                wrapMode: Text.Wrap
                text: searchField.text.trim() === "" ? "= Calculator · > Clipboard · : Shell actions"
                    : (root.mode === "calculator" ? "Calculator · Enter: Copy"
                        : root.mode === "clipboard" ? "Clipboard · Enter: Copy"
                        : root.mode === "actions" ? "Shell actions · Enter: Run" : "Applications · Enter: Open")
                        + " · ↑↓ / Tab: Select · Esc: Close"
            }
        }
    }
    Connections {
        target: GlobalStates
        function onPanelOpened(name) { if (name === "launcher") root.reset() }
        function onLauncherOpenChanged() { if (!GlobalStates.launcherOpen) searchDebounce.stop() }
    }
    Component.onCompleted: reset()
}
