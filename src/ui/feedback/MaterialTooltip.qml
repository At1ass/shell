import QtQuick
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Passive tooltip surface, shared by bar popups and in-window dock hints.
Surface {
    id: root
    property string text: ""
    property real maximumWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2

    property real maximumHeight: Tokens.size.listItem * 8

    FontMetrics { id: metrics; font: label.font }
    color: Theme.inverseSurface
    radius: Tokens.shape.extraSmall
    implicitWidth: Math.min(label.implicitWidth + Tokens.spacing.small * 2, maximumWidth)
    implicitHeight: Math.min(maximumHeight, label.implicitHeight + Tokens.spacing.small * 2)
    Accessible.role: Accessible.ToolTip
    Accessible.name: text

    MaterialText {
        id: label
        x: Tokens.spacing.small
        y: Tokens.spacing.small
        width: Math.max(0, root.width - Tokens.spacing.small * 2)
        text: root.text
        textFormat: Text.PlainText
        textStyle: "bodySmall"
        colorRole: "inverseOnSurface"
        wrapMode: Text.Wrap
        maximumLineCount: Math.max(1, Math.min(8,
            Math.floor((root.maximumHeight - Tokens.spacing.small * 2) / metrics.lineSpacing)))
        elide: Text.ElideRight
    }
}
