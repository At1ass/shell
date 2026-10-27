pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.features.overview
import qs.src.features.background
import qs.src.features.audio
import qs.src.features.connections
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
import qs.src.features.polkit
import qs.src.features.recorder
import qs.src.features.cheatsheet
import qs.src.core.config
import qs.src.core.services
import Calendar

ShellRoot {
    // Instantiate side-effect singletons (they exist only for their
    // Connections/Process children, so nothing else references them).
    Component.onCompleted: {
        ServiceBootstrap.init()
        HyprlandWindowService.init()
    }
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
                    color: Theme.surface

                    anchors {
                        left: true
                        top: true
                        right: true
                        bottom: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.namespace: "shell:wallpaper"
                    WlrLayershell.layer: WlrLayer.Background

                    Wallpaper {
                        anchors.fill: parent
                        screen: wallpaperPanel.screen
                    }
                }
            }
        }
    }

    LazyLoader { active: AppConfig.moduleEnabled("overview") && GlobalStates.overviewOpen; Overview {} }

    // Panels below stay loaded once opened, when listed in
    // performance.keepPanelsLoaded. Each is otherwise torn down on close and
    // rebuilt on the next open, and that rebuild blocks the UI thread for its
    // whole duration -- the largest single stall the shell has. The window
    // itself is cheap and already hides on its own open flag; what is being
    // retained is the QML tree inside it. See GlobalStates.panelRetained.
    // Lockscreen is deliberately NOT in this list: see the note on its loader.

    LazyLoader {
        active: AppConfig.moduleEnabled("connections") && (GlobalStates.connectionsOpen || GlobalStates.panelRetained("connections"))
        ConnectionsPanel {}
    }

    LazyLoader {
        active: AppConfig.moduleEnabled("audio") && (GlobalStates.audioOpen || GlobalStates.panelRetained("audio"))
        AudioPanel {}
    }

    // Dashboard
    LazyLoader {
        active: AppConfig.moduleEnabled("dashboard") && (GlobalStates.dashboardOpen || GlobalStates.panelRetained("dashboard"))
        Dashboard {}
    }

    // One passive meter for volume and brightness.
    LazyLoader {
        active: AppConfig.moduleEnabled("osd")
        SystemOSD {}
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
    Binding {
        target: CalendarBackend
        property: "reminderAllDayTime"
        value: AppConfig.calendarReminderAllDayTime
    }
    Connections {
        target: CalendarBackend
        function onErrorOccurred(message) {
            ToastService.error(message)
        }
    }

    // config.json validation results. AppConfig only PUBLISHES them -- the
    // config layer must not reach into services -- so the toast is raised here.
    // Without this a mistyped key is silently ignored and the user is left
    // believing a setting that never applied.
    Connections {
        target: AppConfig
        function onConfigErrorsChanged() {
            const errors = AppConfig.configErrors
            if (errors.length === 0)
                return
            const first = errors[0]
            ToastService.warning(errors.length === 1
                ? `config.json — ${first.path}: ${first.message}`
                : `config.json — ${errors.length} problems, first: ${first.path}: ${first.message}`,
                8000)
        }
    }

    // Launcher
    LazyLoader {
        active: AppConfig.moduleEnabled("launcher") && (GlobalStates.launcherOpen || GlobalStates.panelRetained("launcher"))
        Launcher {}
    }

    // Notification popups
    LazyLoader {
        active: AppConfig.moduleEnabled("notifications")
        NotificationPopupManager {}
    }

    // Notification center
    LazyLoader {
        active: AppConfig.moduleEnabled("notifications") && (GlobalStates.notificationCenterOpen || GlobalStates.panelRetained("notificationCenter"))
        NotificationCenter {}
    }

    // Screenshot region selection overlay
    LazyLoader {
        active: AppConfig.moduleEnabled("screenshot") && ScreenshotService.screenshotOverlayActive
        ScreenshotOverlay {}
    }

    // Lockscreen (WlSessionLock creates surfaces for each screen internally).
    // Gated ONLY on lockscreenActive: destroying an active WlSessionLock
    // sends protocol destroy (NOT unlock_and_destroy), which permanently
    // locks the session with no surfaces to type into. Entering the lock is
    // already module-gated inside GlobalStates.lockSession().
    LazyLoader {
        active: GlobalStates.lockscreenActive
        Lockscreen {}
    }

    // Power menu
    LazyLoader {
        active: AppConfig.moduleEnabled("powerMenu") && (GlobalStates.powerMenuOpen || GlobalStates.panelRetained("powermenu"))
        PowerMenu {}
    }

    // Polkit authentication prompt.
    //
    // `moduleEnabled` is read FIRST on purpose: `&&` short-circuits, so with the
    // module off nothing ever touches PolkitService, the singleton is never
    // constructed, and no agent registers. That matters — see the note in
    // PolkitService: a registered agent that does not prompt breaks
    // authentication for the whole session.
    // Loaded for as long as the module is on, NOT per request: polkit drops
    // `isActive` briefly between prompts, and keying the loader on it tore the
    // dialog down mid-conversation -- taking the "authentication failed" text
    // with it, so a rejected password just silently emptied the field.
    // The window costs nothing while hidden; it maps no surface.
    LazyLoader {
        active: AppConfig.moduleEnabled("polkit")
        PolkitDialog {}
    }

    // Screen recording indicator.
    //
    // `moduleEnabled` is read FIRST so `&&` short-circuits: with the module off
    // RecorderService is never referenced, never constructed, and never polls.
    // With it on, reading `active` here is what constructs the service, which is
    // how detection starts.
    LazyLoader {
        active: AppConfig.moduleEnabled("recorder") && RecorderService.active
        RecordingIndicator {}
    }

    // Cheatsheet overlay
    LazyLoader {
        active: AppConfig.moduleEnabled("cheatsheet") && (GlobalStates.cheatsheetOpen || GlobalStates.panelRetained("cheatsheet"))
        Cheatsheet {}
    }
}
