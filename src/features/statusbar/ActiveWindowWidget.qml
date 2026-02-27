import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null

    property int maxWidth: widgetSettings.maxWidth ?? 300
    property bool showIcon: widgetSettings.showIcon ?? true

    // State — tracked from Hyprland IPC events
    property string _windowTitle: ""
    property string _windowClass: ""

    visible: _windowTitle !== ""
    hoverable: true
    clickable: true
    clip: true

    implicitWidth: content.implicitWidth + Tokens.spacing.small * 2

    nonVisualChildren: [
        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (event.name === "activewindow") {
                    // event.data = "class,title" — parse directly for instant update
                    const sep = event.data.indexOf(",")
                    root._windowClass = sep >= 0 ? event.data.substring(0, sep) : ""
                    root._windowTitle = sep >= 0 ? event.data.substring(sep + 1) : ""
                } else if (event.name === "windowtitle") {
                    // Title changed (browser tab switch, etc.) — refetch active window
                    if (!refetchProc.running)
                        refetchProc.running = true
                }
            }
        },

        Process {
            id: refetchProc
            running: false
            command: ["hyprctl", "-j", "activewindow"]

            stdout: StdioCollector {
                id: refetchCollector
                onStreamFinished: {
                    try {
                        const obj = JSON.parse(refetchCollector.text)
                        root._windowTitle = obj.title ?? ""
                        root._windowClass = obj.class ?? root._windowClass
                    } catch (e) {}
                }
            }
        }
    ]

    Component.onCompleted: {
        // Fetch initial active window on load
        if (!refetchProc.running)
            refetchProc.running = true
    }

    clickHandler: function(mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        id: content
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: IconCategoryResolver.getAppCategoryIcon(root._windowClass)
            fontSize: Tokens.typography.titleLarge.size
            iconColor: root.hovered ? Theme.primary : Theme.onSurface
            color: "transparent"
        }

        MaterialText {
            text: root._windowTitle
            textStyle: "bodyMedium"
            colorRole: root.hovered ? "primary" : "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: root.maxWidth
        }
    }
}
