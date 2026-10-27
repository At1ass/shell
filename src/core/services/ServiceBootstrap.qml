pragma Singleton

import Quickshell

// Background services must exist independently of lazy panels.
Singleton {
    function init() {
        NetworkAuthService.init()
        VPNService.init()
        SystemMonitorService.init()
        NightLightService.init()
        IdleInhibitorService.init()
        NotificationDND.init()
        GamingModeService.init()
    }
}
