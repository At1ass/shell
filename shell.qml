import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.features.background
import qs.src.features.dashboard
import qs.src.features.launcher
import qs.src.features.osd
import qs.src.features.notifications
import qs.src.features.statusbar as Bar
import qs.src.features.dock as DockFeature
import qs.src.features.popouts as Popouts
import qs.src.features.screenshot
import qs.src.features.lockscreen
import qs.src.features.powermenu
import qs.src.features.cheatsheet
import qs.src.core.config
import qs.src.core.services
import Calendar

ShellRoot {
    // Instantiate side-effect singletons (they exist only for their
    // Connections/Process children, so nothing else references them).
    Component.onCompleted: HyprlandWindowService.init()
    LazyLoader {
        active: AppConfig.moduleEnabled("popouts")
        Popouts.Popouts {}
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property ShellScreen modelData

            LazyLoader {
                active: AppConfig.moduleEnabled("bar")
                Bar.StatusBar {
                    id: statusBar
                    screen: screenScope.modelData
                }
            }

            // Dock (per screen)
            LazyLoader {
                active: AppConfig.moduleEnabled("dock")
                DockFeature.Dock {
                    screen: screenScope.modelData
                }
            }

            // Wallpaper (per screen)
            LazyLoader {
                active: AppConfig.moduleEnabled("wallpaper")
                PanelWindow {
                    id: wallpaperPanel
                    screen: screenScope.modelData

                    anchors {
                        left: true
                        top: true
                        right: true
                        bottom: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "shell:wallpaper"
                    WlrLayershell.layer: WlrLayershell.Background

                    Wallpaper {
                        anchors.fill: parent
                        screen: wallpaperPanel.screen
                    }
                }
            }
        }
    }

    // Dashboard
    LazyLoader {
        active: AppConfig.moduleEnabled("dashboard") && GlobalStates.dashboardOpen
        Dashboard {}
    }

    // Volume OSD
    LazyLoader {
        active: AppConfig.moduleEnabled("osd")
        VolumeOSD {}
    }

    // Brightness OSD
    LazyLoader {
        active: AppConfig.moduleEnabled("osd")
        BrightnessOSD {}
    }

    // Toast notifications
    LazyLoader {
        active: AppConfig.moduleEnabled("toasts")
        ToastOverlay {}
    }

    // Calendar plugin: bootstrap reminders config and surface errors
    Binding {
        target: CalendarBackend
        property: "remindersEnabled"
        value: AppConfig.calendarRemindersEnabled
    }
    Binding {
        target: CalendarBackend
        property: "reminderMinutes"
        value: AppConfig.calendarReminderMinutes
    }
    Binding {
        target: CalendarBackend
        property: "reminderLookaheadDays"
        value: AppConfig.calendarReminderLookaheadDays
    }
    Connections {
        target: CalendarBackend
        function onErrorOccurred(message) {
            ToastService.error(message)
        }
    }

    // Launcher
    LazyLoader {
        active: AppConfig.moduleEnabled("launcher") && GlobalStates.launcherOpen
        Launcher {}
    }

    // Notification popups
    LazyLoader {
        active: AppConfig.moduleEnabled("notifications")
        NotificationPopupManager {}
    }

    // Notification center
    LazyLoader {
        active: AppConfig.moduleEnabled("notifications") && GlobalStates.notificationCenterOpen
        NotificationCenter {}
    }

    // Screenshot region selection overlay
    LazyLoader {
        active: AppConfig.moduleEnabled("screenshot") && ScreenshotService.screenshotOverlayActive
        ScreenshotOverlay {}
    }

    // Lockscreen (WlSessionLock creates surfaces for each screen internally)
    LazyLoader {
        active: AppConfig.moduleEnabled("lockscreen") && GlobalStates.lockscreenActive
        Lockscreen {}
    }

    // Power menu
    LazyLoader {
        active: AppConfig.moduleEnabled("powerMenu") && GlobalStates.powerMenuOpen
        PowerMenu {}
    }

    // Cheatsheet overlay
    LazyLoader {
        active: AppConfig.moduleEnabled("cheatsheet") && GlobalStates.cheatsheetOpen
        Cheatsheet {}
    }
}
