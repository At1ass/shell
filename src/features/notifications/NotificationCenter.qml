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
        // the panel goes away. The LazyLoader in shell.qml destroys this window
        // on close, so destruction is the close event.
        Component.onDestruction: NotificationService.markAllRead()
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
            width: AppConfig.notificationPanelWidth
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
                    notifList.currentIndex = -1
                    notifList.positionViewAtBeginning()
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
            function _moveCursor(delta) {
                if (notifList.count === 0) return
                const cur = notifList.currentIndex
                const next = cur < 0
                    ? (delta > 0 ? 0 : notifList.count - 1)
                    : Math.max(0, Math.min(notifList.count - 1, cur + delta))
                notifList.currentIndex = next
                notifList.positionViewAtIndex(next, ListView.Contain)
            }

            Keys.onPressed: (event) => {
                // Keycodes.key(), NOT event.key: the latter carries the symbol
                // the active layout produces, so every vi binding below was
                // dead on a Cyrillic layout — the physical J key arrives as
                // Qt.Key_O there. Escape/arrows/Return/Delete pass through
                // unchanged; they are layout-independent already.
                const key = Keycodes.key(event)

                if (key === Qt.Key_Escape) {
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
                        if (item && item.notificationId)
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
                        notifList.currentIndex = target
                        notifList.positionViewAtIndex(target, ListView.Contain)
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
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        // No decorative bell here: the DND toggle on the right
                        // is also a bell, and two near-identical glyphs in one
                        // header made it ambiguous which one was interactive.
                        // The title carries the meaning; the toggle keeps the icon.
                        MaterialText {
                            text: "Notifications"
                            textStyle: "titleLarge"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                        }

                        Item { Layout.fillWidth: true }

                        // DND toggle. The selected state is the button's own
                        // `tonal` variant, not a hand-placed Rectangle at
                        // z: -1 with a hardcoded 0.3 opacity. The icon pair
                        // also matches the bar widget now — it used to show
                        // "do_not_disturb_on" while DND was OFF, i.e. the
                        // icon for the state you were not in.
                        IconButton {
                            iconName: NotificationService.doNotDisturb ? "notifications_off" : "notifications"
                            iconSize: Tokens.iconSize.large
                            variant: NotificationService.doNotDisturb ? "tonal" : "standard"
                            iconColor: NotificationService.doNotDisturb ? Theme.onTertiaryContainer : Theme.onSurfaceVariant
                            onClicked: NotificationService.toggleDoNotDisturb()
                        }

                        MaterialButton {
                            text: "Clear all"
                            variant: "text"
                            enabled: NotificationService.historyList.count > 0
                            onClicked: NotificationService.clearHistory()
                        }
                    }

                    // Count indicator + DND state hint
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialText {
                            text: {
                                const count = NotificationService.historyList.count
                                if (count === 0) return ""
                                return count + (count === 1 ? " notification" : " notifications")
                            }
                            visible: text.length > 0
                            textStyle: "labelMedium"
                            colorRole: "onSurfaceVariant"
                        }

                        // Keyboard shortcuts were fully undiscoverable: j/k,
                        // Delete/X, Enter and g/G existed with nothing on
                        // screen naming them.
                        MonoText {
                            visible: NotificationService.historyList.count > 0 && !NotificationDND.active
                            text: "j/k move · x delete · ⏎ collapse"
                            textStyle: "labelSmall"
                            colorRole: "outline"
                        }

                        Item { Layout.fillWidth: true }

                        // Surface DND-active state — distinguish manual toggle
                        // from the auto-suppress when a fullscreen window is in focus.
                        MaterialText {
                            visible: NotificationDND.active
                            text: NotificationDND.enabled
                                ? "DND on — popups silenced"
                                : "Fullscreen — popups silenced"
                            textStyle: "labelSmall"
                            colorRole: "tertiary"
                        }
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
                            spacing: 0
                            clip: true
                            // Selection is drawn by the delegate's own focus
                            // ring (see NotificationHistoryItem.selected), so
                            // no `highlight` component and no auto-follow —
                            // `highlightFollowsCurrentItem` did nothing here
                            // anyway, because no highlight was ever defined.
                            currentIndex: -1

                            model: NotificationService.historyList

                            // Recycle delegates instead of destroying and
                            // rebuilding one per row that crosses the viewport.
                            // Every model role is a `required property`, so the
                            // bindings re-resolve on reuse; only the delegate's
                            // OWN transient state has to be undone by hand,
                            // which is what onReused below does.
                            //
                            // NO cacheBuffer here, deliberately. The obvious
                            // companion setting (DankMaterialShell pairs the
                            // two) builds roughly ten delegates beyond the
                            // viewport, and this panel is rebuilt on every
                            // open: measured interleaved over three rounds with
                            // 60 rows in history, it cost +28% on open
                            // (13.2 -> 17.0 ms of GUI thread) with no overlap
                            // between the two distributions. Opening is the
                            // dominant cost here; scrolling is not.
                            reuseItems: true

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

                                // The add/remove transitions below animate this
                                // Column's opacity and scale, and a recycled
                                // delegate inherits wherever they stopped.
                                ListView.onReused: {
                                    row.opacity = 1
                                    row.scale = 1
                                    historyItem.resetSwipe()
                                }

                                NotificationHistoryItem {
                                    id: historyItem
                                    width: parent.width
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
                }
            }
        }
    }
}
