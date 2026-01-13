import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.features.statusbar

Item {
    id: root

    required property var widgetConfig
    required property var tooltipManager
    property string screenName
    property var popouts: null

    property string widgetType: (widgetConfig && (widgetConfig.type || widgetConfig["type"])) || ""
    property bool widgetEnabled: !(widgetConfig && (widgetConfig.enabled === false || widgetConfig["enabled"] === false))

    property alias item: loader.item

    implicitWidth: getImplicitSize(loader.item, "implicitWidth")
    implicitHeight: getImplicitSize(loader.item, "implicitHeight")

    visible: widgetEnabled && widgetType !== ""
    // visible: false

    Loader {
        id: loader
        asynchronous: false
        active: root.widgetEnabled && root.widgetType !== "" && Config.shouldShowWidget2(root.widgetConfig, screenName)

        sourceComponent: {
            if (!root.widgetEnabled || root.widgetType === "")
                return null;

            switch (root.widgetType) {
            case "workspaces":
                return workspacesComponent;
            case "media":
                return mprisComponent;
            case "tray":
                return trayComponent;
            case "notifications":
                return notificationsComponent;
            case "volume":
                return volumeComponent;
            case "network":
                return networkComponent;
            case "battery":
                return batteryComponent;
            case "clock":
                return clockComponent;
            case "layout":
                return layoutComponent;
            case "weather":
                return weatherComponent;
            default:
                console.warn("Unknown widget type:", root.widgetType);
                return null;
            }
        }
    }

    function getImplicitSize(item, prop) {
        if (!item)
            return 0;
        const value = item[prop];
        if (value > 0)
            return Math.round(value);
        return Math.round(item[prop === "implicitWidth" ? "width" : "height"] || 0);
    }

    // Widget components
    Component {
        id: workspacesComponent
        WorkspaceWidget {
            widgetConfig: root.widgetConfig
        }
    }

    Component {
        id: mprisComponent
        MPRISWidget {
            widgetConfig: root.widgetConfig
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: trayComponent
        TrayWidget {
            widgetConfig: root.widgetConfig
            tooltipManager: root.tooltipManager
            popouts: root.popouts
        }
    }

    Component {
        id: notificationsComponent
        NotificationWidget {
            widgetConfig: root.widgetConfig
        }
    }

    Component {
        id: volumeComponent
        VolumeWidget {
            widgetConfig: root.widgetConfig
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: networkComponent
        NetworkWidget {
            widgetConfig: root.widgetConfig
        }
    }

    Component {
        id: batteryComponent
        BatteryWidget {
            widgetConfig: root.widgetConfig
        }
    }

    Component {
        id: clockComponent
        ClockWidget {
            widgetConfig: root.widgetConfig
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: layoutComponent
        LayoutWidget {
            widgetConfig: root.widgetConfig
        }
    }

    Component {
        id: weatherComponent
        WeatherWidget {
            widgetConfig: root.widgetConfig
        }
    }
}
