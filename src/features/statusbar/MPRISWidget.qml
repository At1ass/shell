import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
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
    visible: (typeof MprisController !== 'undefined') && MprisController.activePlayer !== null

    implicitWidth: content.implicitWidth + Tokens.spacing.small * 2

    nonVisualChildren: [
        // Simple hover tooltip for track info
        TooltipItem {
            id: hoverTooltip
            tooltip: root.tooltipManager
            owner: root
            isMenu: false
            hoverable: true
            show: root.hovered && (typeof MprisController !== 'undefined') && !!MprisController.activePlayer

            MaterialText {
                text: {
                    if (typeof MprisController === 'undefined' || !MprisController.activeTrack)
                        return "Nothing playing";
                    const title = MprisController.activeTrack.title || "Unknown Title";
                    const artist = MprisController.activeTrack.artist || "Unknown Artist";
                    return `${title} — ${artist}`;
                }
                textStyle: "bodyMedium"
                colorRole: "onSurface"
            }
        }
    ]

    clickHandler: function (mouse) {
        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction);
            mouse.accepted = true;
            return;
        }

        mouse.accepted = false;
    }

    // Main content - compact display on bar
    RowLayout {
        id: content
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: "music_note"
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        // Track info — expands from 0 to its full width on hover.
        MaterialText {
            id: trackInfoText
            text: {
                if (typeof MprisController === "undefined" || !MprisController.activeTrack)
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
            Layout.preferredWidth: root.hovered ? 260 : 0
            Layout.alignment: Qt.AlignVCenter

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                    easing.type: Tokens.motion.easing.standard
                }
            }
        }

        // Previous button - visible on hover, enabled if action available
        IconButton {
            variant: "standard"
            iconName: "skip_previous"
            iconSize: Tokens.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            opacity: enabled ? 1.0 : 0.38
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.previous();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }

        // Play/Pause button - always visible
        IconButton {
            variant: "standard"
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            iconSize: Tokens.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            visible: true
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.togglePlaying();
                }
            }
        }

        // Next button - visible on hover, enabled if action available
        IconButton {
            variant: "standard"
            iconName: "skip_next"
            iconSize: Tokens.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
            iconColor: enabled ? Theme.onSurface : Theme.onSurfaceVariant
            opacity: enabled ? 1.0 : 0.38
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.next();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }
    }
}
