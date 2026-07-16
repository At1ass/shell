import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base

Scope {
    property var modelData

    readonly property var actions: [
        { icon: "lock",                label: "Lock",     action: "lock",     key: "L" },
        { icon: "dark_mode",           label: "Suspend",  action: "suspend",  key: "S" },
        { icon: "restart_alt",         label: "Reboot",   action: "reboot",   key: "R" },
        { icon: "power_settings_new",  label: "Shutdown", action: "shutdown", key: "D" },
        { icon: "logout",              label: "Logout",   action: "logout",   key: "O" }
    ]

    PanelWindow {
        id: menuWindow
        visible: GlobalStates.powerMenuOpen
        color: "transparent"
        exclusiveZone: 0
        focusable: true

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: focusGrab
            windows: [menuWindow]
            active: GlobalStates.powerMenuOpen

            onCleared: {
                GlobalStates.closePanel("powermenu")
            }
        }

        // Keyboard focus state
        property int focusedIndex: 0

        onVisibleChanged: {
            if (visible) {
                focusedIndex = 0
                // Reset all confirm states
                for (let i = 0; i < actionsRepeater.count; i++) {
                    let item = actionsRepeater.itemAt(i)
                    if (item) item.confirming = false
                }
            }
        }

        // Keyboard focus root
        Item {
            id: keyboardRoot
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: GlobalStates.closePanel("powermenu")

            Keys.onLeftPressed: {
                menuWindow.focusedIndex = (menuWindow.focusedIndex - 1 + actions.length) % actions.length
            }
            Keys.onRightPressed: {
                menuWindow.focusedIndex = (menuWindow.focusedIndex + 1) % actions.length
            }
            Keys.onTabPressed: {
                menuWindow.focusedIndex = (menuWindow.focusedIndex + 1) % actions.length
            }

            Keys.onReturnPressed: menuWindow.activateFocused()
            Keys.onEnterPressed: menuWindow.activateFocused()

            Keys.onPressed: event => {
                let key = event.text.toUpperCase()
                for (let i = 0; i < actions.length; i++) {
                    if (actions[i].key === key) {
                        menuWindow.focusedIndex = i
                        let item = actionsRepeater.itemAt(i)
                        if (item) item.activate()
                        event.accepted = true
                        return
                    }
                }
            }
        }

        // Scrim
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: GlobalStates.powerMenuOpen ? 0.5 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium2
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.closePanel("powermenu")
            }
        }

        // Center content
        Item {
            anchors.centerIn: parent
            width: actionsRow.width
            height: actionsRow.height

            opacity: GlobalStates.powerMenuOpen ? 1.0 : 0.0
            scale: GlobalStates.powerMenuOpen ? 1.0 : 0.9

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Tokens.motion.easing.emphasizedDecelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Tokens.motion.duration.medium4
                    easing.type: Tokens.motion.easing.emphasizedDecelerate
                    easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                }
            }

            // Block click-through
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: actionsRow
                spacing: Tokens.spacing.extraLarge + Tokens.spacing.medium

                Repeater {
                    id: actionsRepeater
                    model: actions

                    delegate: ColumnLayout {
                        id: actionDelegate
                        required property var modelData
                        required property int index
                        property bool confirming: false
                        property bool focused: menuWindow.focusedIndex === index
                        property bool hovered: delegateMouseArea.containsMouse

                        spacing: Tokens.spacing.medium

                        // Whole-delegate mouse area for hover tracking
                        MouseArea {
                            id: delegateMouseArea
                            Layout.preferredWidth: buttonContainer.width
                            Layout.preferredHeight: buttonContainer.height + labelText.height + actionDelegate.spacing + hotkeyText.height + Tokens.spacing.extraSmall
                            Layout.alignment: Qt.AlignHCenter
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: menuWindow.focusedIndex = actionDelegate.index
                            onClicked: actionDelegate.activate()

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: actionDelegate.spacing

                                // Icon container
                                Rectangle {
                                    id: buttonContainer
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 96
                                    Layout.preferredHeight: 96
                                    radius: Tokens.shape.extraLarge

                                    color: {
                                        if (actionDelegate.confirming) return Theme.primary
                                        if (actionDelegate.focused) return Theme.secondaryContainer
                                        return Qt.alpha(Theme.surfaceContainerHigh, 0.6)
                                    }

                                    border.width: actionDelegate.focused && !actionDelegate.confirming ? 2 : 0
                                    border.color: Theme.primary

                                    scale: actionDelegate.focused ? 1.08 : 1.0
                                    layer.enabled: scale !== 1.0
                                    layer.smooth: true

                                    Behavior on color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Tokens.motion.duration.short4
                                            easing.type: Tokens.motion.easing.emphasizedDecelerate
                                            easing.bezierCurve: Tokens.motion.easing.emphasizedDeceleratePoints
                                        }
                                    }
                                    Behavior on border.width {
                                        NumberAnimation { duration: Tokens.motion.duration.short4 }
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: actionDelegate.confirming ? "check" : actionDelegate.modelData.icon
                                        fontSize: 40
                                        iconColor: {
                                            if (actionDelegate.confirming) return Theme.onPrimary
                                            if (actionDelegate.focused) return Theme.onSecondaryContainer
                                            return Qt.alpha(Theme.scrimForeground, 0.8)
                                        }
                                        backgroundColor: "transparent"

                                        Behavior on iconColor {
                                            ColorAnimation { duration: Tokens.motion.duration.short4 }
                                        }
                                    }
                                }

                                // Label
                                MaterialText {
                                    id: labelText
                                    Layout.alignment: Qt.AlignHCenter
                                    text: actionDelegate.confirming ? "Confirm?" : actionDelegate.modelData.label
                                    textStyle: "titleSmall"
                                    color: {
                                        if (actionDelegate.confirming) return Theme.primary
                                        if (actionDelegate.focused) return Theme.scrimForeground
                                        return Qt.alpha(Theme.scrimForeground, 0.7)
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                                    }
                                }

                                // Hotkey hint
                                MaterialText {
                                    id: hotkeyText
                                    Layout.alignment: Qt.AlignHCenter
                                    text: actionDelegate.modelData.key
                                    textStyle: "labelSmall"
                                    color: actionDelegate.focused ? Qt.alpha(Theme.scrimForeground, 0.5) : Qt.alpha(Theme.scrimForeground, 0.25)

                                    Behavior on color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                                    }
                                }
                            }
                        }

                        Timer {
                            id: confirmTimer
                            interval: 3000
                            onTriggered: actionDelegate.confirming = false
                        }

                        function activate() {
                            let act = modelData.action
                            let needsConfirm = AppConfig.powerMenuConfirmActions
                                && (act === "reboot" || act === "shutdown" || act === "logout")

                            if (needsConfirm && !confirming) {
                                confirming = true
                                confirmTimer.restart()
                            } else {
                                GlobalStates.executePowerAction(act)
                            }
                        }
                    }
                }
            }
        }

        function activateFocused() {
            let item = actionsRepeater.itemAt(focusedIndex)
            if (item) item.activate()
        }
    }
}
