import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.features.background
import qs.src.features.dashboard
import qs.src.features.launcher
import qs.src.features.osd
import qs.src.features.notifications
import qs.src.features.statusbar as Bar
import qs.src.features.popouts as Popouts
import qs.src.features.screenshot
import qs.src.features.lockscreen
import qs.src.features.powermenu
import qs.src.features.cheatsheet
import qs.src.core.services

ShellRoot {
    readonly property var _hws: HyprlandWindowService
    Popouts.Popouts {
        id: globalPopouts
        Component.onCompleted: PopoutsState.popoutsInstance = globalPopouts
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property ShellScreen modelData

            Bar.StatusBar {
                id: statusBar
                screen: screenScope.modelData
            }

            // Popouts.PopoutsScrim {
            //     screen: screenScope.modelData
            // }

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

    // Dashboard
    LazyLoader {
        loading: GlobalStates.dashboardOpen
        Dashboard {}
    }

    // Volume OSD
    LazyLoader {
        loading: true
        VolumeOSD {}
    }

    // Brightness OSD
    LazyLoader {
        loading: true
        BrightnessOSD {}
    }

    // Toast notifications
    ToastOverlay {}

    // Launcher
    LazyLoader {
        loading: GlobalStates.launcherOpen
        Launcher {}
    }

    // Notification popups
    NotificationPopupManager {}

    // Notification center
    LazyLoader {
        loading: GlobalStates.notificationCenterOpen
        NotificationCenter {}
    }

    // Screenshot region selection overlay
    LazyLoader {
        loading: ScreenshotService.screenshotOverlayActive
        ScreenshotOverlay {}
    }

    // Lockscreen (WlSessionLock creates surfaces for each screen internally)
    LazyLoader {
        loading: GlobalStates.lockscreenActive
        Lockscreen {}
    }

    // Power menu
    LazyLoader {
        loading: GlobalStates.powerMenuOpen
        PowerMenu {}
    }

    // Cheatsheet overlay
    LazyLoader {
        loading: GlobalStates.cheatsheetOpen
        Cheatsheet {}
    }
}
