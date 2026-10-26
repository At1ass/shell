import QtQuick
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.services

BarElement {
    id: layoutWidget

    property var tooltipManager: null
    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    // BarElement configuration
    clickable: true
    hoverable: true
    minWidth: Tokens.size.control
    expandOnHover: false
    animated: true

    // Show only if multiple layouts available
    property bool shown: KeyboardLayoutService.layoutCodes.length > 1

    // This widget is the only thing that displays CapsLock/NumLock, and the
    // service can only learn them by polling (Hyprland emits no event). Hold a
    // watcher so the poll exists exactly while something shows its result.
    Component.onCompleted: KeyboardLayoutService.addLockStateWatcher()
    Component.onDestruction: KeyboardLayoutService.removeLockStateWatcher()

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            KeyboardLayoutService.switchLayout()
            mouse.accepted = true
            return
        }

        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    Column {
        spacing: Tokens.spacing.extraSmall / 2

        MaterialText {
            text: KeyboardLayoutService.currentLayoutCode.toUpperCase() || "EN"
            textStyle: "titleMedium"
            colorRole: "onSurface"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // CapsLock / NumLock indicators
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.extraSmall / 2

            MaterialIndicator {
                id: capsIndicator
                animated: layoutWidget.animationsActive
                size: "extraSmall"
                colorRole: KeyboardLayoutService.capsLockEnabled ? "primary" : "outline"
                shape: "rounded"
                visible: KeyboardLayoutService.capsLockEnabled

                MouseArea {
                    id: capsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    TooltipItem {
                        tooltip: layoutWidget.tooltipManager
                        owner: capsIndicator
                        show: capsMouseArea.containsMouse && layoutWidget.barRevealed
                        text: "Caps Lock"
                    }
                }
            }

            MaterialIndicator {
                id: numIndicator
                animated: layoutWidget.animationsActive
                size: "extraSmall"
                colorRole: KeyboardLayoutService.numLockEnabled ? "secondary" : "outline"
                shape: "rounded"
                visible: KeyboardLayoutService.numLockEnabled

                MouseArea {
                    id: numMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    TooltipItem {
                        tooltip: layoutWidget.tooltipManager
                        owner: numIndicator
                        show: numMouseArea.containsMouse && layoutWidget.barRevealed
                        text: "Num Lock"
                    }
                }
            }
        }
    }
}
