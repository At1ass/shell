pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services
import "../../core/services/WindowWorkspace.js" as WindowWorkspace

// Numbered groups preserve workspace identity even in compact presentation.
// One Tab stop; H/L select workspaces, J/K select windows, Enter activates.
BarElement {
    id: workspaceWidget
    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property var tooltipManager: null
    property int wsBaseIndex: widgetSettings.baseIndex ?? 1
    property int wsCount: widgetSettings.count ?? 9
    property bool showWindows: widgetSettings.showWindows ?? true
    property int maxWindows: widgetSettings.maxWindowsPerWorkspace ?? 4
    readonly property bool pillIndicator: (widgetSettings.activeIndicator ?? "pill") === "pill"
    property int _metricRevision: 0
    property int keyboardWorkspaceId: wsBaseIndex
    property string keyboardWindowAddress: ""
    property int scrollAccumulator: 0
    readonly property int currentIndex: Hyprland.focusedWorkspace?.id ?? wsBaseIndex
    readonly property int controlHeight: Math.ceil(Math.max(Tokens.touchTarget.minimum, Tokens.typography.labelLarge.lineHeight))
    readonly property int chipSize: Math.ceil(Math.max(controlHeight, numberMetrics.width + Tokens.spacing.small * 2))
    readonly property int iconFontSize: Math.min(Tokens.iconSize.large, controlHeight - Tokens.spacing.small)
    readonly property var windowsByWorkspace: WindowWorkspace.group(Hyprland.toplevels?.values ?? [])
    readonly property var keyboardWindows: windowsByWorkspace[keyboardWorkspaceId] ?? []
    readonly property var keyboardWindow: keyboardWindows.find(window => window.address === keyboardWindowAddress) ?? null

    property TextMetrics _numberMetrics: TextMetrics {
        id: numberMetrics
        text: String(workspaceWidget.wsBaseIndex + workspaceWidget.wsCount - 1)
        font.family: Tokens.typography.fontFamily
        font.pixelSize: Tokens.typography.labelLarge.size
        font.weight: Tokens.typography.labelLarge.weight
    }
    function fullWidth() {
        let total = Tokens.spacing.medium + Math.max(0, wsCount - 1) * Tokens.spacing.extraSmall
        for (let i = 0; i < workspaceItems.count; i++) {
            const item = workspaceItems.itemAt(i) as WorkspaceGroup
            total += item?.fullWidth ?? chipSize
        }
        return total
    }
    function workspaceDescription(id) {
        const count = windowsByWorkspace[id]?.length ?? 0
        return "Workspace " + id + " · " + count + (count === 1 ? " window" : " windows")
            + (id === currentIndex ? " · Active" : "")
    }
    function windowDescription(window, id) {
        const app = IconCategoryResolver.appName(window?.lastIpcObject?.class ?? "")
        const title = window?.title || window?.lastIpcObject?.title || app
        return app + (title !== app ? "\n" + title : "") + "\nWorkspace " + id
    }
    function openOverview(id) { OverviewService.showWorkspace(id, workspaceWidget) }
    function contextWorkspace(id) {
        const action = widgetConfig?.clickAction ?? "overview"
        if (action === "overview") openOverview(id)
        else GlobalStates.handleClickAction(action)
    }
    function selectWorkspace(delta) {
        const index = keyboardWorkspaceId - wsBaseIndex
        keyboardWorkspaceId = wsBaseIndex + (index + delta + wsCount) % wsCount
        keyboardWindowAddress = ""
    }
    function selectWindow(delta) {
        if (!keyboardWindows.length) { keyboardWindowAddress = ""; return }
        const index = keyboardWindows.findIndex(window => window.address === keyboardWindowAddress)
        const next = index < 0 ? (delta > 0 ? 0 : keyboardWindows.length - 1)
            : (index + delta + keyboardWindows.length) % keyboardWindows.length
        keyboardWindowAddress = keyboardWindows[next].address
    }
    function revealSelection() {
        if (!activeFocus || !barRevealed) return
        const group = workspaceItems.itemAt(keyboardWorkspaceId - wsBaseIndex) as WorkspaceGroup
        const target = group?.focusTarget()
        if (!target) return
        let ancestor = parent
        while (ancestor) {
            const viewport = ancestor as Flickable
            if (viewport && viewport.interactive) {
                const x = target.mapToItem(viewport.contentItem, 0, 0).x
                const left = x - Tokens.focusRing.width
                const right = x + target.width + Tokens.focusRing.width
                const next = x <= Tokens.spacing.small ? 0 : left < viewport.contentX ? left
                    : right > viewport.contentX + viewport.width ? right - viewport.width : viewport.contentX
                viewport.contentX = Math.max(0, Math.min(Math.max(0, viewport.contentWidth - viewport.width), next))
                return
            }
            ancestor = ancestor.parent
        }
    }
    onKeyboardWorkspaceIdChanged: Qt.callLater(revealSelection)
    onKeyboardWindowAddressChanged: Qt.callLater(revealSelection)
    onCompactPresentationChanged: Qt.callLater(revealSelection)
    function activateSelection() {
        if (!enabled || !barRevealed) return
        if (keyboardWindow) HyprlandDispatch.focusWindow(keyboardWindow.address)
        else HyprlandDispatch.focusWorkspace(keyboardWorkspaceId)
    }
    onKeyboardWindowsChanged: if (!keyboardWindow) keyboardWindowAddress = ""
    onActiveFocusChanged: if (activeFocus) {
        keyboardWorkspaceId = Math.max(wsBaseIndex, Math.min(wsBaseIndex + wsCount - 1, currentIndex))
        keyboardWindowAddress = ""
    }
    preferredWidth: { const revision = _metricRevision; return fullWidth() }
    minimumWidth: preferredWidth
    compactWidth: Tokens.spacing.medium + wsCount * chipSize + Math.max(0, wsCount - 1) * Tokens.spacing.extraSmall
    customHeight: controlHeight
    focusRingEnabled: false
    hoverable: false
    clickable: false
    activeFocusOnTab: enabled && barRevealed
    accessibleName: "Workspaces. " + (keyboardWindow ? windowDescription(keyboardWindow, keyboardWorkspaceId) : workspaceDescription(keyboardWorkspaceId))
    Accessible.role: Accessible.ToolBar
    Accessible.onPressAction: activateSelection()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            if (!event.isAutoRepeat) contextWorkspace(keyboardWorkspaceId)
        } else {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
            const key = Keycodes.key(event)
            if (key === Qt.Key_H || key === Qt.Key_Left) selectWorkspace(-1)
            else if (key === Qt.Key_L || key === Qt.Key_Right) selectWorkspace(1)
            else if (key === Qt.Key_J || key === Qt.Key_Down) selectWindow(1)
            else if (key === Qt.Key_K || key === Qt.Key_Up) selectWindow(-1)
            else if (key === Qt.Key_Escape && keyboardWindowAddress !== "") keyboardWindowAddress = ""
            else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
                if (!event.isAutoRepeat) activateSelection()
            } else return
        }
        event.accepted = true
    }
    wheelHandler: function(wheel) {
        wheel.accepted = true
        let acc = scrollAccumulator - wheel.angleDelta.y
        const offset = Math.sign(acc) * Math.floor(Math.abs(acc) / 120)
        scrollAccumulator = Math.sign(acc) * (Math.abs(acc) % 120)
        const id = Math.max(wsBaseIndex, Math.min(wsBaseIndex + wsCount - 1, currentIndex + offset))
        if (offset !== 0 && id !== currentIndex) HyprlandDispatch.focusWorkspace(id)
    }

    component WorkspaceGroup: Item {
        id: wsItem
        required property int index
        readonly property int wsIndex: workspaceWidget.wsBaseIndex + index
        readonly property var allWindows: workspaceWidget.windowsByWorkspace[wsIndex] ?? []
        readonly property var shownWindows: allWindows.slice(0, workspaceWidget.maxWindows)
        readonly property int overflow: Math.max(0, allWindows.length - workspaceWidget.maxWindows)
        readonly property bool hasWindows: allWindows.length > 0
        readonly property bool active: wsIndex === workspaceWidget.currentIndex
        readonly property bool showIcons: workspaceWidget.showWindows && hasWindows && !workspaceWidget.compactPresentation
        readonly property bool keySelected: workspaceWidget.activeFocus && workspaceWidget.keyboardWorkspaceId === wsIndex
        readonly property bool keyWindowShown: showIcons && shownWindows.some(window => window.address === workspaceWidget.keyboardWindowAddress)
        readonly property real fullWidth: workspaceWidget.chipSize + (workspaceWidget.showWindows && hasWindows ? shownWindows.length * workspaceWidget.controlHeight + (wsItem.overflow > 0 ? workspaceWidget.chipSize : 0) + Tokens.spacing.extraSmall : 0)
        function focusTarget() {
            if (!keyWindowShown) return header
            return windowRepeater.itemAt(shownWindows.findIndex(window => window.address === workspaceWidget.keyboardWindowAddress)) ?? header
        }
        implicitWidth: workspaceWidget.compactPresentation ? workspaceWidget.chipSize : fullWidth
        implicitHeight: workspaceWidget.controlHeight
        MaterialShape {
            anchors.fill: parent
            radius: Tokens.shape.small
            color: wsItem.active && workspaceWidget.pillIndicator ? Theme.secondaryContainer : wsItem.hasWindows ? Theme.surfaceContainer : Theme.surfaceContainerLow
            border.width: wsItem.hasWindows && !wsItem.active ? Tokens.size.outline : 0
        }
        StateLayer {
            hovered: headerMouse.containsMouse
            focused: wsItem.keySelected && !wsItem.keyWindowShown
            showFocusRing: focused
        }
        Item {
            id: header
            width: workspaceWidget.chipSize
            height: parent.height
            Accessible.role: Accessible.Button
            Accessible.name: workspaceWidget.workspaceDescription(wsItem.wsIndex)
            Accessible.onPressAction: if (enabled && workspaceWidget.barRevealed) HyprlandDispatch.focusWorkspace(wsItem.wsIndex)
            MaterialText {
                anchors.centerIn: parent
                text: String(wsItem.wsIndex)
                textStyle: "labelLarge"
                colorRole: wsItem.active ? (workspaceWidget.pillIndicator ? "onSecondaryContainer" : "primary") : wsItem.hasWindows ? "onSurface" : "onSurfaceVariant"
                Accessible.ignored: true
            }
            MaterialShape {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.spacing.extraSmall / 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: Tokens.spacing.extraSmall
                height: width
                radius: Tokens.shape.full
                color: Theme.primary
                visible: wsItem.active && !workspaceWidget.pillIndicator
            }
            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: {
                    workspaceWidget.forceActiveFocus(Qt.MouseFocusReason)
                    workspaceWidget.keyboardWorkspaceId = wsItem.wsIndex
                    workspaceWidget.keyboardWindowAddress = ""
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) workspaceWidget.contextWorkspace(wsItem.wsIndex)
                    else HyprlandDispatch.focusWorkspace(wsItem.wsIndex)
                }
            }
            TooltipItem {
                tooltip: workspaceWidget.tooltipManager
                owner: header
                show: workspaceWidget.barRevealed && (headerMouse.containsMouse || (wsItem.keySelected && !wsItem.keyWindowShown))
                text: wsItem.keySelected && workspaceWidget.keyboardWindow ? workspaceWidget.windowDescription(workspaceWidget.keyboardWindow, wsItem.wsIndex) : workspaceWidget.workspaceDescription(wsItem.wsIndex) + "\nRight-click: " + ((workspaceWidget.widgetConfig?.clickAction ?? "overview") === "overview" ? "Overview" : "More actions")
            }
        }
        Row {
            id: windowIconsRow
            anchors.left: header.right
            anchors.leftMargin: Tokens.spacing.extraSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: wsItem.showIcons
            spacing: 0
            Repeater {
                id: windowRepeater
                model: ScriptModel { values: wsItem.showIcons ? wsItem.shownWindows : []; objectProp: "address" }
                delegate: Item {
                    id: winIcon
                    required property var modelData
                    readonly property string windowClass: modelData.lastIpcObject?.class ?? ""
                    readonly property bool hasAppIcon: appIcon.status === Image.Ready
                    readonly property bool windowActive: modelData.activated ?? (Hyprland.activeToplevel?.address === modelData.address)
                    readonly property bool keySelected: wsItem.keySelected && workspaceWidget.keyboardWindowAddress === modelData.address
                    implicitWidth: workspaceWidget.controlHeight
                    implicitHeight: workspaceWidget.controlHeight
                    Accessible.role: Accessible.Button
                    Accessible.name: workspaceWidget.windowDescription(modelData, wsItem.wsIndex) + (windowActive ? " · Active window" : "")
                    Accessible.onPressAction: if (enabled && workspaceWidget.barRevealed) HyprlandDispatch.focusWindow(modelData.address)
                    MaterialShape {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.extraSmall / 2
                        radius: Tokens.shape.extraSmall
                        color: winIcon.windowActive ? Theme.primaryContainer : "transparent"
                    }
                    Image {
                        id: appIcon
                        anchors.centerIn: parent
                        width: workspaceWidget.iconFontSize
                        height: width
                        source: IconCategoryResolver.appIconSource(winIcon.windowClass)
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        // Quickshell's themed icon provider is not thread-safe.
                        asynchronous: false
                        visible: winIcon.hasAppIcon
                        Accessible.ignored: true
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !winIcon.hasAppIcon
                        iconName: IconCategoryResolver.getAppCategoryIcon(winIcon.windowClass, "terminal")
                        fontSize: workspaceWidget.iconFontSize
                        iconColor: winIcon.windowActive ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                    }
                    MaterialShape {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: Tokens.spacing.extraSmall / 2
                        width: Tokens.spacing.small
                        height: Tokens.size.tabIndicator
                        radius: Tokens.shape.full
                        color: Theme.primary
                        visible: winIcon.windowActive
                    }
                    StateLayer {
                        hovered: winMouse.containsMouse
                        pressed: winMouse.pressed
                        focused: winIcon.keySelected
                        showFocusRing: focused
                    }
                    MouseArea {
                        id: winMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: {
                            workspaceWidget.forceActiveFocus(Qt.MouseFocusReason)
                            workspaceWidget.keyboardWorkspaceId = wsItem.wsIndex
                            workspaceWidget.keyboardWindowAddress = winIcon.modelData.address
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) workspaceWidget.contextWorkspace(wsItem.wsIndex)
                            else HyprlandDispatch.focusWindow(winIcon.modelData.address)
                        }
                    }
                    TooltipItem {
                        tooltip: workspaceWidget.tooltipManager
                        owner: winIcon
                        show: workspaceWidget.barRevealed && wsItem.showIcons && (winMouse.containsMouse || winIcon.keySelected)
                        text: workspaceWidget.windowDescription(winIcon.modelData, wsItem.wsIndex)
                    }
                }
            }
            Item {
                id: overflowButton
                    objectName: "workspaceOverflow" + wsItem.wsIndex
                visible: wsItem.overflow > 0
                width: wsItem.overflow > 0 ? workspaceWidget.chipSize : 0
                height: workspaceWidget.controlHeight
                Accessible.role: Accessible.Button
                Accessible.name: "Show " + wsItem.overflow + " more windows on workspace " + wsItem.wsIndex
                Accessible.onPressAction: if (enabled && workspaceWidget.barRevealed) workspaceWidget.openOverview(wsItem.wsIndex)
                MaterialText { anchors.centerIn: parent; text: "+" + wsItem.overflow; textStyle: "labelSmall"; Accessible.ignored: true }
                StateLayer { hovered: overflowMouse.containsMouse; pressed: overflowMouse.pressed; showFocusRing: false }
                MouseArea { id: overflowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: workspaceWidget.openOverview(wsItem.wsIndex) }
                TooltipItem { tooltip: workspaceWidget.tooltipManager; owner: overflowButton; show: workspaceWidget.barRevealed && overflowMouse.containsMouse; text: overflowButton.Accessible.name }
            }
        }
    }

    RowLayout {
        spacing: Tokens.spacing.extraSmall
        Repeater {
            id: workspaceItems
            model: workspaceWidget.wsCount
            onItemAdded: workspaceWidget._metricRevision++
            onItemRemoved: workspaceWidget._metricRevision++
            delegate: WorkspaceGroup {}
        }
    }
}
