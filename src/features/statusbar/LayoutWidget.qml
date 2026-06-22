import QtQuick
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Layouts
import Quickshell
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: layoutWidget

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    // BarElement configuration
    clickable: true
    hoverable: true
    minWidth: 48
    expandOnHover: false
    animated: true

    // Show only if multiple layouts available
    visible: KeyboardLayoutService.layoutCodes.length > 1

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
        spacing: 2

        MaterialText {
            text: KeyboardLayoutService.currentLayoutCode.toUpperCase() || "EN"
            textStyle: "titleMedium"
            colorRole: "onSurface"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // CapsLock / NumLock indicators
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            MaterialIndicator {
                id: capsIndicator
                size: "extraSmall"
                colorRole: KeyboardLayoutService.capsLockEnabled ? "primary" : "outline"
                shape: "rounded"
                visible: KeyboardLayoutService.capsLockEnabled

                MouseArea {
                    id: capsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    // QtQuick.Controls ToolTip — no tooltipManager available
                    ToolTip {
                        text: "Caps Lock"
                        visible: capsMouseArea.containsMouse
                        delay: 1000
                    }
                }
            }

            MaterialIndicator {
                id: numIndicator
                size: "extraSmall"
                colorRole: KeyboardLayoutService.numLockEnabled ? "secondary" : "outline"
                shape: "rounded"
                visible: KeyboardLayoutService.numLockEnabled

                MouseArea {
                    id: numMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    // QtQuick.Controls ToolTip — no tooltipManager available
                    ToolTip {
                        text: "Num Lock"
                        visible: numMouseArea.containsMouse
                        delay: 1000
                    }
                }
            }
        }
    }
}
