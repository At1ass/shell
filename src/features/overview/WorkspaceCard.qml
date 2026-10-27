pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell as QS
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

MaterialCard {
    id: root
    required property var workspace
    property bool dropTarget: false
    property bool keepDragSource: false
    property bool selectedWorkspace: false
    property Item keyOwner: null
    property string selectedAddress: ""
    property bool captureEnabled: false
    signal dragBegan(string address, point position)
    signal dragMoved(string address, point position)
    signal dragFinished(string address, point position, bool cancelled)
    signal selectedRequested(string address)
    signal activated(string address)
    signal moveRequested(string address)
    signal closeRequested(string address)
    signal workspaceRequested(int id)
    readonly property QS.ObjectModel windowModel: workspace.native?.toplevels as QS.ObjectModel
    readonly property var screenGeometry: {
        const screen = Quickshell.screens.find(screen => screen?.name === root.workspace.native?.monitor?.name)
        return screen ? {x:screen.x,y:screen.y,width:Math.max(1,screen.width),height:Math.max(1,screen.height)} : {x:0,y:0,width:Math.max(1,Quickshell.screens[0]?.width ?? root.width),height:Math.max(1,Quickshell.screens[0]?.height ?? root.width*9/16)}
    }
    implicitHeight: titleRow.implicitHeight + Tokens.spacing.small * 3 + width * 9/16
    color: root.dropTarget || root.selectedWorkspace
        ? Qt.tint(Theme.surfaceContainerHigh, Qt.alpha(Theme.primary, root.dropTarget ? Tokens.stateLayer.draggedOpacity : Tokens.stateLayer.focusOpacity))
        : Theme.surfaceContainerHigh
    radius: Tokens.shape.medium
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        spacing: Tokens.spacing.small
        RowLayout {
            id: titleRow
            Layout.fillWidth: true
            MaterialText {
                Layout.fillWidth: true
                text: root.workspace.name + (root.workspace.native?.monitor?.name ? " · " + root.workspace.native.monitor.name : "")
                textFormat: Text.PlainText
                textStyle: "labelLarge"
                colorRole: root.selectedWorkspace ? "primary" : "onSurface"
                elide: Text.ElideRight
            }
            IconButton {
                iconName: "arrow_forward"
                Accessible.name: "Switch to workspace " + root.workspace.name
                onClicked: root.workspaceRequested(root.workspace.id)
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Surface {
                id: desktop
                objectName: "overviewWorkspaceCanvas"
                anchors.centerIn: parent
                width: Math.max(0, Math.min(parent.width, parent.height * root.screenGeometry.width / root.screenGeometry.height))
                height: width * root.screenGeometry.height / root.screenGeometry.width
                radius: Tokens.shape.small
                color: root.dropTarget || root.selectedWorkspace
                    ? Qt.tint(Theme.surfaceContainerLowest, Qt.alpha(Theme.primary, root.dropTarget ? Tokens.stateLayer.draggedOpacity : Tokens.stateLayer.focusOpacity))
                    : Theme.surfaceContainerLowest
                outlineWidth: root.dropTarget ? Tokens.focusRing.width : 0
                outlineColor: Theme.primary
                outlined: false
                clip: true
                MouseArea { anchors.fill: parent; onClicked: root.workspaceRequested(root.workspace.id) }
                Loader {
                    anchors.fill: parent
                    active: root.captureEnabled || root.keepDragSource
                    asynchronous: true
                    sourceComponent: Item {
                        Repeater {
                            model: ScriptModel { values: root.windowModel ? Array.from(root.windowModel.values) : [] }
                            delegate: WindowThumbnail {
                                required property HyprlandToplevel modelData
                                window: modelData
                                keyOwner: root.keyOwner
                                readonly property var geometry: modelData?.lastIpcObject ?? ({})
                                width: Math.min(parent.width, Math.max(Tokens.iconSize.extraLarge * 2, (geometry.size?.[0] ?? root.screenGeometry.width) / root.screenGeometry.width * parent.width))
                                height: Math.min(parent.height, Math.max(Tokens.touchTarget.minimum, (geometry.size?.[1] ?? root.screenGeometry.height) / root.screenGeometry.height * parent.height))
                                x: Math.max(0,Math.min(parent.width-width,((geometry.at?.[0] ?? root.screenGeometry.x)-root.screenGeometry.x)/root.screenGeometry.width*parent.width))
                                y: Math.max(0,Math.min(parent.height-height,((geometry.at?.[1] ?? root.screenGeometry.y)-root.screenGeometry.y)/root.screenGeometry.height*parent.height))
                                selected: modelData?.address === root.selectedAddress
                                matched: OverviewService.matches.includes(modelData?.address ?? "")
                                captureEnabled: root.captureEnabled
                                z: selected ? 1 : 0
                                onDragBegan: (address,position) => root.dragBegan(address,position)
                                onDragMoved: (address,position) => root.dragMoved(address,position)
                                onDragFinished: (address,position,cancelled) => root.dragFinished(address,position,cancelled)
                                onSelectedRequested: address => root.selectedRequested(address)
                                onActivated: address => root.activated(address)
                                onMoveRequested: address => root.moveRequested(address)
                                onCloseRequested: address => root.closeRequested(address)
                            }
                        }
                    }
                }
            }
        }
    }
}
