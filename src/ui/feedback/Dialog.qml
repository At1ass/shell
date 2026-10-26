import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Material Design 3 Dialog
Rectangle {
    id: root
    anchors.fill: parent

    // MD3 Scrim (backdrop) - RGBA(0,0,0,0.32)
    color: Qt.alpha(Theme.scrim, Tokens.state.scrimOpacity)

    visible: false
    opacity: 0

    // Properties
    property int dialogWidth: 400
    property int dialogHeight: 400  // Default height
    default property alias content: contentWrapper.children

    // Signals
    signal opened()
    signal closed()

    // MD3 animation
    Behavior on opacity {
        MotionAnimation {
            duration: Tokens.motion.duration.short4
            curve: "emphasizedDecelerate"
        }
    }

    // Scrim click to close — goes through requestClose() so subclasses
    // can intercept (e.g. confirm-on-discard).
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    // Dialog container
    MaterialCard {
        id: dialogCard
        anchors.centerIn: parent

        // A dialog here lives inside a PANEL, not a screen. The dashboard is a
        // fixed 640 tall and its tab area is smaller still, so a card asking for
        // 640 hangs off the bottom and the panel clips it — the event editor lost
        // the bottom of its form that way. Clamping costs nothing: EventDialog
        // scrolls its form, and every other dialog asks for 240 or less.
        readonly property int _inset: Tokens.spacing.large * 2
        // max(0, ...) because root has no size for the first binding pass and a
        // negative width is a warning, not a clamp.
        width: Math.max(0, Math.min(root.dialogWidth, root.width - _inset))
        height: Math.max(0, Math.min(root.dialogHeight, root.height - _inset))

        color: Theme.surfaceContainerHigh
        radius: Tokens.shape.extraLarge

        // Scale animation (MD3 spec: 0.8 → 1.0)
        scale: root.opacity * 0.2 + 0.8

        Behavior on scale {
            MotionAnimation {
                duration: Tokens.motion.duration.short4
                curve: "emphasizedDecelerate"
            }
        }

        // Block clicks from propagating to scrim
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Content wrapper
        Item {
            id: contentWrapper
            width: parent.width
            height: parent.height
        }
    }

    property Item _previousFocus: null
    readonly property bool modalFocusBoundary: true
    readonly property bool _ownsFocus: {
        for (let current = root.Window.window?.activeFocusItem; current; current = current.parent) {
            if (current === root) return true
            if (current["modalFocusBoundary"] === true) return false
        }
        return false
    }

    // Native editors consume Tab before it can bubble to a parent Keys handler.
    // Window shortcuts intercept that step; only the nearest modal owns them.
    Shortcut {
        sequence: "Tab"
        context: Qt.WindowShortcut
        enabled: root.visible && root._ownsFocus
        onActivated: root._cycleFocus(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        context: Qt.WindowShortcut
        enabled: root.visible && root._ownsFocus
        onActivated: root._cycleFocus(true)
    }

    function _owns(item) {
        for (let current = item; current; current = current.parent)
            if (current === root) return true
        return false
    }

    function _cycleFocus(backwards) {
        const current = root.Window.window?.activeFocusItem ?? contentWrapper
        let next = current.nextItemInFocusChain(!backwards)
        const start = next
        while (next) {
            if (root._owns(next) && next.visible && next.enabled && next.activeFocusOnTab) {
                next.forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason)
                return
            }
            next = next.nextItemInFocusChain(!backwards)
            if (next === start) break
        }
        root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (!root.visible) return
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root._cycleFocus(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier))
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.requestClose()
            event.accepted = true
        }
    }

    // Public API
    function open() {
        // A pending close (scrim dismiss + immediate reopen) would hide the
        // freshly opened dialog when its 200 ms timer fired.
        closeTimer.stop()
        root._previousFocus = root.Window.window?.activeFocusItem ?? null
        root.visible = true
        root.opacity = 1
        root._cycleFocus(false)
        opened()
    }

    function close() {
        root.opacity = 0
        closeTimer.start()
    }

    // Subclasses can override to add a confirm step. Default just closes.
    function requestClose() { close() }

    Timer {
        id: closeTimer
        interval: Tokens.motion.duration.short4
        onTriggered: {
            const shouldRestore = root._owns(root.Window.window?.activeFocusItem)
            root.visible = false
            if (shouldRestore) {
                if (root._previousFocus?.visible && root._previousFocus.enabled)
                    root._previousFocus.forceActiveFocus(Qt.OtherFocusReason)
                else if (root.parent) root.parent.forceActiveFocus(Qt.OtherFocusReason)
            }
            root._previousFocus = null
            root.closed()
        }
    }
}
