pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

Item {
    id: root
    property string iconName: ""
    property string title: ""
    property real progress: 0
    property color progressColor: Theme.primary
    implicitWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2
    implicitHeight: row.implicitHeight + Tokens.spacing.medium * 2
    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.medium
        MaterialIcon { iconName: root.iconName; fontSize: Tokens.iconSize.large; iconColor: root.progressColor }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                MaterialText {
                    Layout.fillWidth: true
                    text: root.title
                    textStyle: "bodyMedium"
                    colorRole: "onSurface"
                    elide: Text.ElideRight
                }
                MaterialText {
                    text: Math.round(root.progress * 100) + "%"
                    textStyle: "labelLarge"
                    color: root.progressColor
                }
            }
            ProgressIndicator {
                Layout.fillWidth: true
                thickness: Tokens.spacing.extraSmall
                value: root.progress
                activeColor: root.progressColor
            }
        }
    }
}
