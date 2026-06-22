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
                Hyprland.dispatch("workspace " + id);
            }
        }
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall

        Repeater {
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

                implicitWidth: hasWindows ? windowIconsRow.implicitWidth + Tokens.spacing.small * 2
                                          : workspaceWidget.chipSize
                implicitHeight: workspaceWidget.chipSize

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Tokens.motion.duration.medium2
                        easing.type: Tokens.motion.easing.emphasized
                        easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
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
                        NumberAnimation {
                            duration: Tokens.motion.duration.medium2
                            easing.type: Tokens.motion.easing.standard
                            easing.bezierCurve: Tokens.motion.easing.standardPoints
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
                        if (mouse.button === Qt.RightButton && workspaceWidget.widgetConfig?.clickAction) {
                            GlobalStates.handleClickAction(workspaceWidget.widgetConfig.clickAction);
                            return;
                        }
                        if (mouse.button === Qt.LeftButton)
                            Hyprland.dispatch("workspace " + wsItem.wsIndex);
                    }
                }

                // Empty/occupied dot indicator.
                MaterialIndicator {
                    anchors.centerIn: parent
                    visible: !wsItem.hasWindows
                    shape: "rounded"
                    size: wsItem.active ? "extraLarge" : (wsItem.showIndicator ? "medium" : "small")
                    colorRole: wsItem.active ? "primary" : (wsItem.showIndicator ? "secondaryContainer" : "outline")
                }

                // App icons for the windows on this workspace.
                Row {
                    id: windowIconsRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall
                    visible: wsItem.hasWindows

                    // Declarative enter/reposition animation — fires only for genuinely new
                    // delegates (ScriptModel reuses existing ones), not on every toplevel event.
                    add: Transition {
                        NumberAnimation {
                            properties: "scale"
                            from: 0.0
                            to: 1.0
                            duration: Tokens.motion.duration.medium2
                            easing.type: Tokens.motion.easing.emphasizedDecelerate
                            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                        }
                        NumberAnimation {
                            properties: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: Tokens.motion.duration.short3
                        }
                    }
                    move: Transition {
                        NumberAnimation {
                            properties: "x"
                            duration: Tokens.motion.duration.medium2
                            easing.type: Tokens.motion.easing.standard
                            easing.bezierCurve: Tokens.motion.easing.standardPoints
                        }
                    }

                    Repeater {
                        // ScriptModel diffs by element identity against the stable toplevel
                        // pool, so delegates are reused across window events.
                        model: ScriptModel { values: wsItem.shownWindows }

                        delegate: MaterialIcon {
                            id: winIcon
                            required property var modelData

                            iconName: IconCategoryResolver.getAppCategoryIcon(modelData.lastIpcObject?.class, "terminal")
                            fontSize: workspaceWidget.iconFontSize
                            iconColor: wsItem.active ? Theme.primary : Theme.onSurfaceVariant

                            StateLayer {
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
                                onClicked: Hyprland.dispatch("focuswindow address:" + winIcon.modelData.address)
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
