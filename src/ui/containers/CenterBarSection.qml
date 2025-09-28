import QtQuick
import QtQuick.Layouts
import qs.src.core.config

Item {
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

    default property alias children: root.children

    RowLayout {
        id: root
        anchors.centerIn: parent
        spacing: Config.spacing.medium
    }
}
