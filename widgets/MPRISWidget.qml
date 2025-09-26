import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.components.base
import qs.components.tooltip
import qs.components.popup
import qs.config
import qs.services

BarElement {
    id: root
    clickable: false
    hoverable: true

    property var tooltipManager: null
    property bool menuOpen: GlobalStates.mediaControlsOpen


    // Always visible for testing - comment out to hide when no player
    visible: true
    // visible: (typeof MprisController !== 'undefined') && MprisController.activePlayer !== null

    implicitWidth: content.width + 12
    // minWidth: content.implicitWidth

    nonVisualChildren: [
        // Simple hover tooltip for track info
        TooltipItem {
            id: hoverTooltip
            tooltip: root.tooltipManager
            owner: root
            isMenu: false
            hoverable: true
            show: root.hovered && (typeof MprisController !== 'undefined') && !!MprisController.activePlayer && !root.menuOpen

            MaterialText {
                text: {
                    if (typeof MprisController === 'undefined' || !MprisController.activeTrack) return "Нет воспроизведения"
                    const title = MprisController.activeTrack.title || "Unknown Title"
                    const artist = MprisController.activeTrack.artist || "Unknown Artist"
                    return `${title} — ${artist}`
                }
                textStyle: "bodyMedium"
                colorRole: "surfaceText"
            }
        }

        // MediaControls теперь управляется через GlobalStates
        // Удален старый MPRISPopup
    ]

    onClicked: function(mouse) {
        if (mouse && mouse.button === Qt.RightButton) {
            console.log("MPRISWidget clicked, current state:", GlobalStates.mediaControlsOpen)
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    // Main content - compact display on bar
    RowLayout {
        id: content
        // anchors.centerIn: parent
        spacing: Config.spacing.small

        // Previous button
        MaterialText {
            text: "⏮"
            font.pixelSize: 16
            color: (typeof MprisController !== 'undefined' && MprisController.canGoPrevious) ? Config.colors.primary : Config.colors.onSurfaceDisabled
            opacity: (typeof MprisController !== 'undefined' && MprisController.canGoPrevious) ? 1.0 : 0.5
            MouseArea {
                anchors.fill: parent
                enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
                hoverEnabled: true
                acceptedButtons: Qt.RightButton | Qt.LeftButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (typeof MprisController !== 'undefined')
                            MprisController.previous();
                    }
                }
            }
        }

        // Play/pause button
        MaterialText {
            text: (typeof MprisController !== 'undefined' && MprisController.isPlaying) ? "⏸" : "▶"
            font.pixelSize: 16
            color: (typeof MprisController !== 'undefined' && MprisController.canTogglePlaying) ? Config.colors.primary : Config.colors.onSurfaceDisabled
            opacity: (typeof MprisController !== 'undefined' && MprisController.canTogglePlaying) ? 1.0 : 0.5
            MouseArea {
                anchors.fill: parent
                enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
                hoverEnabled: true
                acceptedButtons: Qt.RightButton | Qt.LeftButton
                onClicked: function(mouse){
                    if (mouse.button === Qt.LeftButton) {
                        if (typeof MprisController !== 'undefined')
                            MprisController.togglePlaying();
                    }
                }
            }
        }
        // Next button
        MaterialText {
            text: "⏭"
            font.pixelSize: 16
            color: (typeof MprisController !== 'undefined' && MprisController.canGoNext) ? Config.colors.primary : Config.colors.onSurfaceDisabled
            opacity: (typeof MprisController !== 'undefined' && MprisController.canGoNext) ? 1.0 : 0.5
            MouseArea {
                anchors.fill: parent
                enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
                hoverEnabled: true
                acceptedButtons: Qt.RightButton | Qt.LeftButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (typeof MprisController !== 'undefined')
                            MprisController.next();
                    }
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
                running: MprisController.isPlaying && (hoverTooltip.visible || GlobalStates.mediaControlsOpen)
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
