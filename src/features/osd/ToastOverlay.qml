pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

Scope {
    id: root

    property var _queue: []
    property bool _visible: false
    property string _message: ""
    property string _icon: "info"
    property int _level: ToastService.levelInfo

    Connections {
        target: ToastService
        function onToastRequested(message, icon, level, duration) {
            root._queue.push({ message: message, icon: icon, level: level, duration: duration })
            root._queue = root._queue
            if (!root._visible) root._showNext()
        }
    }

    function _showNext() {
        if (_queue.length === 0) return
        const item = _queue.shift()
        _queue = _queue
        _message = item.message
        _icon = item.icon
        _level = item.level
        _visible = true
        hideTimer.interval = item.duration
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        repeat: false
        onTriggered: {
            root._visible = false
            root._showNext()
        }
    }

    function _bgColor(level) {
        switch (level) {
            case ToastService.levelSuccess: return Theme.primaryContainer
            case ToastService.levelWarning: return Theme.tertiaryContainer
            case ToastService.levelError:   return Theme.errorContainer
            default:                        return Theme.surfaceContainerHigh
        }
    }

    function _fgColor(level) {
        switch (level) {
            case ToastService.levelSuccess: return Theme.onPrimaryContainer
            case ToastService.levelWarning: return Theme.onTertiaryContainer
            case ToastService.levelError:   return Theme.onErrorContainer
            default:                        return Theme.onSurface
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: toastWindow
            required property var modelData

            visible: root._visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:toast"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { bottom: true; left: false; right: false; top: false }
            margins { bottom: 48 }

            implicitWidth: toastCard.implicitWidth
            implicitHeight: toastCard.implicitHeight

            Item {
                width: toastCard.implicitWidth
                height: toastCard.implicitHeight

                opacity: root._visible ? 1 : 0
                scale: root._visible ? 1 : 0.92

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                        easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                        easing.bezierCurve: Tokens.motion.easing.emphasizedPoints
                    }
                }

                MaterialCard {
                    id: toastCard
                    color: root._bgColor(root._level)
                    radius: Tokens.shape.extraLarge
                    implicitWidth: toastRow.implicitWidth + Tokens.spacing.large * 2
                    implicitHeight: toastRow.implicitHeight + Tokens.spacing.medium * 2

                    RowLayout {
                        id: toastRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: root._icon
                            fontSize: Tokens.typography.titleMedium.size
                            iconColor: root._fgColor(root._level)
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            text: root._message
                            textStyle: "bodyMedium"
                            color: root._fgColor(root._level)
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
}
