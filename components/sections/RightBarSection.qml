import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property int customSpacing: Config.spacing.medium

    spacing: customSpacing
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
}
