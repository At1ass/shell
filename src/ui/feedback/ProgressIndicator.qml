import QtQuick
import qs.src.core.config

// Material Design 3 Progress Indicator — linear or circular, determinate or indeterminate.
Item {
    id: root

    property string type: "linear"   // "linear" | "circular"
    property bool indeterminate: false
    property real value: 0.0          // 0..1 (used when !indeterminate)
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
                NumberAnimation {
                    from: -linearFill.width
                    to: linearFill.parent.width
                    duration: Tokens.motion.duration.extraLong2
                    easing.type: Tokens.motion.easing.standard
                    easing.bezierCurve: Tokens.motion.easing.standardPoints
                }
            }

            Behavior on width {
                enabled: !root.indeterminate
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
