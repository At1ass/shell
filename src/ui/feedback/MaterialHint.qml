import QtQuick
import QtQuick.Controls
import qs.src.core.config

ToolTip {
    id: root
    delay: Tokens.interaction.tooltipDelay
    padding: 0
    background: null
    contentItem: MaterialTooltip { text: root.text }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.motion.duration.short2 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Tokens.motion.duration.short2 } }
}
