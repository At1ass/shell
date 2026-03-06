pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.feedback

PanelWindow {
    id: dock

    readonly property string screenName: screen ? screen.name : ""
    readonly property bool autoHide: AppConfig.dockAutoHide
    readonly property int iconSize: AppConfig.dockIconSize
    readonly property int dockPadding: Tokens.spacing.small
    readonly property int dockSpacing: Tokens.spacing.extraSmall

    // The actual dock bar height
    readonly property int dockBarHeight: iconSize + 20 + dockPadding * 2

    // Reveal state — HoverHandler OR active preview keeps dock visible
    readonly property bool shouldReveal: !autoHide || dockHover.hovered || _previewShowing
    property bool contextMenuOpen: false

    // === Preview state ===
    property int _pendingPreviewIdx: -1
    property int _previewIdx: -1
    property real _previewCenterX: 0
    property bool _previewHovered: false
    readonly property int _previewThumbHeight: 180
    readonly property int _previewCardHeight: _previewThumbHeight + 26 + Tokens.spacing.medium * 2

    // Does NOT depend on shouldReveal — breaks feedback loop
    readonly property bool _previewShowing: _previewIdx >= 0 && _previewToplevels.length > 0

    readonly property var _previewToplevels: {
        if (_previewIdx < 0 || _previewIdx >= dockModel.length) return []
        const item = dockModel[_previewIdx]
        if (!item || item.windows.length < 1) return []
        const appId = item.appId.toLowerCase()
        const all = ToplevelManager.toplevels?.values ?? []
        let matched = []
        for (let i = 0; i < all.length; i++) {
            if ((all[i].appId || "").toLowerCase() === appId)
                matched.push(all[i])
        }
        return matched
    }

    Timer {
        id: previewShowTimer
        interval: 400
        onTriggered: dock._previewIdx = dock._pendingPreviewIdx
    }

    Timer {
        id: previewHideTimer
        interval: 300
        onTriggered: {
            if (!dock._previewHovered) {
                dock._previewIdx = -1
                dock._pendingPreviewIdx = -1
            }
        }
    }

    color: "transparent"
    exclusiveZone: AppConfig.dockExclusive ? dockBarHeight : 0
    WlrLayershell.namespace: "shell:dock"
    WlrLayershell.layer: WlrLayershell.Top

    // Input mask — only interactive areas receive events, rest passes through
    mask: Region { item: maskItem }

    anchors {
        left: true
        right: true
        bottom: true
    }

    // Height: always includes preview space when revealed.
    // The mask handles input passthrough, so the tall window doesn't block clicks.
    implicitHeight: {
        if (autoHide) {
            if (!shouldReveal && dockBar.opacity < 0.01) return 4
            return dockBarHeight + _previewCardHeight + Tokens.spacing.small
        }
        return dockBarHeight + _previewCardHeight + Tokens.spacing.small
    }

    // Mask item defines the Wayland input region.
    // Only this area receives hover/click events; rest passes through to windows below.
    Item {
        id: maskItem
        visible: false
        x: {
            // Hidden: trigger strip matching dock bar width
            if (autoHide && !shouldReveal && dockBar.opacity < 0.01) return dockBar.x
            // Preview: bounding box of dock bar + preview card
            if (_previewShowing && previewCard.visible)
                return Math.min(dockBar.x, previewCard.x)
            return dockBar.x
        }
        width: {
            if (autoHide && !shouldReveal && dockBar.opacity < 0.01) return dockBar.width
            if (_previewShowing && previewCard.visible) {
                const right = Math.max(dockBar.x + dockBar.width, previewCard.x + previewCard.width)
                return right - x
            }
            return dockBar.width
        }
        y: {
            if (autoHide && !shouldReveal && dockBar.opacity < 0.01)
                return dock.height - 1
            if (_previewShowing && previewCard.visible)
                return previewCard.y
            return dockBar.y
        }
        height: dock.height - y
    }

    // HoverHandler propagates through child MouseAreas — no flicker
    HoverHandler {
        id: dockHover
    }

    // === Model: pinned + running apps ===
    readonly property var pinnedIds: AppConfig.dockPinnedApps
    readonly property var toplevels: Hyprland.toplevels ? Hyprland.toplevels.values : []

    // Group running windows by class
    readonly property var runningGroups: {
        let groups = {}
        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i]
            const cls = tl.lastIpcObject?.class ?? ""
            if (!cls) continue
            if (!groups[cls]) groups[cls] = []
            groups[cls].push(tl)
        }
        return groups
    }

    function findDesktopEntry(appId) {
        const apps = DesktopEntries.applications.values
        const lower = appId.toLowerCase()
        for (let i = 0; i < apps.length; i++) {
            const id = (apps[i].id || "").toLowerCase()
            if (id === lower || id === lower + ".desktop") return apps[i]
            const name = (apps[i].name || "").toLowerCase()
            if (name === lower) return apps[i]
        }
        return null
    }

    // Build dock model: [{appId, entry, windows, pinned}]
    readonly property var dockModel: {
        let items = []
        let seen = new Set()

        for (let i = 0; i < pinnedIds.length; i++) {
            const id = pinnedIds[i]
            const entry = findDesktopEntry(id)
            const windows = runningGroups[id] || []
            items.push({ appId: id, entry: entry, windows: windows, pinned: true })
            seen.add(id)
        }

        const classes = Object.keys(runningGroups)
        for (let i = 0; i < classes.length; i++) {
            const cls = classes[i]
            if (seen.has(cls)) continue
            const entry = findDesktopEntry(cls)
            items.push({ appId: cls, entry: entry, windows: runningGroups[cls], pinned: false })
        }

        return items
    }

    // === Preview popup ===
    Rectangle {
        id: previewCard
        visible: dock._previewShowing
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.92
        transformOrigin: Item.Bottom

        anchors.bottom: dockBar.top
        anchors.bottomMargin: Tokens.spacing.extraSmall

        x: {
            const margin = Tokens.spacing.small
            const targetX = dock._previewCenterX - width / 2
            return Math.max(margin, Math.min(targetX, dock.width - width - margin))
        }

        width: previewRow.implicitWidth + Tokens.spacing.medium * 2
        height: previewRow.implicitHeight + Tokens.spacing.medium * 2
        radius: Tokens.shape.large
        color: Qt.alpha(Theme.surfaceContainer, 0.95)
        clip: true

        // Surface tint
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: 0.06
            radius: parent.radius
        }

        Behavior on opacity {
            NumberAnimation { duration: Tokens.motion.duration.short4 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Easing.OutCubic
            }
        }

        // Animate horizontal position when switching between icons
        Behavior on x {
            NumberAnimation {
                duration: Tokens.motion.duration.short3
                easing.type: Easing.OutCubic
            }
        }

        // Hover tracking on preview card — keeps preview alive
        HoverHandler {
            id: previewHoverHandler
            onHoveredChanged: {
                dock._previewHovered = hovered
                if (hovered) {
                    previewHideTimer.stop()
                } else {
                    previewHideTimer.restart()
                }
            }
        }

        Row {
            id: previewRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Repeater {
                model: dock._previewToplevels

                delegate: Item {
                    id: previewDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isFocused: modelData.activated

                    width: thumbColumn.implicitWidth
                    height: thumbColumn.implicitHeight

                    Column {
                        id: thumbColumn
                        spacing: 4

                        Rectangle {
                            id: thumbContainer
                            width: Math.max(screencopyView.implicitWidth > 0 ? screencopyView.implicitWidth : 280, 240)
                            height: dock._previewThumbHeight
                            radius: Tokens.shape.small
                            color: previewDelegate.isFocused
                                   ? Qt.alpha(Theme.primaryContainer, 0.5)
                                   : Qt.alpha(Theme.surfaceContainerHighest, 0.5)
                            clip: true

                            border.width: previewDelegate.isFocused ? 2 : 0
                            border.color: Theme.primary

                            ScreencopyView {
                                id: screencopyView
                                anchors.centerIn: parent
                                captureSource: previewDelegate.modelData
                                live: true
                                constraintSize: Qt.size(280, dock._previewThumbHeight - 4)
                                visible: hasContent
                            }

                            // Fallback when no content yet
                            Image {
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                visible: !screencopyView.hasContent
                                source: {
                                    if (dock._previewIdx < 0 || dock._previewIdx >= dock.dockModel.length)
                                        return "image://icon/application-x-executable"
                                    const entry = dock.dockModel[dock._previewIdx]?.entry
                                    const icon = entry?.icon ?? ""
                                    return icon ? "image://icon/" + icon : "image://icon/application-x-executable"
                                }
                                sourceSize: Qt.size(48, 48)
                                opacity: 0.5
                            }

                            StateLayer {
                                layerColor: Theme.onSurface
                                hovered: thumbMouse.containsMouse
                                pressed: thumbMouse.pressed
                            }

                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    previewDelegate.modelData.activate()
                                    dock._previewIdx = -1
                                    dock._pendingPreviewIdx = -1
                                }
                            }
                        }

                        Text {
                            width: thumbContainer.width
                            text: previewDelegate.modelData.title || "Untitled"
                            color: Theme.onSurface
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // === Dock bar ===
    Rectangle {
        id: dockBar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.spacing.small

        width: dockRow.implicitWidth + dock.dockPadding * 2
        height: dockRow.implicitHeight + dock.dockPadding * 2
        radius: Tokens.shape.large
        color: Qt.alpha(Theme.surfaceContainer, 0.90)
        clip: false

        // Surface tint
        Rectangle {
            anchors.fill: parent
            color: Theme.primary
            opacity: 0.08
            radius: parent.radius
        }

        // Scale + opacity animation (no translate — avoids Wayland clipping)
        scale: dock.shouldReveal ? 1.0 : 0.85
        opacity: dock.shouldReveal ? 1.0 : 0.0
        transformOrigin: Item.Bottom
        visible: opacity > 0

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.motion.duration.medium1
                easing.type: dock.shouldReveal ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.5
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
            }
        }

        RowLayout {
            id: dockRow
            anchors.centerIn: parent
            spacing: dock.dockSpacing

            Repeater {
                model: dock.dockModel

                delegate: Item {
                    id: iconDelegate
                    required property var modelData
                    required property int index

                    readonly property var app: modelData
                    readonly property bool isActive: app.windows.length > 0
                    readonly property bool isFocused: {
                        for (let i = 0; i < app.windows.length; i++) {
                            if (app.windows[i].activated) return true
                        }
                        return false
                    }
                    readonly property bool showSeparator: {
                        if (!app.pinned && index > 0 && dock.dockModel[index - 1].pinned)
                            return true
                        return false
                    }

                    implicitWidth: (showSeparator ? separatorRect.width + dock.dockSpacing : 0) + iconButton.width
                    implicitHeight: dock.iconSize + 12
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: separatorRect
                        visible: iconDelegate.showSeparator
                        width: 1
                        height: dock.iconSize * 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        color: Qt.alpha(Theme.outline, 0.4)
                    }

                    Rectangle {
                        id: iconButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: dock.iconSize + 8
                        height: dock.iconSize + 8
                        radius: Tokens.shape.medium
                        color: "transparent"

                        property bool hovered: iconMouseArea.containsMouse
                        scale: hovered ? 1.1 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Tokens.motion.duration.short3
                                easing.type: Easing.OutBack
                                easing.overshoot: 2
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: dock.iconSize
                            height: dock.iconSize
                            source: {
                                const icon = iconDelegate.app.entry?.icon ?? ""
                                if (icon) return "image://icon/" + icon
                                return "image://icon/application-x-executable"
                            }
                            sourceSize: Qt.size(dock.iconSize, dock.iconSize)
                            smooth: true
                            opacity: iconDelegate.isActive || iconDelegate.app.pinned ? 1.0 : 0.5
                        }

                        StateLayer {
                            layerColor: Theme.onSurface
                            hovered: iconButton.hovered
                            pressed: iconMouseArea.pressed
                        }

                        MouseArea {
                            id: iconMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            onContainsMouseChanged: {
                                if (containsMouse && iconDelegate.app.windows.length > 0) {
                                    // Running app — show or switch preview
                                    previewHideTimer.stop()

                                    const pos = iconButton.mapToItem(null, iconButton.width / 2, 0)
                                    dock._previewCenterX = pos.x
                                    dock._pendingPreviewIdx = iconDelegate.index

                                    if (dock._previewIdx >= 0) {
                                        // Already showing preview — switch instantly
                                        dock._previewIdx = iconDelegate.index
                                        previewShowTimer.stop()
                                    } else {
                                        // First reveal — use delay
                                        previewShowTimer.restart()
                                    }
                                } else if (containsMouse) {
                                    // Non-running pinned icon — just cancel pending preview
                                    previewShowTimer.stop()
                                    dock._pendingPreviewIdx = -1
                                    if (dock._previewIdx >= 0)
                                        previewHideTimer.restart()
                                } else {
                                    // Mouse left this icon
                                    previewShowTimer.stop()
                                    if (dock._previewIdx === iconDelegate.index
                                        || dock._pendingPreviewIdx === iconDelegate.index) {
                                        previewHideTimer.restart()
                                    }
                                }
                            }

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (iconDelegate.app.entry)
                                        iconDelegate.app.entry.execute()
                                    return
                                }

                                if (iconDelegate.app.windows.length === 0) {
                                    if (iconDelegate.app.entry)
                                        iconDelegate.app.entry.execute()
                                } else if (iconDelegate.app.windows.length === 1) {
                                    const addr = iconDelegate.app.windows[0].lastIpcObject?.address ?? ""
                                    if (addr)
                                        Hyprland.dispatch("focuswindow address:" + addr)
                                } else {
                                    let currentIdx = -1
                                    for (let i = 0; i < iconDelegate.app.windows.length; i++) {
                                        if (iconDelegate.app.windows[i].activated) {
                                            currentIdx = i
                                            break
                                        }
                                    }
                                    const nextIdx = (currentIdx + 1) % iconDelegate.app.windows.length
                                    const addr = iconDelegate.app.windows[nextIdx].lastIpcObject?.address ?? ""
                                    if (addr)
                                        Hyprland.dispatch("focuswindow address:" + addr)
                                }
                            }
                        }

                        // QtQuick.Controls ToolTip — no tooltipManager available in dock
                        ToolTip {
                            visible: iconMouseArea.containsMouse && dock._previewIdx !== iconDelegate.index
                            text: {
                                const name = iconDelegate.app.entry?.name ?? iconDelegate.app.appId
                                const count = iconDelegate.app.windows.length
                                return count > 1 ? name + " (" + count + ")" : name
                            }
                            delay: 400
                        }
                    }

                    // Running indicator dots
                    Row {
                        anchors.horizontalCenter: iconButton.horizontalCenter
                        anchors.top: iconButton.bottom
                        anchors.topMargin: 1
                        spacing: 3
                        visible: iconDelegate.isActive

                        Repeater {
                            model: Math.min(iconDelegate.app.windows.length, 3)

                            Rectangle {
                                required property int index
                                width: iconDelegate.isFocused && index === 0 ? 10 : 4
                                height: 4
                                radius: 2
                                color: iconDelegate.isFocused ? Theme.primary : Theme.onSurfaceVariant

                                Behavior on width {
                                    NumberAnimation { duration: Tokens.motion.duration.short3 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Tokens.motion.duration.short3 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
