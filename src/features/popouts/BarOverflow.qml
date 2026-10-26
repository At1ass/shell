pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

Item {
    id: root
    required property QtObject barModel
    property real maximumHeight: Tokens.size.listItem * 10
    property QtObject workspaceWidget: null
    property int requestEpoch: -1
    signal menuClosed()
    function widgets(model) { return model?.overflowWidgets ?? [] }
    function anchor(model) { return model?.overflowAnchor ?? null }
    function kind(widget) { return widget?.widgetType ?? "" }
    function itemFor(widget) { return widget?.item ?? null }
    function workspaceCount(widget) { return widget?.wsCount ?? 0 }
    function workspaceId(widget,index) { return (widget?.wsBaseIndex ?? 1)+index }
    readonly property var entries: widgets(barModel)
    implicitWidth: Tokens.size.fieldWidth + Tokens.spacing.large * 2
    implicitHeight: Math.min(maximumHeight,column.implicitHeight)

    function title(widget) {
        return ({clock:"Clock & calendar",workspaces:"Workspaces",activewindow:"Active window",
            media:"Media",weather:"Weather",volume:"Audio",network:"Connections",battery:"Battery",
            layout:"Keyboard layout",notifications:"Notifications",tray:"Applications"})[kind(widget)] ?? "Widget"
    }
    function icon(widget) {
        return ({clock:"schedule",workspaces:"view_module",activewindow:"window",media:"music_note",
            weather:"cloud",volume:"volume_up",network:"wifi",battery:"battery_full",
            layout:"keyboard",notifications:"notifications",tray:"apps"})[kind(widget)] ?? "more_horiz"
    }
    function summary(widget) {
        const item = itemFor(widget)
        switch(kind(widget)) {
        case "clock": return (item?.currentTime ?? "") + " · " + Qt.formatDate(DateTime.clock.date,"dddd, d MMMM yyyy")
        case "activewindow": return ActiveWindowService.windowTitle
        case "media": return `${MprisController.activeTrack?.title ?? "Nothing playing"} · ${MprisController.activeTrack?.artist ?? ""}`
        case "weather": return `${Weather.location} · ${Math.round(Weather.tempC)}${Weather.tempUnit}`
        case "volume": return AudioService.masterMuted ? "Muted" : `${Math.round(AudioService.masterVolume*100)}%`
        case "network": return NetworkService.connectionLabel
        case "battery": return item?.deviceReady ? `${item.percentage}%${item.charging ? " · Charging" : ""}` : "Unavailable"
        case "layout": return KeyboardLayoutService.currentLayoutCode.toUpperCase()
        case "tray": return `${item?.trayItems?.length ?? 0} applications`
        default: return ""
        }
    }
    function action(widget) {
        return widget?.widgetConfig?.clickAction ?? ({clock:"dashboard-calendar",media:"dashboard-quick",weather:"dashboard-weather",
            volume:"audio",network:"connections-wifi",battery:"dashboard-quick",notifications:"notification-center"})[kind(widget)] ?? ""
    }
    function activate(widget) {
        const type = kind(widget), item = itemFor(widget), source = anchor(barModel)
        if(type === "workspaces") {
            workspaceWidget = workspaceWidget === item ? null : item
            return
        }
        if(type === "tray") {
            if(item?.fullTrayModel) PopoutsState.openPopout("trayoverflow",item.fullTrayModel,source)
            return
        }
        const command = action(widget)
        root.menuClosed()
        if(command === "audio" || command === "dashboard-audio") GlobalStates.openAudio(source)
        else if(command === "connections" || command === "connections-wifi" || command === "connections-bluetooth" || command === "dashboard-network")
            GlobalStates.openConnections(command === "connections-bluetooth" ? "bluetooth" : command === "connections" ? "" : "wifi",source)
        else if(command) GlobalStates.handleClickAction(command)
    }
    function focusRows() {
        const result=[]
        for(const repeater of [rows,workspaces]) for(let i=0;i<repeater.count;i++) {
            const row = repeater.itemAt(i)
            if(row?.visible && row.enabled && row.activeFocusOnTab) result.push(row)
        }
        return result
    }
    function focusInitial() { const candidates=focusRows();if(candidates.length) candidates[0].forceActiveFocus(Qt.PopupFocusReason) }
    function moveFocus(direction,last) {
        const candidates=focusRows()
        if(!candidates.length) return
        let current = root.Window.window?.activeFocusItem
        while(current && !candidates.includes(current)) current=current.parent
        const index=last ? candidates.length-1 : direction===0 ? 0
            : (candidates.indexOf(current)+direction+candidates.length)%candidates.length
        candidates[index].forceActiveFocus(Qt.TabFocusReason)
    }
    function closeIfEmpty() {
        const epoch=requestEpoch
        if(entries.length) return
        Qt.callLater(()=>{if(epoch===PopoutsState.epoch && PopoutsState.name==="baroverflow" && !root.entries.length) root.menuClosed()})
    }
    Component.onCompleted: {requestEpoch=PopoutsState.epoch;closeIfEmpty()}
    onEntriesChanged: closeIfEmpty()
    Keys.onPressed: event=>{
        if(event.key===Qt.Key_Down) moveFocus(1,false)
        else if(event.key===Qt.Key_Up) moveFocus(-1,false)
        else if(event.key===Qt.Key_Home) moveFocus(0,false)
        else if(event.key===Qt.Key_End) moveFocus(0,true)
        else if(event.key===Qt.Key_Escape) {if(workspaceWidget) workspaceWidget=null;else menuClosed()}
        else return
        event.accepted=true
    }
    ScrollableList {
        anchors.fill: parent
        spacing: 0
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            spacing: 0
            MaterialText { Layout.margins: Tokens.spacing.small; text:"More";textStyle:"titleSmall" }
            Repeater {
                id: rows
                model: ScriptModel {values:Array.from(root.entries)}
                ListItem {
                    required property var modelData
                    Layout.fillWidth:true
                    headline:root.title(modelData)
                    supportingText:root.summary(modelData)
                    supportingTextFormat:Text.PlainText
                    leadingIcon:root.icon(modelData)
                    clickable:root.kind(modelData)==="workspaces" || root.kind(modelData)==="tray" || root.action(modelData)!==""
                    trailingIcon:root.kind(modelData)==="workspaces" ? "expand_more" : root.kind(modelData)==="tray" ? "chevron_right" : ""
                    onClicked:root.activate(modelData)
                }
            }
            Repeater {
                id: workspaces
                model: root.workspaceCount(root.workspaceWidget)
                ListItem {
                    required property int index
                    Layout.fillWidth:true
                    readonly property int workspaceId:root.workspaceId(root.workspaceWidget,index)
                    headline:`Workspace ${workspaceId}`
                    leadingIcon:"view_module"
                    onClicked:{HyprlandDispatch.focusWorkspace(workspaceId);root.menuClosed()}
                }
            }
            RowLayout {
                Layout.fillWidth:true
                visible:root.entries.some(widget=>root.kind(widget)==="media")
                Item {Layout.fillWidth:true}
                IconButton {iconName:"skip_previous";Accessible.name:"Previous track";enabled:MprisController.canGoPrevious;onClicked:MprisController.previous()}
                IconButton {iconName:MprisController.isPlaying ? "pause" : "play_arrow";Accessible.name:MprisController.isPlaying ? "Pause" : "Play";enabled:MprisController.canTogglePlaying;onClicked:MprisController.togglePlaying()}
                IconButton {iconName:"skip_next";Accessible.name:"Next track";enabled:MprisController.canGoNext;onClicked:MprisController.next()}
                Item {Layout.fillWidth:true}
            }
        }
    }
}
