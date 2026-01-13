import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
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
    // expandOnHover: true
    // expandedWidth: 300
    hoverable: true
    // hoverable: false

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool compact: widgetSettings.compact ?? false
    property bool showIcon: widgetSettings.showIcon ?? true
    property int maxWidth: widgetSettings.maxWidth ?? 0

    property var tooltipManager: null

    // Show when there's an active player
    visible: (typeof MprisController !== 'undefined') && MprisController.activePlayer !== null

    implicitWidth: content.implicitWidth + Config.spacing.small * 2

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
        spacing: Config.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: "music_note"
            fontSize: Config.typography.titleLarge.size
            // iconColor: Config.colors.onSurface
            iconColor: (root.hovered ? Config.colors.primary : Config.colors.onSurface)
            color: "transparent"
        }

        // Track info - visible only on hover
        // Item {
        //     width: 300
        //     // height: 40
        //     clip: true
        //
        //     Row {
        //         id: row
        //         spacing: 40
        //         x: 0
        //
        //         Repeater {
        //             model: 2
        //             MaterialText {
        //                 // visible: root.hovered && !root.compact
        //                 text: {
        //                     if (typeof MprisController === "undefined" || !MprisController.activeTrack)
        //                     return "Нет воспроизведения";
        //                     const title = MprisController.activeTrack.title || "Unknown Title";
        //                     const artist = MprisController.activeTrack.artist || "Unknown Artist";
        //                     return `${title} — ${artist}`;
        //                 }
        //                 textStyle: "bodyMedium"
        //                 colorRole: "onSurface"
        //                 elide: Text.ElideRight
        //                 maximumLineCount: 1
        //                 // Layout.maximumWidth: root.maxWidth > 0 ? root.maxWidth : 200
        //                 Layout.preferredWidth: 260
        //                 Layout.alignment: Qt.AlignVCenter
        //
        //                 Behavior on Layout.maximumWidth {
        //                     NumberAnimation {
        //                         duration: Config.motion.duration.short4
        //                         easing.type: Config.motion.easing.standard
        //                     }
        //                 }
        //             }
        //
        //         }
        //
        //         NumberAnimation on x {
        //             from: 0
        //             to: -(row.width / 2)
        //             duration: 6000
        //             loops: Animation.Infinite
        //         }
        //     }
        // }
        MaterialText {
            // visible: root.hovered && !root.compact
            id: trackInfoText
            text: {
                if (typeof MprisController === "undefined" || !MprisController.activeTrack)
                    return "Нет воспроизведения";
                const title = MprisController.activeTrack.title || "Unknown Title";
                const artist = MprisController.activeTrack.artist || "Unknown Artist";
                return `${title} — ${artist}`;
            }
            textStyle: "bodyMedium"
            colorRole: root.hovered ? "primary" : "onSurface"
            elide: Text.ElideRight
            maximumLineCount: 1
            // visible: root.hovered || !root.compact
            visible: Layout.preferredWidth > 0
            // Layout.maximumWidth: root.maxWidth > 0 ? root.maxWidth : 200
            Layout.preferredWidth: root.hovered ? 260 : 0
            Layout.alignment: Qt.AlignVCenter

            // Behavior on Layout.maximumWidth {
            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                    easing.type: Config.motion.easing.standard
                }
            }
        }

        // Previous button - visible on hover, enabled if action available
        IconButton {
            variant: "standard"
            iconName: "skip_previous"
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
            iconColor: enabled ? (root.hovered ? Config.colors.primary : Config.colors.onSurface) : Config.colors.onSurfaceVariant
            opacity: enabled ? 1.0 : 0.38
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.previous();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.motion.duration.short4
                }
            }
        }

        // Play/Pause button - always visible
        IconButton {
            variant: "standard"
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
            // iconColor: Config.colors.onSurface
            iconColor: enabled ? (root.hovered ? Config.colors.primary : Config.colors.onSurface) : Config.colors.onSurfaceVariant
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
            iconSize: Config.iconSize.large
            containerSize: 32
            touchTargetSize: 40
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
            // iconColor: enabled ? Config.colors.onSurface : Config.colors.onSurfaceVariant
            iconColor: enabled ? (root.hovered ? Config.colors.primary : Config.colors.onSurface) : Config.colors.onSurfaceVariant
            opacity: enabled ? 1.0 : 0.38
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (typeof MprisController !== 'undefined')
                        MprisController.next();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.motion.duration.short4
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
