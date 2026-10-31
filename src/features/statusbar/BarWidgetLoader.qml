// Bound, because every widget Component below reaches `root` across a Component
// boundary. Unbound that resolves through the dynamic context — it happens to
// work, but nothing checks it. Bound makes the capture lexical and verifiable.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.core.config
import qs.src.features.statusbar

Item {
    id: root

    required property var widgetConfig
    required property var tooltipManager
    required property bool barRevealed
    property string widgetKey: ""
    property bool adaptiveHidden: false
    property bool adaptiveCompact: false
    property Item overflowAnchor: null
    readonly property bool eligible: widgetEnabled && widgetType !== "" && loader.active && root.widgetShown(loader.item)
    readonly property string displayName: ({clock:"Clock",workspaces:"Workspaces",activewindow:"Active window",media:"Media",weather:"Weather",volume:"Audio",network:"Connections",battery:"Battery",layout:"Keyboard layout",notifications:"Notifications",tray:"Applications"})[widgetType] ?? widgetType
    function attention(widget) { return widget?.needsAttention ?? false }
    readonly property real normalWidth: preferredMeasurement(loader.item)
    readonly property real normalMinimum: metric(loader.item,"minimumWidth",normalWidth)
    readonly property real compactWidth: metric(loader.item,"compactWidth",normalMinimum)
    readonly property real compactMinimum: metric(loader.item,"compactMinimumWidth",compactWidth)
    function preferredMeasurement(widget) {
        if (widget?.preferredWidth !== undefined) return metric(widget,"preferredWidth",0)
        return getImplicitSize(widget,"implicitWidth")
    }
    function metric(widget,name,fallback) { return Math.ceil(Math.max(0,widget?.[name] ?? fallback)) }
    function measure(section,order) {
        const automatic = widgetConfig?.priority === undefined || widgetConfig?.priority === null
        const compactOrder = {weather:10,clock:20,network:30,volume:40,media:50,tray:60,workspaces:70,battery:80}
        return {key:widgetKey,section:section,order:order,widget:root,
            minimum:normalMinimum,preferred:Math.max(normalMinimum,normalWidth),
            compactMinimum:Math.min(normalMinimum,compactMinimum),compactPreferred:Math.max(compactMinimum,compactWidth),
            priority:automatic && widgetType==="battery" && attention(loader.item) ? 95 : AppConfig.barWidgetPriority(widgetConfig),compactPriority:compactOrder[widgetType] ?? 90}
    }
    Layout.fillWidth: true
    Layout.minimumWidth: adaptiveCompact ? compactMinimum : normalMinimum
    Layout.preferredWidth: adaptiveCompact ? compactWidth : normalWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.alignment: Qt.AlignVCenter
    Binding { target: loader.item as BarElement; property: "compactPresentation"; value: root.adaptiveCompact }
    Binding { target: loader.item as BarElement; property: "defaultAccessibleName"; value: root.displayName }
    Binding { target: loader.item as BarElement; property: "actionAnchor"; value: root.adaptiveHidden ? root.overflowAnchor : loader.item }
    property string screenName

    property string widgetType: (widgetConfig && (widgetConfig.type || widgetConfig["type"])) || ""
    property bool widgetEnabled: !(widgetConfig && (widgetConfig.enabled === false || widgetConfig["enabled"] === false))

    property alias item: loader.item

    implicitWidth: adaptiveCompact ? compactWidth : normalWidth
    implicitHeight: getImplicitSize(loader.item, "implicitHeight")

    // Follow the loaded widget's own `shown` contract property: RowLayout
    // only skips its DIRECT child, so a self-hidden widget (no player / no
    // window / one layout) left a full-width phantom gap otherwise.
    // NOTE: item.visible must NOT be read here — QQuickItem.visible reads
    // back EFFECTIVE visibility, and with the loader initially hidden that
    // binding self-locks at false (empty bar).
    visible: root.eligible && !root.adaptiveHidden
    enabled: root.eligible && !root.adaptiveHidden

    function widgetShown(widget) { return widget?.shown ?? true }

    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: false
        active: root.widgetEnabled && root.widgetType !== "" && AppConfig.shouldShowOnMonitor(root.widgetConfig, root.screenName)

        sourceComponent: {
            if (!root.widgetEnabled || root.widgetType === "")
                return null;

            switch (root.widgetType) {
            case "workspaces":
                return workspacesComponent;
            case "activewindow":
                return activeWindowComponent;
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
        id: activeWindowComponent
        ActiveWindowWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: workspacesComponent
        WorkspaceWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: mprisComponent
        MPRISWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: trayComponent
        TrayWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: notificationsComponent
        NotificationWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
        }
    }

    Component {
        id: volumeComponent
        VolumeWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: networkComponent
        NetworkWidget {
            tooltipManager: root.tooltipManager
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
        }
    }

    Component {
        id: batteryComponent
        BatteryWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
        }
    }

    Component {
        id: clockComponent
        ClockWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
            tooltipManager: root.tooltipManager
        }
    }

    Component {
        id: layoutComponent
        LayoutWidget {
            tooltipManager: root.tooltipManager
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
        }
    }

    Component {
        id: weatherComponent
        WeatherWidget {
            widgetConfig: root.widgetConfig
            barRevealed: root.barRevealed && !root.adaptiveHidden
        }
    }
}
