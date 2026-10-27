pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

FocusScope {
    id: root
    property int _dragEpoch: 0
    property string dragAddress: ""
    property int dragOriginWorkspaceId: 0
    property real dragOriginScrollY: 0
    property int dragTargetId: 0
    property point dragPosition: Qt.point(0,0)
    readonly property bool dragging: dragAddress !== ""
    readonly property var dragWindow: OverviewService.windowFor(dragAddress)
    readonly property var dragTarget: OverviewService.workspaces.find(workspace=>workspace.id===dragTargetId) ?? null
    readonly property bool dropAllowed: dragging && dragTarget !== null && dragTargetId !== dragOriginWorkspaceId
    readonly property int dragScrollDirection: {
        if (!dragging) return 0
        const point=grid.mapFromItem(root,dragPosition.x,dragPosition.y)
        if (point.x<0 || point.x>=grid.width || point.y<0 || point.y>=grid.height) return 0
        const edge=Tokens.spacing.large
        if (point.y<edge && grid.contentY>0) return -1
        if (point.y>grid.height-edge && grid.contentY<Math.max(0,grid.contentHeight-grid.height)) return 1
        return 0
    }
    function cancelDrag() { _dragEpoch++;dragAddress="";dragTargetId=0;dragOriginWorkspaceId=0 }
    function beginDrag(address,position) {
        const window=OverviewService.windowFor(address)
        if (dragging || modalOpen || !GlobalStates.overviewOpen || !window) return false
        _dragEpoch++
        selectedAddress=address
        dragOriginWorkspaceId=window.workspace?.id ?? 0
        dragOriginScrollY=grid.contentY
        dragAddress=address
        updateDrag(address,position)
        return true
    }
    function updateDropTarget() {
        dragTargetId=0
        if (!dragging) return
        const point=grid.mapFromItem(root,dragPosition.x,dragPosition.y)
        if (point.x<0 || point.x>=grid.width || point.y<0 || point.y>=grid.height) return
        const index=grid.indexAt(grid.contentX+point.x,grid.contentY+point.y)
        const target=OverviewService.workspaces[index]
        const card=grid.itemAtIndex(index)
        if (!target || !card) return
        const local=card.mapFromItem(root,dragPosition.x,dragPosition.y)
        if (local.x>=0 && local.x<card.width && local.y>=0 && local.y<card.height) dragTargetId=target.id
    }
    function updateDrag(address,position) {
        if (address!==dragAddress || !dragging) return
        dragPosition=position
        updateDropTarget()
    }
    function finishDrag(address,position,cancelled) {
        if (!dragging || address!==dragAddress) return false
        updateDrag(address,position)
        const target=dragTargetId
        const valid=!cancelled && GlobalStates.overviewOpen && dropAllowed
            && OverviewService.windowFor(address)?.workspace?.id===dragOriginWorkspaceId
        cancelDrag()
        return valid ? OverviewService.moveWindow(address,target) : false
    }
    onDragWindowChanged: if (dragging && !dragWindow) {
        const epoch=root._dragEpoch
        Qt.callLater(() => {if(root._dragEpoch===epoch && root.dragging && !root.dragWindow)root.cancelDrag()})
    }
    onVisibleChanged: if (!visible) root.cancelDrag()
    onModalOpenChanged: if (modalOpen) root.cancelDrag()
    Connections {
        target: root.dragWindow
        function onWorkspaceChanged() { if (root.dragWindow?.workspace?.id!==root.dragOriginWorkspaceId) root.cancelDrag() }
    }
    Connections { target:GlobalStates;function onOverviewOpenChanged(){if(!GlobalStates.overviewOpen)root.cancelDrag()} }
    Timer {
        interval: Tokens.interaction.dragScrollInterval
        repeat: true
        running: root.dragging && root.dragScrollDirection!==0
        onTriggered: if(root.dragging) {
            grid.contentY=Math.max(0,Math.min(Math.max(0,grid.contentHeight-grid.height),grid.contentY+root.dragScrollDirection*Tokens.spacing.medium*2))
            root.updateDropTarget()
        }
    }
    property int selectedWorkspaceId: AppConfig.overviewFirstWorkspace
    property string selectedAddress: ""
    property string moveSourceAddress: ""
    readonly property var moveSourceWindow: OverviewService.windowFor(moveSourceAddress)
    readonly property bool modalOpen: moveDialog.visible
    property var moveDestinations: []
    readonly property var selectedWindow: OverviewService.windowFor(selectedAddress)
    function focusInitial() { search.forceActiveFocus(Qt.TabFocusReason) }
    function reset() {
        root.cancelDrag()
        OverviewService.query=""
        root.selectedWorkspaceId=OverviewService.workspaces.find(workspace=>workspace.native?.focused)?.id ?? AppConfig.overviewFirstWorkspace
        root.selectedAddress=OverviewService.windows.find(window=>window?.activated)?.address ?? ""
        root.reconcileSelection()
        root.focusInitial()
    }
    function reconcileSelection() {
        if (OverviewService.matches.includes(selectedAddress)) return
        const local=OverviewService.matches.find(address=>OverviewService.windowFor(address)?.workspace?.id===selectedWorkspaceId)
        selectedAddress=local ?? (OverviewService.query.trim() ? OverviewService.matches[0] ?? "" : "")
    }
    function step(delta) {
        const matches = OverviewService.matches
        if (!matches.length) return
        const found = matches.indexOf(selectedAddress)
        const current = found < 0 ? (delta > 0 ? -1 : 0) : found
        selectedAddress = matches[(current + delta + matches.length) % matches.length]
        const window = selectedWindow
        const index = OverviewService.workspaces.findIndex(workspace => workspace.id === window?.workspace?.id)
        if (index >= 0) grid.positionViewAtIndex(index, GridView.Contain)
    }
    function stepWorkspace(delta) {
        const workspaces=OverviewService.workspaces
        if (!workspaces.length) return
        const current=Math.max(0,workspaces.findIndex(workspace=>workspace.id===selectedWorkspaceId))
        const next=(current+delta+workspaces.length)%workspaces.length
        selectedWorkspaceId=workspaces[next].id
        selectedAddress=OverviewService.matches.find(address=>OverviewService.windowFor(address)?.workspace?.id===selectedWorkspaceId) ?? ""
        grid.positionViewAtIndex(next,GridView.Contain)
    }
    function activateSelection() {
        if (selectedWindow) OverviewService.focusWindow(selectedAddress)
        else if (!OverviewService.query.trim()) OverviewService.focusWorkspace(selectedWorkspaceId)
    }
    onSelectedWindowChanged: if (selectedWindow?.workspace) selectedWorkspaceId=selectedWindow.workspace.id
    function closeWindow(address) {
        if (dragging || modalOpen || !OverviewService.matches.includes(address)) return false
        if (!OverviewService.windowFor(address)) return false
        root.forceActiveFocus(Qt.OtherFocusReason)
        return OverviewService.closeWindow(address)
    }
    function openMove(address) {
        if (!OverviewService.windowFor(address)) return
        root.cancelDrag()
        selectedAddress = address
        const candidate = OverviewService.workspaces.find(workspace => workspace.id !== selectedWindow.workspace?.id)
        if (!candidate) return
        moveSourceAddress = address
        moveDestinations = OverviewService.workspaces.map(workspace=>({id:workspace.id,name:workspace.name}))
        moveDialog.open()
    }
    Connections { target: OverviewService; function onMatchesChanged() { root.reconcileSelection() } }
    Shortcut { sequence:"PgDown";context:Qt.WindowShortcut;enabled:root.visible && !root.modalOpen && !root.dragging;onActivated:root.stepWorkspace(1) }
    Shortcut { sequence:"PgUp";context:Qt.WindowShortcut;enabled:root.visible && !root.modalOpen && !root.dragging;onActivated:root.stepWorkspace(-1) }
    function handleKey(event) {
        if (root.modalOpen) return
        const key=Keycodes.key(event)
        if (root.dragging) {
            if (key===Qt.Key_Escape) root.cancelDrag()
            event.accepted=true
            return
        }
        const editing = search.inputItem.activeFocus
        const navigation = !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))
            && ((event.modifiers & Qt.AltModifier) || !editing)
        if (navigation && key===Qt.Key_H) root.stepWorkspace(-1)
        else if (navigation && key===Qt.Key_L) root.stepWorkspace(1)
        else if (navigation && key===Qt.Key_J) root.step(1)
        else if (navigation && key===Qt.Key_K) root.step(-1)
        else if (key===Qt.Key_M && (event.modifiers & Qt.ControlModifier)) {
            if (!event.isAutoRepeat) root.openMove(root.selectedAddress)
        } else if (key===Qt.Key_W && event.modifiers===Qt.ControlModifier) {
            if (!event.isAutoRepeat) root.closeWindow(root.selectedAddress)
        } else if (!editing && (key===Qt.Key_Return || key===Qt.Key_Enter || key===Qt.Key_Space)) {
            if (!event.isAutoRepeat) root.activateSelection()
        } else if (key === Qt.Key_Escape) GlobalStates.closePanel("overview")
        else if (key === Qt.Key_Down) root.step(1)
        else if (key === Qt.Key_Up) root.step(-1)
        else return
        event.accepted = true
    }
    Keys.onPressed: event => root.handleKey(event)
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.medium
        RowLayout {
            Layout.fillWidth: true
            MaterialTextField {
                id: search
                keyForwardTargets: [root]
                Layout.fillWidth: true
                placeholderText: "Find a window or application"
                leadingIcon: "search"
                onTextEdited: OverviewService.query = text
                onAccepted: if (!root.modalOpen) root.activateSelection()
                Keys.onDownPressed: root.step(1)
                Keys.onUpPressed: root.step(-1)
            }
            IconButton { iconName:"drive_file_move"; enabled:!!root.selectedWindow; Accessible.name:"Move selected window (Ctrl+M)"; onClicked:root.openMove(root.selectedAddress) }
            IconButton { iconName:"close"; Accessible.name:"Close workspace overview"; onClicked:GlobalStates.closePanel("overview") }
        }
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cacheBuffer: root.dragging ? Math.abs(contentY-root.dragOriginScrollY)+height : 0
            interactive: !root.dragging
            onContentYChanged: if (root.dragging) root.updateDropTarget()
            readonly property int columns: Math.max(1, Math.min(AppConfig.overviewColumns, Math.floor(width / Tokens.size.fieldWidth)))
            readonly property int rows: Math.max(1, Math.ceil(OverviewService.workspaces.length / columns))
            // Keep controls and a useful preview at large fonts/short heights.
            // Otherwise fit every row, instead of deriving height from width alone.
            readonly property real minimumCellHeight: Math.max(Tokens.touchTarget.minimum, Tokens.size.iconButton, Tokens.typography.labelLarge.lineHeight)
                + Tokens.spacing.small * 4 + Tokens.touchTarget.minimum * 2
            cellWidth: Math.max(1, Math.floor(width / columns))
            cellHeight: Math.max(minimumCellHeight, Math.floor(Math.min(cellWidth * 9/16 + Tokens.size.control + Tokens.spacing.medium * 2, height / rows)))
            model: ScriptModel { values: OverviewService.workspaces; objectProp:"id" }
            boundsBehavior: Flickable.StopAtBounds
            delegate: WorkspaceCard {
                required property var modelData
                required property int index
                workspace: modelData
                width: Math.max(0, grid.cellWidth - Tokens.spacing.small)
                height: Math.max(0, grid.cellHeight - Tokens.spacing.small)
                selectedWorkspace: root.selectedWorkspaceId === modelData.id
                dropTarget: root.dropAllowed && root.dragTargetId===modelData.id
                keepDragSource: root.dragging && root.dragOriginWorkspaceId===modelData.id
                selectedAddress: root.selectedAddress
                keyOwner: root
                captureEnabled: root.visible && GlobalStates.overviewOpen && y + height >= grid.contentY && y <= grid.contentY + grid.height
                onDragBegan: (address,position) => root.beginDrag(address,position)
                onDragMoved: (address,position) => root.updateDrag(address,position)
                onDragFinished: (address,position,cancelled) => root.finishDrag(address,position,cancelled)
                onSelectedRequested: address => { root.selectedAddress=address }
                onActivated: address => OverviewService.focusWindow(address)
                onWorkspaceRequested: id => OverviewService.focusWorkspace(id)
                onMoveRequested: address => root.openMove(address)
                onCloseRequested: address => root.closeWindow(address)
            }
        }
        MaterialText {
            Layout.fillWidth: true
            text: root.selectedWindow?.title || (OverviewService.query ? "No matching windows" : "Workspace " + root.selectedWorkspaceId + " · No windows")
            textFormat: Text.PlainText
            textStyle:"bodyMedium"
            elide:Text.ElideRight
        }
        MaterialText { Layout.fillWidth:true; text: root.width < Tokens.size.fieldWidth * 2 ? "Alt+H/L Workspace · Alt+J/K Window" : "Alt+H/L Workspace · Alt+J/K Window · Enter Switch · Ctrl+M Move · Ctrl+W Close window · Esc Dismiss"; textStyle:"labelSmall"; colorRole:"onSurfaceVariant"; wrapMode:Text.WordWrap }
    }
    Surface {
        id: dragGhost
        objectName: "overviewDragGhost"
        visible: root.dragging
        z: 1
        width: Math.max(0,Math.min(Tokens.size.fieldWidth,root.width-Tokens.spacing.medium*2))
        height: ghostColumn.implicitHeight+Tokens.spacing.small*2
        x: Math.max(Tokens.spacing.small,Math.min(root.width-width-Tokens.spacing.small,root.dragPosition.x+Tokens.spacing.small))
        y: Math.max(Tokens.spacing.small,Math.min(root.height-height-Tokens.spacing.small,root.dragPosition.y+Tokens.spacing.small))
        color: Theme.surfaceContainerHighest
        outlineWidth: Tokens.focusRing.width
        outlineColor: Theme.primary
        radius: Tokens.shape.small
        ColumnLayout {
            id: ghostColumn
            anchors.left: parent.left;anchors.right:parent.right
            anchors.top:parent.top;anchors.margins:Tokens.spacing.small
            spacing:Tokens.spacing.extraSmall
            MaterialText {Layout.fillWidth:true;text:root.dragWindow?.title ?? "Window";textFormat:Text.PlainText;textStyle:"labelMedium";elide:Text.ElideRight}
            MaterialText {Layout.fillWidth:true;text:root.dropAllowed ? "Move to " + root.dragTarget.name : "Choose another workspace";textStyle:"labelSmall";colorRole:"onSurfaceVariant";elide:Text.ElideRight}
        }
    }
    Dialog {
        id: moveDialog
        parent: root
        dialogWidth: Math.min(root.width - Tokens.spacing.large * 2, Tokens.size.fieldWidth * 2)
        dialogHeight: Math.min(root.height - Tokens.spacing.large * 2, Tokens.size.listItem * 7)
        onOpened: Qt.callLater(() => { if (moveDialog?.visible && destinations) destinations.focusFirst() })
        onClosed: {root.moveSourceAddress="";root.moveDestinations=[]}
        ColumnLayout {
            anchors.fill: parent
            MaterialText { Layout.fillWidth:true; text:"Move window to…"; textStyle:"titleMedium" }
            MaterialMenu {
                id: destinations
                Layout.fillWidth:true
                Layout.fillHeight:true
                itemWidth:width
                maximumHeight:height
                Keys.onPressed: event => {
                    const key=Keycodes.key(event)
                    if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier)) return
                    if (key===Qt.Key_J) destinations.focusNext(1)
                    else if (key===Qt.Key_K) destinations.focusNext(-1)
                    else return
                    event.accepted=true
                }
                model:root.moveDestinations.map(workspace=>({label:workspace.name,enabled:workspace.id!==root.moveSourceWindow?.workspace?.id}))
                onTriggered: index => {
                    const target=root.moveDestinations[index]
                    if (target) OverviewService.moveWindow(root.moveSourceAddress,target.id)
                    moveDialog.close()
                    search.forceActiveFocus()
                }
            }
            MaterialText { text:"Esc to cancel";textStyle:"labelSmall";colorRole:"onSurfaceVariant" }
        }
    }
    onMoveSourceWindowChanged: if (!moveSourceWindow && moveDialog.visible) moveDialog.close()
}
