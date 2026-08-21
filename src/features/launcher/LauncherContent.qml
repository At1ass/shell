pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services
import qs.src.features.launcher.components as LauncherComponents

Item {
    id: root

    // LauncherService.filteredApps is a SINGLETON property that outlives the
    // launcher window, so at creation it still holds the PREVIOUS session's
    // results. Binding the list model straight to it populated the view with
    // stale rows, and the replacement a moment later (Component.onCompleted
    // runs the first search) left the outgoing delegates drawn ON TOP of the
    // incoming ones — permanently, not just for the remove transition. That
    // is the doubled first row, and the rows that came up with no icon.
    // Reproduce by typing a query, closing, and reopening.
    //
    // So: show nothing until the first search for THIS session has run.
    property bool _searchReady: false

    implicitHeight: 56 + Math.min(appListView.contentHeight, AppConfig.launcherListMaxHeight) + Tokens.spacing.large * 3 + 4  // +4 for the shadow

    // MD3 Shadow (Elevation Level 2)

    MaterialCard {
        id: container
        anchors.fill: parent
        anchors.margins: 2  // Margin for the shadow
        outlined: false

        color: Theme.surfaceContainer
        radius: Tokens.shape.extraLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            // Search Field (at top with fixed height)
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Tokens.shape.full
                color: Theme.surfaceContainerHighest
                border.width: searchField.activeFocus ? 2 : 0
                border.color: searchField.activeFocus ? Theme.primary : "transparent"

                Behavior on border.width {
                    MotionAnimation {
                        duration: Tokens.motion.duration.short4
                        curve: "standard"
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "search"
                        iconColor: Theme.onSurfaceVariant
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true

                        placeholderText: "Search apps..."
                        color: Theme.onSurface
                        font.pixelSize: Tokens.typography.bodyLarge.size

                        background: Item {}  // Transparent - the outer Rectangle is used

                        // Coalesced, NOT live. Every keystroke rebuilds the
                        // result list, which rebinds delegates and cancels
                        // their in-flight icon loads — and a cancelled load
                        // poisons Quickshell's icon provider for that icon
                        // NAME for the rest of the session. The icon then
                        // renders nowhere: not here, not in the bar's
                        // workspace chips. Reproduce by typing fast; the
                        // poisoned entry survives reopening the launcher, is
                        // keyed by name rather than size, and ignores
                        // `cache: false`, so it is below this layer.
                        //
                        // Holding the query still for one interval lets the
                        // loads finish. Enter flushes a pending search first
                        // so it can never act on a stale list.
                        onTextChanged: {
                            searchDebounce.restart()
                            appListView.currentIndex = 0
                        }

                        Timer {
                            id: searchDebounce
                            interval: 120
                            onTriggered: LauncherService.search(searchField.text)
                        }

                        function flushSearch() {
                            if (searchDebounce.running) {
                                searchDebounce.stop()
                                LauncherService.search(searchField.text)
                            }
                        }

                        // Tab navigation
                        Keys.onTabPressed: (event) => {
                            if (event.modifiers & Qt.ShiftModifier) {
                                // Shift+Tab - up
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--
                                }
                            } else {
                                // Tab - down
                                if (appListView.currentIndex < appListView.count - 1) {
                                    appListView.currentIndex++
                                }
                            }
                            event.accepted = true
                        }

                        Keys.onBacktabPressed: (event) => {
                            // Shift+Tab alternate handler
                            if (appListView.currentIndex > 0) {
                                appListView.currentIndex--
                            }
                            event.accepted = true
                        }

                        // Keyboard navigation
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                if (appListView.currentIndex < appListView.count - 1) {
                                    appListView.currentIndex++
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                searchField.flushSearch()
                                const result = appListView.currentItem?.modelData ?? null
                                // Actionless rows (calculator errors) stay open.
                                if (result?.action) {
                                    LauncherService.launch(result)
                                    GlobalStates.closePanel("launcher")
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                GlobalStates.closePanel("launcher")
                                event.accepted = true
                            }
                        }

                        Component.onCompleted: searchField.forceActiveFocus()
                    }

                    IconButton {
                        id: clearButton
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "close"
                        visible: searchField.text.length > 0
                        iconSize: Tokens.iconSize.medium

                        onClicked: {
                            searchField.text = ""
                            searchField.forceActiveFocus()
                        }
                    }
                }
            }

            // App List (scrollable, takes remaining space)
            ListView {
                id: appListView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                    contentHeight,
                    AppConfig.launcherListMaxHeight
                )

                maximumFlickVelocity: 3000

                // ScriptModel to track item changes
                model: ScriptModel {
                    id: scriptModel
                    objectProp: "resultId"  // Fixed: all providers use "id"
                    values: root._searchReady ? LauncherService.filteredApps : []

                    onValuesChanged: appListView.currentIndex = 0
                }

                spacing: Tokens.spacing.extraSmall
                clip: true

                currentIndex: 0
                highlightFollowsCurrentItem: false

                // Auto-scroll when currentIndex changes
                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }

                // Transform origin for scale animations
                transformOrigin: Item.Center

                // Highlight
                highlight: Rectangle {
                    visible: !!appListView.currentItem
                    width: appListView.width
                    height: appListView.currentItem ? appListView.currentItem.height : 0
                    y: appListView.currentItem ? appListView.currentItem.y : 0
                    radius: Tokens.shape.medium
                    color: Theme.secondaryContainer
                    opacity: 0.3

                    Behavior on y {
                        MotionAnimation {
                            duration: Tokens.motion.duration.short4
                            curve: "standard"
                        }
                    }

                    Behavior on height {
                        MotionAnimation {
                            duration: Tokens.motion.duration.short4
                            curve: "standard"
                        }
                    }
                }

                delegate: LauncherComponents.AppListItem {
                    width: appListView.width
                    isCurrentItem: appListView.currentIndex === index

                    onClicked: {
                        LauncherService.launch(modelData)
                        GlobalStates.closePanel("launcher")
                    }
                }

                // Flag to disable transitions on reopen
                property bool transitionsEnabled: true

                // MD3 transitions for list item add/remove/move
                add: Transition {
                    enabled: appListView.transitionsEnabled
                    MotionAnimation {
                        properties: "opacity,scale"; from: 0; to: 1
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                }

                populate: Transition {
                    enabled: appListView.transitionsEnabled
                    MotionAnimation {
                        properties: "opacity,scale"; from: 0; to: 1
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                }

                // No `remove` transition. It was the only one that drove a
                // delegate's scale toward 0, and ListView keeps an item alive
                // for the whole transition — so interrupting it was what left
                // rows stranded shrunk. Rows now leave at once.

                move: Transition {
                    MotionAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                    MotionAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                }

                addDisplaced: Transition {
                    MotionAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.short4
                        curve: "standard"
                    }
                    MotionAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.short4
                        curve: "standard"
                    }
                }

                displaced: Transition {
                    MotionAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                    MotionAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                }

                rebound: Transition {
                    MotionAnimation {
                        properties: "x,y"
                        duration: Tokens.motion.duration.medium4
                        curve: "standard"
                    }
                }

                // Scrollbar - always reserve space
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    visible: appListView.contentHeight > appListView.height
                    opacity: visible ? 1.0 : 0.0

                    Behavior on opacity {
                        MotionAnimation {
                            duration: Tokens.motion.duration.short4
                            curve: "standard"
                        }
                    }
                }
            }
        }
    }

    // Re-run the search when cliphist entries change in clipboard-prefix mode
    // (covers the case where ClipboardService.refresh in onVisibleChanged got
    // back stale data, then the 100ms debounce refresh delivered the new
    // entry afterwards — the displayed list needs to recompute).
    Connections {
        target: ClipboardService
        function onEntriesChanged() {
            if (root.visible && searchField.text.startsWith(">"))
                LauncherService.search(searchField.text)
        }
    }

    // Initialize on creation. The content is recreated per open (LazyLoader
    // + Loader both gate on launcherOpen), so this IS the open hook — an
    // onVisibleChanged reset block would be dead code here (visible never
    // changes during the item's lifetime).
    Component.onCompleted: {
        // Pull fresh cliphist state — the clipboard-change watcher uses a
        // 100 ms debounce, which races a fast Mod+Space right after a copy.
        ClipboardService.refresh()
        LauncherService.search("")
        root._searchReady = true
        appListView.currentIndex = 0
    }
}
