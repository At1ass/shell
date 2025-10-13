import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.features.background
import qs.src.features.dashboard
import qs.src.features.launcher
import qs.src.features.osd
import qs.src.features.statusbar as Bar

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            property var modelData
            Bar.StatusBar {
                screen: modelData
            }

            PanelWindow {
                id: wallpaperPanel
                screen: modelData

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
}
