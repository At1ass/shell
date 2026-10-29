pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

Item {
    id: root
    implicitHeight: row.implicitHeight
    readonly property bool summaryActive: visible && GlobalStates.dashboardOpen && AppConfig.dashboardShowSystemSummary
    property bool _uptimeRegistered: false
    function syncUptime() {
        if (_uptimeRegistered === summaryActive) return
        _uptimeRegistered = summaryActive
        if (_uptimeRegistered) DateTime.addUptimeWatcher()
        else DateTime.removeUptimeWatcher()
    }
    onSummaryActiveChanged: syncUptime()
    Component.onCompleted: syncUptime()
    Component.onDestruction: if (_uptimeRegistered) DateTime.removeUptimeWatcher()

    RowLayout {
        id: row
        width: parent.width
        spacing: Tokens.spacing.medium
        CircleAvatar {
            objectName: "dashboardAvatar"
            visible: AppConfig.dashboardShowAvatar
            size: "large"
            imageSource: AccountService.iconSource.toString()
            fallbackIcon: "person"
            Accessible.name: "User avatar"
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Tokens.spacing.extraSmall
            MaterialText {
                Layout.fillWidth: true
                visible: AppConfig.dashboardShowAvatar
                text: AccountService.displayName || SystemMonitorService.userName || "User"
                textStyle: "titleMedium"
                elide: Text.ElideRight
            }
            MaterialText {
                objectName: "dashboardSystemSummary"
                Layout.fillWidth: true
                visible: AppConfig.dashboardShowSystemSummary
                text: [SystemMonitorService.osName, SystemMonitorService.wmName].filter(value => value !== "").join(" · ")
                    + (DateTime.uptime ? " · Up " + DateTime.uptime : "")
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                wrapMode: Text.WordWrap
            }
        }
    }
}
