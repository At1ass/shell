pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    hoverable: true
    clickable: false
    minWidth: Tokens.size.control
    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null
    property int iconSize: widgetSettings.iconSize ?? 20
    property int itemSpacing: widgetSettings.spacing ?? Tokens.spacing.small
    property int maxVisible: widgetSettings.maxVisible ?? 4
    property list<string> pinnedIds: widgetSettings.pinnedIds ?? []
    function modelValues(model) { return model?.values ?? [] }
    readonly property list<SystemTrayItem> trayItems: root.modelValues(SystemTray.items)
    readonly property bool needsAttention: trayItems.some(item=>item.status===Status.NeedsAttention)
    readonly property bool shown: root.trayItems.length > 0
    readonly property int normalCount: AppConfig.moduleEnabled("popouts") ? Math.min(maxVisible, trayItems.length) : trayItems.length
    readonly property bool normalOverflow: normalCount < trayItems.length
    preferredWidth: Math.max(minWidth, normalCount * (iconSize + Tokens.spacing.extraSmall * 2)
        + (normalOverflow ? overflowButton.implicitWidth : 0)
        + Math.max(0, normalCount + Number(normalOverflow) - 1) * itemSpacing + Tokens.spacing.medium)
    minimumWidth: preferredWidth
    compactWidth: AppConfig.moduleEnabled("popouts") ? overflowButton.implicitWidth + Tokens.spacing.medium : preferredWidth
    readonly property TrayModel fullTrayModel: TrayModel { items: root.trayItems; pinnedIds: root.pinnedIds; limit: 0; anchorItem: root.actionAnchor }
    readonly property TrayModel trayModel: TrayModel {
        items: root.trayItems
        pinnedIds: root.pinnedIds
        // Without a popout host every icon must stay reachable on the bar.
        limit: AppConfig.moduleEnabled("popouts") ? (root.compactPresentation ? 0 : root.maxVisible) : -1
        anchorItem: root
    }
    RowLayout {
        spacing: root.itemSpacing
        Repeater {
            model: ScriptModel { values: Array.from(root.trayModel.visibleItems) }
            delegate: TrayIcon {
                required property SystemTrayItem modelData
                trayItem: modelData
                iconSize: root.iconSize
                tooltipManager: root.tooltipManager
            }
        }
        Item {
            implicitWidth: overflowButton.implicitWidth
            implicitHeight: overflowButton.implicitHeight
            visible: root.trayModel.hiddenItems.length > 0
            IconButton {
                id: overflowButton
                iconName: "more_horiz"
                iconSize: Tokens.iconSize.medium
                Accessible.name: "Show " + root.trayModel.hiddenItems.length + " more tray icons"
                onClicked: PopoutsState.openPopout("trayoverflow", root.trayModel, root)
            }
            MaterialIndicator {
                anchors.right: parent.right
                anchors.top: parent.top
                size: "extraSmall"
                animated: root.animationsActive
                colorRole: "primary"
                visible: root.trayModel.hiddenAttentionCount > 0
            }
        }
    }
}
