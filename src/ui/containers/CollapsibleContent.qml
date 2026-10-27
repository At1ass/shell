pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base

// The clipped content and its occupied layout height use one reveal progress.
// Keep the lazy body alive through closing, then release it at zero height.
Item {
    id: root
    property bool expanded: false
    property bool animated: true
    property int spacing: 0
    property alias sourceComponent: body.sourceComponent
    readonly property Item item: body.item as Item
    readonly property real progress: Math.max(0, Math.min(1, root._progress))
    property real _progress: 0
    property bool _ready: false

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight * root.progress
    // A zero-height item would otherwise leave an extra parent-layout gap.
    Layout.topMargin: -root.spacing * (1 - root.progress)
    clip: true

    function settle() {
        if (root._ready) {
            revealAnimation.stop()
            if (root.animated && root.visible && !AppConfig.reduceMotion) {
                revealAnimation.to = root.expanded ? 1 : 0
                if (root._progress !== revealAnimation.to) revealAnimation.start()
                return
            }
        }
        root._progress = root.expanded ? 1 : 0
    }
    onExpandedChanged: settle()
    onAnimatedChanged: if (!animated) settle()
    onVisibleChanged: if (!visible) settle()
    Component.onCompleted: { settle(); root._ready = true }
    MotionAnimation {
        id: revealAnimation
        target: root
        property: "_progress"
        duration: Tokens.motion.duration.medium4
        curve: "emphasized"
    }
    Connections {
        target: AppConfig
        function onReduceMotionChanged() { if (AppConfig.reduceMotion) root.settle() }
    }
    Loader {
        id: body
        active: root.expanded || root.progress > 0
        enabled: root.expanded
        width: root.width
        height: implicitHeight
    }
}
