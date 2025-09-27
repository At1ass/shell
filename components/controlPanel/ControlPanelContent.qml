import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.components.base
import qs.services
import qs.components.controlPanel.components
import "." as Panel

MaterialCard {
    id: root

    property int currentTab: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        TopSection {
        }

        MiddleSection {
            currentTab: root.currentTab
            onCurrentTabChanged: root.currentTab = currentTab
        }

        BottomSection {
        }
    }
}
