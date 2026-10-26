import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: true
    clip: true
    animated: false
    hoverable: true

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool compact: widgetSettings.compact ?? false
    property bool showIcon: widgetSettings.showIcon ?? true
    property int maxWidth: widgetSettings.maxWidth ?? 0

    property var tooltipManager: null

    // Show when there's an active player
    property bool shown: MprisController.activePlayer !== null

    readonly property real buttonWidth: Math.max(Tokens.size.iconButton, Tokens.touchTarget.minimum)
    readonly property real baseWidth: (showIcon ? mediaGlyph.implicitWidth + Tokens.spacing.extraSmall : 0) + Tokens.spacing.medium
    minimumWidth: baseWidth + buttonWidth * (compact ? 1 : 3) + Tokens.spacing.extraSmall * (compact ? 0 : 3)
    preferredWidth: minimumWidth + (compact ? 0 : Math.min(trackInfoText.implicitWidth, maxWidth > 0 ? maxWidth : Tokens.size.fieldWidth))
    compactWidth: baseWidth + buttonWidth

    nonVisualChildren: [
        // Simple hover tooltip for track info
        TooltipItem {
            id: hoverTooltip
            tooltip: root.tooltipManager
            owner: root
            show: root.hovered && root.barRevealed && !!MprisController.activePlayer
            text: MprisController.activeTrack
                ? `${MprisController.activeTrack.title || "Unknown Title"} — ${MprisController.activeTrack.artist || "Unknown Artist"}`
                : "Nothing playing"
        }
    ]

    clickHandler: function (mouse) {
        if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
            GlobalStates.handleClickAction(root.widgetConfig?.clickAction ?? "dashboard-quick");
            mouse.accepted = true;
            return;
        }

        mouse.accepted = false;
    }

    // Main content - compact display on bar
    RowLayout {
        id: mediaContent
        width: Math.max(0, root.width - Tokens.spacing.medium)
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            id: mediaGlyph
            visible: root.showIcon
            iconName: "music_note"
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        // Compact is a fixed icon/control footprint; details live in the tooltip.
        MaterialText {
            id: trackInfoText
            text: {
                if (!MprisController.activeTrack)
                    return "Nothing playing";
                const title = MprisController.activeTrack.title || "Unknown Title";
                const artist = MprisController.activeTrack.artist || "Unknown Artist";
                return `${title} — ${artist}`;
            }
            textStyle: "bodyMedium"
            colorRole: "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: Layout.preferredWidth > 0
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: root.compact || root.compactPresentation ? 0 : Math.min(implicitWidth, root.maxWidth > 0 ? root.maxWidth : Tokens.size.fieldWidth)
            Layout.alignment: Qt.AlignVCenter


        }

        // Expanded media controls keep a stable width.
        IconButton {
            variant: "standard"
            visible: !root.compact && !root.compactPresentation
            Accessible.name: "Previous track"
            iconName: "skip_previous"
            iconSize: Tokens.iconSize.large
            containerSize: Tokens.size.iconButton
            touchTargetSize: Tokens.touchTarget.minimum
            enabled: MprisController.canGoPrevious
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity
            onClicked: MprisController.previous()

            Behavior on opacity {
                enabled: root.barRevealed
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }

        // Play/Pause button - always visible
        IconButton {
            variant: "standard"
            Accessible.name: MprisController.isPlaying ? "Pause" : "Play"
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            iconSize: Tokens.iconSize.large
            containerSize: Tokens.size.iconButton
            touchTargetSize: Tokens.touchTarget.minimum
            enabled: MprisController.canTogglePlaying
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            visible: true
            onClicked: MprisController.togglePlaying()
        }

        // Next is hidden only by the configured compact mode.
        IconButton {
            variant: "standard"
            visible: !root.compact && !root.compactPresentation
            Accessible.name: "Next track"
            iconName: "skip_next"
            iconSize: Tokens.iconSize.large
            containerSize: Tokens.size.iconButton
            touchTargetSize: Tokens.touchTarget.minimum
            enabled: MprisController.canGoNext
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            opacity: enabled ? 1.0 : Tokens.state.disabledContentOpacity
            onClicked: MprisController.next()

            Behavior on opacity {
                enabled: root.barRevealed
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }
    }
}
