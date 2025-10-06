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
    // property bool showDateSelector: false

    color: Config.colors.surface

    // Global overlay to close date selector when clicking anywhere
    MouseArea {
        anchors.fill: parent
        visible: GlobalStates.showDateSelector
        onClicked: function (mouse) {
            console.log("Global overlay clicked - closing date selector");
            GlobalStates.showDateSelector = false;
        }
        propagateComposedEvents: true
    }

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
