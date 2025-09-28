import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base
import qs.src.core.services
import qs.src.features.controlPanel.components
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
