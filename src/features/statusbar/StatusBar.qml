pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.ui.base
import qs.src.core.services
import qs.src.features.statusbar
import qs.src.ui.containers
import qs.src.ui.feedback

PanelWindow {
    id: statusBar

    readonly property TooltipManager tooltip: tooltipManager
    // Per-section widget lists, updated ONLY when their JSON content really
    // changes. AppConfig.data is a fresh object on every config hot-reload,
    // so binding Repeater models straight to a .filter() of it would destroy
    // and recreate every bar widget on any unrelated config edit.
    property var leftWidgets: []
    property var centerWidgets: []
    property var rightWidgets: []

    function _syncWidgets() {
        const widgets = AppConfig.ready ? (AppConfig.barWidgets || []) : []
        const next = { "left": [], "center": [], "right": [] }
        for (const w of widgets) {
            const section = w.section || "left"
            if (next[section]) next[section].push(w)
        }
        if (JSON.stringify(next.left) !== JSON.stringify(leftWidgets)) leftWidgets = next.left
        if (JSON.stringify(next.center) !== JSON.stringify(centerWidgets)) centerWidgets = next.center
        if (JSON.stringify(next.right) !== JSON.stringify(rightWidgets)) rightWidgets = next.right
    }

    Connections {
        target: AppConfig
        function onReadyChanged() { statusBar._syncWidgets() }
        function onDataChanged() { statusBar._syncWidgets() }
    }
    Component.onCompleted: _syncWidgets()
    readonly property ShellScreen targetScreen: screen as ShellScreen
    readonly property string screenName: targetScreen?.name ?? ""
    // property ShellScreen screen: null

    readonly property bool autoHide: AppConfig.barAutoHide

    // Reveal when auto-hide is off, while the cursor is over the bar / top
    // trigger strip, OR while this bar owns something on screen.
    //
    // That last clause is the whole point: clicking a tray icon opens the
    // popouts window — a FULLSCREEN layer surface above the bar with a focus
    // grab — so the pointer is no longer over the bar, `barHover.hovered` drops,
    // and the bar slid away out from under the menu the click had just opened.
    // The dock has always had the equivalent (`_previewShowing || contextMenu.open`);
    // the bar tracked hover and nothing else.
    readonly property bool revealed: !autoHide || barHover.hovered
                                     || _ownsPopout || _ownsConnections || _ownsAudio || _ownsDashboard

    // A popout is ours when the item that requested it lives in this bar's
    // scene. Checking by screen would be wrong (two bars, one popout) and
    // checking PopoutsState.open alone would pin every bar open at once.
    readonly property bool _ownsPopout: PopoutsState.open
                                        && statusBar._isOwnItem(PopoutsState.sourceItem)

    readonly property bool _ownsConnections: GlobalStates.connectionsOpen
        && statusBar._isOwnItem(GlobalStates.connectionsSource)

    readonly property bool _ownsDashboard: GlobalStates.dashboardOpen
        && GlobalStates.activePanelScreen?.name === statusBar.screenName

    readonly property bool _ownsAudio: GlobalStates.audioOpen
        && statusBar._isOwnItem(GlobalStates.audioSource)


    function _isOwnItem(item) {
        for (let p = item; p; p = p.parent) {
            if (p === statusBar.contentItem) return true
        }
        return false
    }

    // The window keeps a constant height (no preview/menu like the dock), so the input mask
    // does all the passthrough work and there is no resize-induced HoverHandler flicker.
    implicitHeight: BarMetrics.height
    color: "transparent"

    // Auto-hide reserves no screen space and overlays windows (Ignore); a fixed bar lets
    // Auto reserve its height from the three anchors. We deliberately do NOT assign
    // `exclusiveZone`: writing it force-switches exclusionMode to Normal, and an initial
    // value of 0 does not take effect until the first change — which left space reserved at
    // startup whenever auto-hide was already on. Driving exclusionMode directly avoids that.
    exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    WlrLayershell.namespace: "shell:bar"

    anchors {
        left: true
        top: AppConfig.barPosition !== "bottom"
        bottom: AppConfig.barPosition === "bottom"
        right: true
    }

    // HoverHandler propagates through child MouseAreas (same pattern as the dock). It only
    // sees pointer events inside the Wayland input region below, so when hidden it fires
    // solely on the 1px top trigger strip.
    HoverHandler {
        id: barHover
    }

    // Input mask = full bar rect when revealed, a 1px strip at the top screen edge when
    // hidden. Transparent areas pass clicks through to windows below. The strip is used only
    // once the hide animation has finished (opacity < 0.01), mirroring the dock, so a
    // re-entry mid-fade re-reveals without flicker.
    mask: Region { item: barMaskItem }

    Item {
        id: barMaskItem
        visible: false

        readonly property bool _strip: statusBar.autoHide && !statusBar.revealed
                                       && barBackground.opacity < 0.01

        x: 0
        y: AppConfig.barPosition === "bottom" && _strip ? statusBar.height - height : 0
        width: statusBar.width
        height: _strip ? 1 : statusBar.height
    }

    TooltipManager {
        id: tooltipManager
        bar: statusBar
        suspended: GlobalStates.activePanel !== "" || PopoutsState.open || GlobalStates.lockscreenActive
    }

    Surface {
        id: barBackground
        radius: Tokens.shape.none
        outlined: false

        anchors.fill: parent

        // Scale + opacity reveal (no translate — avoids Wayland clipping). Scales from the
        // top screen edge. MD3 emphasized: decelerate on appear, accelerate on hide.
        scale: statusBar.revealed ? 1.0 : 0.85
        opacity: statusBar.revealed ? 1.0 : 0.0
        transformOrigin: AppConfig.barPosition === "bottom" ? Item.Bottom : Item.Top
        visible: opacity > 0

        Behavior on scale {
            MotionAnimation {
                duration: statusBar.revealed ? Tokens.motion.duration.medium2 : Tokens.motion.duration.short4
                curve: statusBar.revealed ? "emphasizedDecelerate" : "emphasizedAccelerate"
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Tokens.motion.duration.short4 }
        }

        color: AppConfig.barTransparent ? "transparent" : Qt.alpha(Theme.surfaceContainer, 0.90)
        // Primary surface tint (elevation token scale)
        SurfaceTint {
            level: 4
            visible: !AppConfig.barTransparent
        }

        BarLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            leftWidgets: statusBar.leftWidgets
            centerWidgets: statusBar.centerWidgets
            rightWidgets: statusBar.rightWidgets
            screenName: statusBar.screenName
            tooltipManager: statusBar.tooltip
            barRevealed: statusBar.revealed
        }
    }
}
