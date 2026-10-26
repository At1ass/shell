pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

// NotificationDND import comes from qs.src.core.services above (singleton).

Scope {
    PanelWindow {
        id: centerWindow
        visible: GlobalStates.notificationCenterOpen

        // The output to map onto, resolved by GlobalStates.openPanel once per
        // open and before the open flag flips -- so this window is still
        // invisible when it moves, and a RETAINED panel still lands on the
        // monitor the user is looking at. Resolving in Component.onCompleted
        // was only correct while every open rebuilt the window.
        screen: GlobalStates.activePanelScreen ?? null

        // Unread clears on CLOSE, not on open. Clearing on open made the
        // per-card unread dot useless: by the time the panel had finished
        // animating in, every dot it exists to show was already gone. Now the
        // dots survive the visit that reads them, and the bar badge drops when
        // the panel closes. Visibility also covers panels retained between
        // visits; destruction handles a configuration reload while open.
        property bool _wasOpen: false
        onVisibleChanged: {
            if (visible) {
                NotificationService.refreshClearUndo()
                _wasOpen = true
                Qt.callLater(() => notifList.scheduleLayout())
            } else if (_wasOpen) {
                _wasOpen = false
                NotificationService.markAllRead()
            }
        }
        Component.onDestruction: {
            if (_wasOpen) NotificationService.markAllRead()
        }
        focusable: true
        color: "transparent"

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:notification-center"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            active: GlobalStates.notificationCenterOpen
            windows: [centerWindow]
            onCleared: GlobalStates.closePanel("notificationCenter")
        }

        // Scrim overlay
        Scrim {
            shown: panelSlide.visible
            duration: Tokens.motion.duration.medium2

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.closePanel("notificationCenter")
            }
        }

        Item {
            id: panelSlide
            width: Math.max(1, Math.min(AppConfig.notificationPanelWidth, centerWindow.width - Tokens.spacing.medium * 2))
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            anchors.margins: Tokens.spacing.medium
            z: 1
            visible: GlobalStates.notificationCenterOpen

            // Slide-in animation
            property real _slideX: visible ? 0 : panelSlide.width + Tokens.spacing.medium
            property real _slideOpacity: visible ? 1.0 : 0

            transform: Translate { x: panelSlide._slideX }
            opacity: panelSlide._slideOpacity

            Behavior on _slideX {
                MotionAnimation {
                    duration: Tokens.motion.duration.medium2
                    curve: "emphasizedDecelerate"
                }
            }

            Behavior on _slideOpacity {
                MotionAnimation {
                    duration: Tokens.motion.duration.medium1
                    curve: "standard"
                }
            }

            focus: true

            // A retained panel keeps its keyboard cursor and scroll offset, so
            // reopening would restore a selection nobody made and a viewport
            // the user did not leave there. Both used to reset by virtue of the
            // panel being rebuilt.
            Connections {
                target: GlobalStates
                function onPanelOpened(name) {
                    if (name !== "notificationCenter")
                        return
                    panelSlide._selectedEntryId = ""
                    notifList.currentIndex = -1
                    notifList.positionViewAtBeginning()
                    notifList.scheduleLayout()
                }
            }

            // Keyboard navigation.
            //
            // The cursor starts at -1, not at ListView's default 0: the
            // selection is now VISIBLE (a focus ring on the row), so parking it
            // on the first card before the user has pressed anything would look
            // like a selection nobody made. `_moveCursor` also scrolls the row
            // into view — previously j/k moved an invisible cursor that could
            // walk right off the viewport, and Delete then removed a card the
            // user could not see.
            property string _selectedEntryId: ""

            // A collapsed group is one navigable header, represented by its
            // first model row. Hidden notifications are never selected.
            function _isGroupHeader(index) {
                if (!AppConfig.notificationGroupByApp || index < 0) return false
                const entry = NotificationService.historyList.get(index)
                return entry && !NotificationService.isGroupExpanded(entry.appName)
            }

            function _isNavigable(index) {
                if (!_isGroupHeader(index)) return true
                return index === 0 || NotificationService.historyList.get(index - 1).appName
                    !== NotificationService.historyList.get(index).appName
            }

            function _selectIndex(index, scroll) {
                notifList.currentIndex = index
                _selectedEntryId = index >= 0
                    ? NotificationService.historyList.get(index).notificationId : ""
                if (scroll && index >= 0)
                    notifList.positionViewAtIndex(index, ListView.Contain)
            }

            function _syncCursor() {
                if (!_selectedEntryId) return
                const model = NotificationService.historyList
                let next = Math.min(notifList.currentIndex, model.count - 1)
                for (let i = 0; i < model.count; i++) {
                    if (model.get(i).notificationId === _selectedEntryId) { next = i; break }
                }
                while (next > 0 && !_isNavigable(next)) next--
                _selectIndex(next, false)
            }

            function _moveCursor(delta) {
                if (notifList.count === 0) return
                let next = notifList.currentIndex < 0
                    ? (delta > 0 ? 0 : notifList.count - 1)
                    : notifList.currentIndex + delta
                while (next >= 0 && next < notifList.count && !_isNavigable(next)) next += delta
                if (next >= 0 && next < notifList.count) _selectIndex(next, true)
            }

            Keys.onPressed: (event) => {
                // Keycodes.key(), NOT event.key: the latter carries the symbol
                // the active layout produces, so every vi binding below was
                // dead on a Cyrillic layout — the physical J key arrives as
                // Qt.Key_O there. Escape/arrows/Return/Delete pass through
                // unchanged; they are layout-independent already.
                const key = Keycodes.key(event)

                if (key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                    NotificationService.undoClearHistory()
                    event.accepted = true
                } else if (key === Qt.Key_Escape) {
                    GlobalStates.closePanel("notificationCenter")
                    event.accepted = true
                } else if (key === Qt.Key_Up || key === Qt.Key_K) {
                    panelSlide._moveCursor(-1)
                    event.accepted = true
                } else if (key === Qt.Key_Down || key === Qt.Key_J) {
                    panelSlide._moveCursor(1)
                    event.accepted = true
                } else if (key === Qt.Key_Delete || key === Qt.Key_X) {
                    if (notifList.currentIndex >= 0 && notifList.currentIndex < notifList.count) {
                        const item = NotificationService.historyList.get(notifList.currentIndex)
                        if (item && panelSlide._isGroupHeader(notifList.currentIndex))
                            NotificationService.removeGroupFromHistory(item.appName)
                        else if (item && item.notificationId)
                            NotificationService.removeFromHistory(item.notificationId)
                    }
                    event.accepted = true
                } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                    if (notifList.currentIndex >= 0 && notifList.currentIndex < notifList.count) {
                        const item = NotificationService.historyList.get(notifList.currentIndex)
                        if (item && AppConfig.notificationGroupByApp)
                            NotificationService.toggleGroupExpanded(item.appName)
                    }
                    event.accepted = true
                } else if (key === Qt.Key_G) {
                    if (notifList.count > 0) {
                        const target = (event.modifiers & Qt.ShiftModifier) ? notifList.count - 1 : 0
                        let next = target
                        while (next > 0 && !panelSlide._isNavigable(next)) next--
                        panelSlide._selectIndex(next, true)
                    }
                    event.accepted = true
                }
            }

            MaterialCard {
                anchors.fill: parent
                color: Theme.surfaceContainer
                radius: Tokens.shape.extraLarge

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small

                    // Header
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= titleLabel.implicitWidth + headerActions.implicitWidth + columnSpacing ? 2 : 1
                        columnSpacing: Tokens.spacing.small
                        rowSpacing: Tokens.spacing.extraSmall

                        // No decorative bell here: the DND toggle on the right
                        // is also a bell, and two near-identical glyphs in one
                        // header made it ambiguous which one was interactive.
                        // The title carries the meaning; the toggle keeps the icon.
                        MaterialText {
                            id: titleLabel
                            Layout.fillWidth: true
                            text: "Notifications"
                            wrapMode: Text.Wrap
                            textStyle: "titleLarge"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                        }

                        GridLayout {
                            id: headerActions
                            columns: panelSlide.width - Tokens.spacing.medium * 2 >= dndButton.implicitWidth + clearButton.implicitWidth + Tokens.spacing.small ? 2 : 1
                            columnSpacing: Tokens.spacing.small
                            rowSpacing: Tokens.spacing.extraSmall
                            Layout.alignment: Qt.AlignRight
                            // DND toggle. The selected state is the button's own
                            // `tonal` variant, not a hand-placed Rectangle at
                            // z: -1 with a hardcoded 0.3 opacity. The icon pair
                            // also matches the bar widget now — it used to show
                            // "do_not_disturb_on" while DND was OFF, i.e. the
                            // icon for the state you were not in.
                            IconButton {
                                id: dndButton
                                Layout.alignment: Qt.AlignRight
                                Accessible.name: "Toggle do not disturb"
                                iconName: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
                                iconSize: Tokens.iconSize.large
                                variant: NotificationService.doNotDisturb ? "tonal" : "standard"
                                iconColor: NotificationService.doNotDisturb ? Theme.onTertiaryContainer : Theme.onSurfaceVariant
                                onClicked: NotificationService.toggleDoNotDisturb()
                            }

                            MaterialButton {
                                id: clearButton
                                Layout.alignment: Qt.AlignRight
                                text: "Clear all"
                                variant: "text"
                                enabled: NotificationService.historyList.count > 0
                                    && !NotificationService.historyClearing && !NotificationService.historyRestoring
                                onClicked: { panelSlide._selectIndex(-1,false); NotificationService.clearHistory() }
                            }
                        }
                    }

                    MaterialText {
                        Layout.fillWidth: true
                        text: {
                            if (NotificationService.historyRestoring) return "Restoring notifications…"
                            if (NotificationService.historyClearing) return "Clearing history…"
                            const count = NotificationService.historyList.count
                            const suffix = count >= AppConfig.notificationMaxHistory ? " · History limit reached" : ""
                            const dnd = NotificationDND.active ? (NotificationDND.enabled ? " · DND on" : " · Fullscreen: popups silenced") : ""
                            return count + (count === 1 ? " notification" : " notifications") + suffix + dnd
                        }
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }

                    Divider {
                        Layout.fillWidth: true
                    }

                    // Notification list
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: notifList
                            anchors.fill: parent

                            // Flow and async images settle after initial placement.
                            // Coalesce measurements into one deferred layout pass.
                            function scheduleLayout() { Qt.callLater(relayout) }
                            function relayout() {
                                if (!centerWindow.visible) return
                                forceLayout()
                                panelSlide._syncCursor()
                            }
                            Component.onCompleted: scheduleLayout()
                            onWidthChanged: scheduleLayout()
                            onCountChanged: scheduleLayout()

                            Connections {
                                target: NotificationService.historyList
                                function onRowsMoved() { notifList.scheduleLayout() }
                                function onDataChanged() { notifList.scheduleLayout() }
                            }
                            Connections {
                                target: NotificationHistory
                                function on_GroupVersionChanged() { notifList.scheduleLayout() }
                            }
                            spacing: 0
                            clip: true
                            // Selection is drawn by the delegate's own focus
                            // ring (see NotificationHistoryItem.selected), so
                            // no `highlight` component and no auto-follow —
                            // `highlightFollowsCurrentItem` did nothing here
                            // anyway, because no highlight was ever defined.
                            currentIndex: -1

                            model: NotificationService.historyList

                            // NO reuseItems, and NO cacheBuffer.
                            //
                            // reuseItems was tried and REVERTED: these rows are
                            // variable height (the body wraps) and the list is
                            // sectioned, and a recycled delegate gets positioned
                            // from its previous height before the new text has
                            // laid out. Cards overlapped each other and the
                            // section headers. It was never shown to buy
                            // anything here either — the measured cost in this
                            // panel is construction at open, not scrolling.
                            //
                            // cacheBuffer likewise: measured interleaved over
                            // three rounds with 60 rows, it cost +28% on open
                            // (13.2 -> 17.0 ms of GUI thread) with no overlap
                            // between the distributions, because it builds ~10
                            // delegates past the viewport of a panel that is
                            // rebuilt on every open.

                            section.property: AppConfig.notificationGroupByApp ? "appName" : ""
                            section.delegate: NotificationGroupHeader {
                                required property string section
                                width: notifList.width
                                height: implicitHeight + Tokens.spacing.small
                                groupAppName: section
                                // Both come from NotificationHistory's group
                                // index — an O(1) lookup that is rebuilt once
                                // per mutation. They used to be linear scans of
                                // the whole model, run per group, on every add.
                                groupCount: NotificationHistory.getGroupCount(section)
                                groupAppIcon: NotificationHistory.getGroupIcon(section)
                                expanded: NotificationService.isGroupExpanded(section)
                                selected: !expanded && notifList.currentIndex >= 0
                                    && NotificationService.historyList.get(notifList.currentIndex)?.appName === section
                                onToggleExpanded: NotificationService.toggleGroupExpanded(section)
                            }

                            // Typed pass-through. The delegate used to build a
                            // fresh 12-field object literal (plus an actions
                            // array) whenever ANY one field changed, so a single
                            // `unread` flip re-created everything downstream.
                            // Separate properties let each binding update alone.
                            delegate: Column {
                                id: row
                                required property int index
                                required property string notificationId
                                required property int notifId
                                required property string summary
                                required property string body
                                required property string appName
                                required property string appIcon
                                required property string image
                                required property int urgency
                                required property real timestamp
                                required property int count
                                required property bool unread

                                readonly property bool itemVisible: !AppConfig.notificationGroupByApp
                                                                    || NotificationService.isGroupExpanded(row.appName)

                                width: notifList.width
                                height: itemVisible ? implicitHeight : 0
                                visible: itemVisible
                                onHeightChanged: notifList.scheduleLayout()

                                NotificationHistoryItem {
                                    id: historyItem
                                    width: parent.width
                                    onImplicitHeightChanged: notifList.scheduleLayout()
                                    rowIndex: row.index
                                    entryId: row.notificationId
                                    notifId: row.notifId
                                    summary: row.summary
                                    body: row.body
                                    appName: row.appName
                                    appIcon: row.appIcon
                                    image: row.image
                                    urgency: row.urgency
                                    timestamp: row.timestamp
                                    repeatCount: row.count
                                    unread: row.unread
                                    selected: notifList.currentIndex === row.index
                                    // Inside a group the section header already
                                    // names the app; repeating it on every card
                                    // just ate the row that the summary needs.
                                    showAppName: !AppConfig.notificationGroupByApp
                                }

                                Item {
                                    width: 1
                                    height: Tokens.spacing.small
                                }
                            }

                            // Qt's default flick ceiling (2500 px/s) reads as
                            // sluggish on a trackpad against a 60-row history,
                            // and the default overshoot return is not an MD3
                            // curve. Both are free to set; caelestia sets the
                            // same pair on every list it owns.
                            maximumFlickVelocity: 3000

                            rebound: Transition {
                                MotionAnimation {
                                    properties: "x,y"
                                    duration: Tokens.motion.duration.medium1
                                    curve: "standard"
                                }
                            }

                            // Smooth scroll
                            ScrollBar.vertical: ScrollBar {
                                active: notifList.moving || hovered
                                policy: ScrollBar.AsNeeded
                            }

                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.motion.duration.short4 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: Tokens.motion.duration.short4 }
                            }

                            remove: Transition {
                                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Tokens.motion.duration.short3 }
                            }

                            displaced: Transition {
                                MotionAnimation { properties: "y"; duration: Tokens.motion.duration.medium1; curve: "standard" }
                            }
                        }

                        EmptyState {
                            anchors.fill: parent
                            visible: NotificationService.historyList.count === 0
                            iconName: "notifications_none"
                            title: "No notifications"
                            subtitle: "New notifications will appear here"
                        }
                    }
                    Snackbar {
                        id: undoNotice
                        Layout.fillWidth: true
                        visible: NotificationService.canUndoClear || NotificationService.historyRestoring
                        message: NotificationService.historyRestoring ? "Restoring notifications…"
                            : NotificationService.clearedHistoryCount + (NotificationService.clearedHistoryCount === 1 ? " notification cleared" : " notifications cleared")
                        actionText: NotificationService.canUndoClear ? "Undo" : ""
                        onActionClicked: NotificationService.undoClearHistory()
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        visible: NotificationService.historyList.count > 0 || NotificationService.canUndoClear
                        text: (NotificationService.historyList.count > 0 ? "↑↓ / j k: Select · Del: Remove · Enter: Collapse" : "")
                            + (NotificationService.canUndoClear ? (NotificationService.historyList.count > 0 ? " · " : "") + "Ctrl+Z: Undo" : "")
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
