import QtQuick
import qs.src.ui.base
import qs.src.core.config

// System Tray Tooltip
Item {
    id: root
    anchors.fill: parent

    visible: false

    property string tooltipText: ""
    property Item sourceItem: null

    // Public API
    function showTooltip(text, source) {
        root.tooltipText = text
        root.sourceItem = source
        showTimer.start()
    }

    function hideTooltip() {
        showTimer.stop()
        root.visible = false
        tooltipRect.opacity = 0
    }

    // Delay before showing
    Timer {
        id: showTimer
        interval: 500
        onTriggered: {
            root.visible = true
            tooltipRect.opacity = 1
        }
    }

    // Tooltip rectangle
    Rectangle {
        id: tooltipRect
        visible: root.sourceItem !== null && root.tooltipText !== ""

        color: Config.colors.inverseSurface
        radius: Config.shape.extraSmall

        implicitWidth: tooltipTextItem.implicitWidth + Config.spacing.small * 2
        implicitHeight: tooltipTextItem.implicitHeight + Config.spacing.extraSmall * 2

        opacity: 0

        // Position above source item
        x: {
            if (!root.sourceItem) return 0

            const globalPos = root.sourceItem.mapToItem(root, 0, 0)
            const centerX = globalPos.x + root.sourceItem.width / 2
            return centerX - tooltipRect.width / 2
        }

        y: {
            if (!root.sourceItem) return 0

            const globalPos = root.sourceItem.mapToItem(root, 0, 0)
            return globalPos.y - tooltipRect.height - Config.spacing.extraSmall
        }

        Behavior on opacity {
            NumberAnimation { duration: Config.motion.duration.short4 }
        }

        MaterialText {
            id: tooltipTextItem
            anchors.centerIn: parent
            text: root.tooltipText
            textStyle: "bodySmall"
            colorRole: "inverseOnSurface"
        }
    }
}
