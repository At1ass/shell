import QtQuick
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Progress Indicator — linear or circular, determinate or indeterminate.
Item {
    id: root

    property string type: "linear"   // "linear" | "circular"
    property bool indeterminate: false
    property real value: 0.0          // 0..1 (used when !indeterminate)
    // Smooth discrete value changes. Set FALSE when the caller already drives
    // `value` from a running animation (a notification's countdown, a live
    // meter): a second Behavior on top of a continuous source lags behind it
    // and smears the bar. Having this as a parameter is why a caller in that
    // situation no longer needs to hand-roll the whole component.
    property bool animateValue: true
    property color activeColor: Theme.primary
    property color trackColor: Theme.surfaceContainerHighest
    property int thickness: 4
    property int circularSize: 48

    readonly property real _clamped: Math.max(0, Math.min(1, value))

    implicitWidth: type === "circular" ? circularSize : 200
    implicitHeight: type === "circular" ? circularSize : thickness

    // ---- Linear ----
    Rectangle {
        visible: root.type === "linear"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.thickness
        radius: height / 2
        color: root.trackColor
        clip: true

        Rectangle {
            id: linearFill
            height: parent.height
            radius: height / 2
            color: root.activeColor
            width: root.indeterminate ? parent.width * 0.3
                                      : parent.width * root._clamped

            SequentialAnimation on x {
                running: root.visible && root.type === "linear" && root.indeterminate && Tokens.durationScale > 0
                loops: Animation.Infinite
                MotionAnimation {
                    from: -linearFill.width
                    to: linearFill.parent.width
                    duration: Tokens.motion.duration.extraLong2
                    curve: "standard"
                }
            }

            Behavior on width {
                enabled: root.animateValue && !root.indeterminate
                NumberAnimation { duration: Tokens.motion.duration.medium2 }
            }
        }
    }

    // ---- Circular ----
    Canvas {
        id: circ
        visible: root.type === "circular"
        anchors.fill: parent

        readonly property real sweep: root.indeterminate ? 0.25 : root._clamped

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const lw = root.thickness
            const r = Math.min(width, height) / 2 - lw / 2
            const cx = width / 2
            const cy = height / 2
            // Track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.lineWidth = lw
            ctx.strokeStyle = root.trackColor
            ctx.stroke()
            // Active arc
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * sweep)
            ctx.lineWidth = lw
            ctx.lineCap = "round"
            ctx.strokeStyle = root.activeColor
            ctx.stroke()
        }

        onSweepChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()

        // Repaint when theme-driven colors change.
        Connections {
            target: root
            function onActiveColorChanged() { circ.requestPaint() }
            function onTrackColorChanged() { circ.requestPaint() }
        }

        RotationAnimation on rotation {
            running: root.visible && root.type === "circular" && root.indeterminate && Tokens.durationScale > 0
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: Tokens.motion.duration.extraLong4
        }
    }
}
