pragma Singleton

import Quickshell

// Background services must exist independently of lazy panels.
Singleton {
    function init() {
        AudioService.init()
        MprisController.init()
        ActiveWindowService.init()
        NetworkAuthService.init()
        VPNService.init()
        SystemMonitorService.init()
        AccountService.init()
        NightLightService.init()
        IdleInhibitorService.init()
        NotificationDND.init()
        TimerService.init()
        PowerService.init()
        GamingModeService.init()
    }
}
