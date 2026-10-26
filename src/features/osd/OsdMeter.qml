pragma ComponentBehavior: Bound
import QtQuick
import qs.src.core.config

OsdSurface {
    id: root
    property string iconName: ""
    property string title: ""
    property real progress: 0
    property color progressColor: Theme.primary
    cardWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2
    contentComponent: OsdMeterContent {
        title: root.title
        iconName: root.iconName
        progress: root.progress
        progressColor: root.progressColor
    }
}
