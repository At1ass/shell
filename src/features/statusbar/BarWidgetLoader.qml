import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.features.statusbar

// Loader {
Loader {
    id: loader

    required property var widgetConfig
    required property var tooltipManager

    property string widgetType: widgetConfig.type || ""
    property bool widgetEnabled: widgetConfig.enabled !== false

    anchors.fill: parent
    visible: widgetEnabled && widgetType !== ""

    sourceComponent: {
        if (!widgetEnabled || widgetType === "") return null

        switch (widgetType) {
            case "workspaces":
                return workspacesComponent
            case "media":
                return mprisComponent
            case "tray":
                return trayComponent
            case "notifications":
                return notificationsComponent
            case "volume":
                return volumeComponent
            case "network":
                return networkComponent
            case "battery":
                return batteryComponent
            case "clock":
                return clockComponent
            case "layout":
                return layoutComponent
            default:
                console.warn("Unknown widget type:", widgetType)
                return null
        }
    }

    // Widget components
    Component {
        id: workspacesComponent
        WorkspaceWidget {}
    }

    Component {
        id: mprisComponent
        MPRISWidget {
            tooltipManager: loader.tooltipManager
        }
    }

    Component {
        id: trayComponent
        Item {
            // TODO: TrayWidget not yet implemented
            visible: false
        }
    }

    Component {
        id: notificationsComponent
        NotificationWidget {}
    }

    Component {
        id: volumeComponent
        VolumeWidget {
            tooltipManager: loader.tooltipManager
        }
    }

    Component {
        id: networkComponent
        Item {
            // TODO: NetworkWidget not yet implemented
            visible: false
        }
    }

    Component {
        id: batteryComponent
        Item {
            // TODO: BatteryWidget not yet implemented
            visible: false
        }
    }

    Component {
        id: clockComponent
        ClockWidget {
            tooltipManager: loader.tooltipManager
        }
    }

    Component {
        id: layoutComponent
        LayoutWidget {}
    }
}
