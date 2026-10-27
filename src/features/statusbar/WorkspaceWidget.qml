pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

// Per-workspace indicators. Empty workspaces show a tonal dot (MaterialIndicator); occupied
// ones show up to `maxWindows` app icons with a "+N" overflow chip. The widget owns its own
// per-item interaction, so the BarElement-level hover/click handling is disabled.
BarElement {
    id: workspaceWidget

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    property int wsBaseIndex: widgetSettings.baseIndex ?? 1
    property int wsCount: widgetSettings.count ?? 9
    property bool showWindows: widgetSettings.showWindows ?? true
    property int maxWindows: widgetSettings.maxWindowsPerWorkspace ?? 4

    property int _metricRevision: 0
    function fullWidth() {
        let total = Tokens.spacing.medium + Math.max(0, wsCount - 1) * Tokens.spacing.extraSmall
        for (let i = 0; i < workspaceItems.count; i++) total += workspaceItems.itemAt(i)?.fullWidth ?? chipSize
        return total
    }
    preferredWidth: { const revision = _metricRevision; return fullWidth() }
    minimumWidth: preferredWidth
    compactWidth: Tokens.spacing.medium + wsCount * chipSize + Math.max(0, wsCount - 1) * Tokens.spacing.extraSmall

    hoverable: false
    clickable: false

    // Wheel-scroll to switch workspaces (accumulate fractional deltas into whole steps).
    property int scrollAccumulator: 0
    property int currentIndex: 1

    // Chip metrics (token-derived).
    readonly property int chipSize: Tokens.spacing.large           // empty-workspace dot chip
    readonly property int iconFontSize: Tokens.typography.bodyMedium.size

    // Single pass over the toplevel list grouping windows by workspace id — avoids the
    // O(workspaces x windows) re-filtering of one pass per indicator on every toplevel change.
    readonly property var windowsByWorkspace: {
        const map = {};
        const toplevels = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < toplevels.length; i++) {
            const id = toplevels[i].workspace?.id;
            if (id === undefined || id === null)
                continue;
            if (!map[id])
                map[id] = [];
            map[id].push(toplevels[i]);
        }
        return map;
    }

    wheelHandler: function (wheel) {
        wheel.accepted = true;
        let acc = scrollAccumulator - wheel.angleDelta.y;
        const sign = Math.sign(acc);
        acc = Math.abs(acc);

        const offset = sign * Math.floor(acc / 120);
        scrollAccumulator = sign * (acc % 120);

        if (offset != 0) {
            const targetWorkspace = currentIndex + offset;
            const id = Math.max(wsBaseIndex, Math.min(wsBaseIndex + wsCount - 1, targetWorkspace));
            if (id != currentIndex) {
                currentIndex = id;
                HyprlandDispatch.focusWorkspace(id);
            }
        }
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: workspaceItems
            onItemAdded: workspaceWidget._metricRevision++
            onItemRemoved: workspaceWidget._metricRevision++
            model: workspaceWidget.wsCount

            Item {
                id: wsItem

                required property int index
                property int wsIndex: workspaceWidget.wsBaseIndex + index
                property var allWindows: workspaceWidget.windowsByWorkspace[wsIndex] ?? []
                property var shownWindows: allWindows.slice(0, workspaceWidget.maxWindows)
                property int overflow: Math.max(0, allWindows.length - workspaceWidget.maxWindows)
                property bool hasWindows: allWindows.length > 0
                property bool exists: hasWindows
                property bool active: wsIndex === Hyprland.focusedWorkspace?.id
                // When window dots are enabled, only surface occupied/active workspaces;
                // otherwise show every indicator.
                property bool showIndicator: workspaceWidget.showWindows ? (exists || active) : true

                readonly property real fullWidth: hasWindows ? windowIconsRow.implicitWidth + Tokens.spacing.small * 2 : workspaceWidget.chipSize
                implicitWidth: workspaceWidget.compactPresentation ? workspaceWidget.chipSize : fullWidth
                implicitHeight: workspaceWidget.chipSize

                Behavior on implicitWidth {
                    enabled: workspaceWidget.animationsActive
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium2
                        curve: "emphasized"
                    }
                }

                onActiveChanged: {
                    if (active)
                        workspaceWidget.currentIndex = wsIndex;
                }

                // Selected-state container behind the active workspace's icons (MD3 tonal fill).
                Surface {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.extraSmall / 2
                    elevation: 0
                    radius: Tokens.shape.small
                    color: Theme.secondaryContainer
                    opacity: (wsItem.active && wsItem.hasWindows) ? 1 : 0
                    visible: opacity > 0
                    z: -1

                    Behavior on opacity {
                        enabled: workspaceWidget.animationsActive
                        MotionAnimation {
                            duration: Tokens.motion.duration.medium2
                            curve: "standard"
                        }
                    }
                }

                // Workspace-level interaction. Declared BEFORE the icon row so the per-window
                // icon handlers (later siblings) sit on top and receive their own clicks; this
                // MouseArea only catches clicks on the chip's empty area / the dot.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            GlobalStates.handleClickAction(workspaceWidget.widgetConfig?.clickAction ?? "overview");
                            return;
                        }
                        if (mouse.button === Qt.LeftButton)
                            HyprlandDispatch.focusWorkspace(wsItem.wsIndex);
                    }
                }

                // Empty/occupied dot indicator.
                MaterialIndicator {
                    animated: workspaceWidget.animationsActive
                    anchors.centerIn: parent
                    visible: !wsItem.hasWindows || workspaceWidget.compactPresentation
                    shape: "rounded"
                    size: wsItem.active ? "extraLarge" : (wsItem.showIndicator ? "medium" : "small")
                    colorRole: wsItem.active ? "primary" : (wsItem.showIndicator ? "secondaryContainer" : "outline")
                }

                // App icons for the windows on this workspace.
                Row {
                    id: windowIconsRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall
                    visible: wsItem.hasWindows && !workspaceWidget.compactPresentation

                    // Declarative enter/reposition animation — fires only for genuinely new
                    // delegates (ScriptModel reuses existing ones), not on every toplevel event.
                    add: Transition {
                        MotionAnimation {
                            properties: "scale"
                            from: 0.0
                            to: 1.0
                            duration: Tokens.motion.duration.medium2
                            curve: "emphasizedDecelerate"
                        }
                        NumberAnimation {
                            properties: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: Tokens.motion.duration.short3
                        }
                    }
                    move: Transition {
                        MotionAnimation {
                            properties: "x"
                            duration: Tokens.motion.duration.medium2
                            curve: "standard"
                        }
                    }

                    Repeater {
                        // ScriptModel diffs by element identity against the stable toplevel
                        // pool, so delegates are reused across window events.
                        model: ScriptModel { values: wsItem.shownWindows }

                        // The real application icon, with the category glyph as
                        // the fallback. Two ways to have no icon and both must
                        // land on the glyph: the window class resolves to no
                        // desktop entry (source is ""), or it resolves to an
                        // icon name the theme cannot actually produce — which
                        // only shows up as Image.Error at load time.
                        delegate: Item {
                            id: winIcon
                            required property var modelData

                            readonly property string windowClass: modelData.lastIpcObject?.class ?? ""
                            readonly property bool hasAppIcon: appIcon.status === Image.Ready

                            implicitWidth: workspaceWidget.iconFontSize
                            implicitHeight: workspaceWidget.iconFontSize

                            // Full colour on the focused workspace, dimmed
                            // elsewhere: the glyph carried that distinction in
                            // its tint, and an app icon cannot be tinted.
                            opacity: wsItem.active ? 1.0 : 0.65

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: IconCategoryResolver.appIconSource(winIcon.windowClass)
                                sourceSize.width: workspaceWidget.iconFontSize
                                sourceSize.height: workspaceWidget.iconFontSize
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                // NOT asynchronous. `image://icon/` resolves
                                // through Quickshell's IconImageProvider, which
                                // calls QIcon::fromTheme(...).pixmap() -- i.e.
                                // KIconEngine/KIconLoader, which is not thread
                                // safe. Loading asynchronously hands that call
                                // to Qt's QQuickPixmapReader thread and the
                                // shell segfaults there: three coredumps on
                                // 2026-09-01/02, every one on a thread named
                                // QQuickPixmapRea inside
                                // KIconEngine::createPixmap, and this was the
                                // only asynchronous icon-provider load in the
                                // shell. It fired when a window appeared and
                                // its chip icon loaded. Quickshell's own
                                // IconImage defaults asynchronous to false for
                                // the same reason, and the dock has always
                                // loaded its icons synchronously -- which is
                                // why the dock never crashed.
                                visible: winIcon.hasAppIcon
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: !winIcon.hasAppIcon
                                iconName: IconCategoryResolver.getAppCategoryIcon(winIcon.windowClass, "terminal")
                                fontSize: workspaceWidget.iconFontSize
                                iconColor: wsItem.active ? Theme.primary : Theme.onSurfaceVariant
                            }

                            StateLayer {
                                anchors.fill: parent
                                hovered: winMouse.containsMouse
                                pressed: winMouse.pressed
                                layerColor: Theme.onSurface
                                showFocusRing: false
                            }

                            MouseArea {
                                id: winMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: HyprlandDispatch.focusWindow(winIcon.modelData.address)
                            }
                        }
                    }

                    // Overflow chip when more windows than maxWindows are present.
                    MaterialText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: wsItem.overflow > 0
                        text: "+" + wsItem.overflow
                        textStyle: "labelSmall"
                        colorRole: wsItem.active ? "primary" : "onSurfaceVariant"
                    }
                }
            }
        }
    }
}
