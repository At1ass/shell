pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.features.statusbar
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.inputs

PanelWindow {
    id: statusBar

    readonly property TooltipManager tooltip: tooltipManager
    readonly property var barWidgets: AppConfig.ready ? (AppConfig.barWidgets || []) : []
    readonly property string screenName: screen ? screen.name : ""
    // property ShellScreen screen: null

    readonly property bool autoHide: AppConfig.barAutoHide
    // Reveal when auto-hide is off, or while the cursor is over the bar / top trigger strip.
    readonly property bool revealed: !autoHide || barHover.hovered

    // The window keeps a constant height (no preview/menu like the dock), so the input mask
    // does all the passthrough work and there is no resize-induced HoverHandler flicker.
    implicitHeight: AppConfig.barHeight
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
        top: true
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
        y: 0
        width: statusBar.width
        height: _strip ? 1 : statusBar.height
    }

    TooltipManager {
        id: tooltipManager
        bar: statusBar
    }

    Rectangle {
        id: barBackground

        anchors.fill: parent

        // Scale + opacity reveal (no translate — avoids Wayland clipping). Scales from the
        // top screen edge. MD3 emphasized: decelerate on appear, accelerate on hide.
        scale: statusBar.revealed ? 1.0 : 0.85
        opacity: statusBar.revealed ? 1.0 : 0.0
        transformOrigin: Item.Top
        visible: opacity > 0

        Behavior on scale {
            NumberAnimation {
                duration: statusBar.revealed ? Tokens.motion.duration.medium2 : Tokens.motion.duration.short4
                easing.type: statusBar.revealed ? Tokens.motion.easing.emphasizedDecelerate
                                                : Tokens.motion.easing.emphasizedAccelerate
                easing.bezierCurve: statusBar.revealed ? Tokens.motion.easing.emphasizedDeceleratePoints
                                                       : Tokens.motion.easing.emphasizedAcceleratePoints
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

        // Center zone — pinned to the screen centre, width follows its own content. It is
        // the layout anchor: the left/right zones fill the gaps on either side of it, so a
        // wide left zone (e.g. many workspace windows) can never overrun the centre.
        Item {
            id: centerZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: centerSection.implicitWidth
            clip: true

            RowLayout {
                id: centerSection
                spacing: Tokens.spacing.small
                anchors.centerIn: parent

                Repeater {
                    model: statusBar.barWidgets.filter(w => (w.section || "left") === "center")
                    delegate: BarWidgetLoader {
                        required property var modelData
                        screenName: statusBar.screenName
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }

        // Left zone — from the screen edge up to the centre zone. Content is left-aligned;
        // overflow is clipped on the inner (centre-facing) edge rather than overlapping.
        Item {
            anchors.left: parent.left
            anchors.right: centerZone.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            clip: true

            RowLayout {
                id: leftSection
                spacing: Tokens.spacing.small
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: statusBar.barWidgets.filter(w => (w.section || "left") === "left")
                    delegate: BarWidgetLoader {
                        required property var modelData
                        screenName: statusBar.screenName
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }

        // Right zone — from the centre zone to the screen edge. Content is right-aligned.
        Item {
            anchors.left: centerZone.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            clip: true

            RowLayout {
                id: rightSection
                spacing: Tokens.spacing.small
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: statusBar.barWidgets.filter(w => (w.section || "left") === "right")
                    delegate: BarWidgetLoader {
                        required property var modelData
                        screenName: statusBar.screenName
                        widgetConfig: modelData
                        tooltipManager: statusBar.tooltip
                    }
                }
            }
        }
    }
}
