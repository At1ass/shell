pragma Singleton

import Quickshell
import GreeterData 1.0
import qs.src.core.config

Singleton {
    function init() {}
    readonly property string displayName: profile.displayName || SystemMonitorService.userName
    readonly property url iconSource: profile.iconSource
    AccountProfile {
        id: profile
        active: AppConfig.moduleEnabled("dashboard") && AppConfig.dashboardShowAvatar
        username: SystemMonitorService.userName
    }
}
