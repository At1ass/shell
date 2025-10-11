import QtQuick
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: false
    hoverable: true

    property var tooltipManager: null

    // Always visible for testing - comment out to hide when no player
    visible: true
    // visible: (typeof MprisController !== 'undefined') && MprisController.activePlayer !== null

    implicitWidth: content.width + Config.spacing.small * 2
    // minWidth: content.implicitWidth

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
                        return "Нет воспроизведения";
                    const title = MprisController.activeTrack.title || "Unknown Title";
                    const artist = MprisController.activeTrack.artist || "Unknown Artist";
                    return `${title} — ${artist}`;
                }
                textStyle: "bodyMedium"
                colorRole: "onSurface"
            }
        }

        // MediaControls теперь управляется через GlobalStates
        // Удален старый MPRISPopup

    ]

    onClicked: function (mouse) {
        if (mouse && mouse.button === Qt.RightButton) {
            GlobalStates.dashboardOpenIndex = 1
            GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
        }
    }

    // Main content - compact display on bar
    RowLayout {
        id: content
        spacing: Config.spacing.none

        // Previous button
        IconButton {
            variant: "standard"
            iconName: "skip_previous"
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
            iconColor: Config.colors.onSurface
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.previous();
                }
            }
        }

        IconButton {
            variant: "standard"
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
            iconColor: Config.colors.onSurface
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.togglePlaying();
                }
            }
        }

        // Next button
        IconButton {
            variant: "standard"
            iconName: "skip_next"
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
            iconColor: Config.colors.onSurface
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.next();
                }
            }
        }

        property Scope positionInfo: Scope {
            id: positionInfo

            property var player: MprisController.activePlayer
            property int position: Math.floor(MprisController.position)
            property int length: Math.floor(MprisController.length)

            FrameAnimation {
                id: posTracker
                running: MprisController.isPlaying && hoverTooltip.visible
                onTriggered: positionInfo.player.positionChanged()
            }

            function timeStr(time: int): string {
                const seconds = time % 60;
                const minutes = Math.floor(time / 60);

                return `${minutes}:${seconds.toString().padStart(2, '0')}`;
            }
        }
    }
}
