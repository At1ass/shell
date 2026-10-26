pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.feedback
import "BarLayoutPolicy.js" as Policy

// Each bar owns its own plan, widgets and overflow request. No screen-wide state.
Item {
    id: root
    property var leftWidgets: []
    property var centerWidgets: []
    property var rightWidgets: []
    property string screenName: ""
    property var tooltipManager: null
    property bool barRevealed: true
    property int _revision: 0
    readonly property real gap: Tokens.spacing.small
    readonly property real buttonWidth: Math.max(Tokens.size.iconButton, Tokens.touchTarget.minimum)
    readonly property var entries: {
        const revision = root._revision
        const result = []
        for (const pair of [[leftItems,"left"],[centerItems,"center"],[rightItems,"right"]]) {
            for (let i = 0; i < pair[0].count; i++) {
                const item = pair[0].itemAt(i)
                if (item?.eligible) result.push(item.measure(pair[1],result.length))
            }
        }
        return result
    }
    readonly property var plan: Policy.plan(entries, Math.max(0,width),gap,buttonWidth,AppConfig.moduleEnabled("popouts"))
    readonly property var overflowWidgets: entries.filter(entry=>plan.hidden.includes(entry.key)).map(entry=>entry.widget)
    readonly property Item overflowAnchor: overflowButton
    readonly property bool overflowAttention: overflowWidgets.some(widget=>root.widgetAttention(widget))
    function widgetAttention(widget) { return widget?.item?.needsAttention ?? false }
    function hidden(key) { return root.plan.hidden.includes(key) }
    function compact(key) { return root.plan.compact.includes(key) }
    function actionAnchor(key, item) { return root.hidden(key) ? overflowButton : item }

    readonly property real leftGap: plan.zones.left.count && plan.zones.center.count ? gap : 0
    readonly property real rightGap: plan.zones.right.count && plan.zones.center.count ? gap : 0
    readonly property real centerWidth: Math.min(plan.zones.center.preferred,
        Math.max(0,plan.width-plan.zones.left.minimum-plan.zones.right.minimum-leftGap-rightGap))
    readonly property real centerX: plan.zones.center.count
        ? Math.max(plan.zones.left.minimum+leftGap,Math.min((plan.width-centerWidth)/2,
            plan.width-plan.zones.right.minimum-rightGap-centerWidth))
        : Math.min(plan.zones.left.preferred,Math.max(0,plan.width-plan.zones.right.minimum-(plan.zones.left.count && plan.zones.right.count ? gap : 0)))

    IconButton {
        visible: root.plan.scroll
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        Accessible.name: "Previous bar widgets"
        iconName: "chevron_left"
        enabled: viewport.contentX > 0
        onClicked: viewport.contentX = Math.max(0,viewport.contentX-viewport.width/2)
    }
    IconButton {
        visible: root.plan.scroll
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Accessible.name: "Next bar widgets"
        iconName: "chevron_right"
        enabled: viewport.contentX < viewport.contentWidth-viewport.width
        onClicked: viewport.contentX = Math.min(viewport.contentWidth-viewport.width,viewport.contentX+viewport.width/2)
    }
    Flickable {
        id: viewport
        anchors.fill: parent
        anchors.leftMargin: root.plan.scroll ? root.buttonWidth : 0
        anchors.rightMargin: root.plan.scroll ? root.buttonWidth : 0
        contentWidth: root.plan.width
        contentHeight: height
        clip: true
        interactive: root.plan.scroll
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        onInteractiveChanged: if (!interactive) contentX = 0

        Item {
            id: body
            width: root.plan.width
            height: viewport.height
            RowLayout {
                id: leftSection
                x: 0
                height: parent.height
                width: Math.min(root.plan.zones.left.preferred,Math.max(0,root.centerX-root.leftGap))
                spacing: root.gap
                Repeater {
                    id: leftItems
                    model: root.leftWidgets
                    onItemAdded: root._revision++
                    onItemRemoved: root._revision++
                    BarWidgetLoader {
                        required property int index
                        required property var modelData
                        widgetKey: "left:"+index
                        widgetConfig: modelData
                        tooltipManager: root.tooltipManager
                        screenName: root.screenName
                        barRevealed: root.barRevealed
                        adaptiveHidden: root.hidden(widgetKey)
                        adaptiveCompact: root.compact(widgetKey)
                        overflowAnchor: root.overflowAnchor
                    }
                }
            }
            RowLayout {
                id: centerSection
                x: root.centerX
                width: root.centerWidth
                height: parent.height
                spacing: root.gap
                Repeater {
                    id: centerItems
                    model: root.centerWidgets
                    onItemAdded: root._revision++
                    onItemRemoved: root._revision++
                    BarWidgetLoader {
                        required property int index
                        required property var modelData
                        widgetKey: "center:"+index
                        widgetConfig: modelData
                        tooltipManager: root.tooltipManager
                        screenName: root.screenName
                        barRevealed: root.barRevealed
                        adaptiveHidden: root.hidden(widgetKey)
                        adaptiveCompact: root.compact(widgetKey)
                        overflowAnchor: root.overflowAnchor
                    }
                }
            }
            RowLayout {
                id: rightSection
                x: root.plan.width-width
                height: parent.height
                width: Math.min(root.plan.zones.right.preferred,
                    Math.max(0,root.plan.width-root.centerX-root.centerWidth-root.rightGap))
                spacing: root.gap
                Repeater {
                    id: rightItems
                    model: root.rightWidgets
                    onItemAdded: root._revision++
                    onItemRemoved: root._revision++
                    BarWidgetLoader {
                        required property int index
                        required property var modelData
                        widgetKey: "right:"+index
                        widgetConfig: modelData
                        tooltipManager: root.tooltipManager
                        screenName: root.screenName
                        barRevealed: root.barRevealed
                        adaptiveHidden: root.hidden(widgetKey)
                        adaptiveCompact: root.compact(widgetKey)
                        overflowAnchor: root.overflowAnchor
                    }
                }
                Item {
                    visible: root.overflowWidgets.length>0
                    implicitWidth: root.buttonWidth
                    implicitHeight: root.buttonWidth
                    IconButton {
                        id: overflowButton
                        Accessible.name: "More bar widgets"
                        iconName: "more_horiz"
                        onClicked: PopoutsState.openPopout("baroverflow",root,overflowButton)
                    }
                    MaterialIndicator {
                        visible: root.overflowAttention
                        anchors.top: parent.top
                        anchors.right: parent.right
                        size: "extraSmall"
                        colorRole: "primary"
                        animated: root.barRevealed
                    }
                }
            }
        }
    }
}
