pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base

// Toast overlay — queued one-at-a-time toasts on the shared OsdSurface
// shell (bottom edge). The queue is bounded: a toast storm drops the
// oldest queued entries instead of growing memory without limit.
OsdSurface {
    id: root

    property var _queue: []
    property string _message: ""
    property string _icon: "info"
    property int _level: ToastService.levelInfo

    readonly property int maxQueue: 16

    namespacePart: "toast"
    edge: "bottom"
    cardColor: _bgColor(_level)

    Connections {
        target: ToastService
        function onToastRequested(message, icon, level, duration) {
            // Fresh array on every write: assigning a `var` property back to
            // itself is not a change notification (reference-equality
            // short-circuit), so anything binding to _queue would never update.
            const next = root._queue.slice()
            if (next.length >= root.maxQueue) next.shift()
            next.push({ message: message, icon: icon, level: level, duration: duration })
            root._queue = next
            if (!root.shown) root._showNext()
        }
    }

    function _showNext() {
        if (_queue.length === 0) return
        const next = _queue.slice()
        const item = next.shift()
        _queue = next
        _message = item.message
        _icon = item.icon
        _level = item.level
        shown = true
        hideTimer.interval = item.duration
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        repeat: false
        onTriggered: {
            root.shown = false
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

    contentComponent: Component {
        Item {
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
