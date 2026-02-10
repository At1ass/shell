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
import qs.src.core.services

ShellRoot {
    readonly property var _hws: HyprlandWindowService
    Popouts.Popouts {
        id: globalPopouts
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property ShellScreen modelData

            Bar.StatusBar {
                id: statusBar
                screen: screenScope.modelData
                popouts: globalPopouts
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
        loading: true
        Dashboard {}
    }

    // Volume OSD
    LazyLoader {
        loading: true
        VolumeOSD {}
    }

    // Launcher
    LazyLoader {
        loading: true
        Launcher {}
    }

    // Notification popups
    LazyLoader {
        loading: true
        NotificationPopup {}
    }

    // Notification center
    LazyLoader {
        loading: true
        NotificationCenter {}
    }
}
