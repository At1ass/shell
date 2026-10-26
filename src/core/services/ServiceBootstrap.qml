pragma Singleton

import Quickshell

// Background services must exist independently of lazy panels.
Singleton {
    function init() {
        SystemMonitorService.init()
        NightLightService.init()
        IdleInhibitorService.init()
        NotificationDND.init()
        GamingModeService.init()
    }
}
