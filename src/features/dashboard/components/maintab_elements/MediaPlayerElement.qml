import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    id: root
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    property var player: (typeof MprisController !== 'undefined') ? MprisController.activePlayer : null
    property real position: player?.position || 0
    property real length: player?.length || 0
    property bool isPlaying: player?.playbackState == MprisPlaybackState.Playing || false

    // Timer for updating position during playback
    Timer {
        running: root.isPlaying && root.length > 0
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.player && root.player.position < root.length) {
                root.position = root.player.position
            }
        }
    }

    // Empty state when no player is active
    EmptyState {
        visible: !root.player
        anchors.fill: parent
        anchors.margins: Config.spacing.medium

        iconName: "music_note"
        title: "No media playing"
        subtitle: "Start playing music to see controls"
        iconContainerSize: 64
        iconSize: 40
    }

    // Media player content (visible when player is active)
    RowLayout {
        id: mediaPlayerLayout
        visible: root.player
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        // Album Art be on background

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialText {
                text: MprisController.activeTrack.title?? ""
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.preferredWidth: 360
            }

            MaterialText {
                text: ( MprisController.activeTrack.artist?? "" ) + (MprisController.activeTrack.album !== "Unknown Album" ? " — " + MprisController.activeTrack.album : "")
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                Layout.preferredWidth: 360
                elide: Text.ElideRight
            }

            // Progress bar
            RowLayout {
                spacing: Config.spacing.extraSmall

                MaterialText {
                    text: root.formatTime(root.position)
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Config.colors.surfaceContainerHighest

                    Rectangle {
                        width: parent.width * (root.length > 0 ? (root.position / root.length) : 0)
                        height: parent.height
                        radius: parent.radius
                        color: Config.colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.motion.duration.short4
                                easing.type: Config.motion.easing.standard
                            }
                        }
                    }
                }

                MaterialText {
                    text: root.formatTime(root.length)
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                }
            }
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        {
                            icon: "shuffle",
                            action: "shuffle"
                        },
                        {
                            icon: "skip_previous",
                            action: "previous"
                        },
                        {
                            icon: root.isPlaying ? "pause" : "play_arrow",
                            primary: true,
                            action: "play"
                        },
                        {
                            icon: "skip_next",
                            action: "next"
                        },
                        {
                            icon: "repeat",
                            action: "repeat"
                        },
                        {
                            icon: "favorite_border",
                            action: "favorite"
                        }
                    ]

                    delegate: Rectangle {
                        width: modelData.primary ? 40 : 32
                        height: modelData.primary ? 40 : 32
                        radius: (modelData.primary ? 40 : 32) / 2
                        color: modelData.primary ? Config.colors.primary : "transparent"

                        property bool isEnabled: {
                            if (modelData.action === "play") return MprisController.canTogglePlaying
                            if (modelData.action === "previous") return MprisController.canGoPrevious
                            if (modelData.action === "next") return MprisController.canGoNext
                            return false
                        }

                        opacity: isEnabled ? 1.0 : 0.38

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: modelData.icon
                            fontSize: modelData.primary ? Config.typography.titleLarge.size : Config.typography.titleMedium.size
                            iconColor: modelData.primary ? Config.colors.onPrimary : Config.colors.onSurface
                            backgroundColor: "transparent"
                        }

                        StateLayer {
                            layerColor: modelData.primary ? Config.colors.onPrimary : Config.colors.onSurface
                            hovered: mouseArea.containsMouse
                            pressed: mouseArea.pressed
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: parent.isEnabled

                            onClicked: {
                                if (modelData.action === "play") {
                                    MprisController.togglePlaying()
                                } else if (modelData.action === "previous") {
                                    MprisController.previous()
                                } else if (modelData.action === "next") {
                                    MprisController.next()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Connections {
        target: root.player

        function onPositionChanged() {
            if (root.player) {
                root.position = root.player.position
            }
        }

        function onLengthChanged() {
            if (root.player) {
                root.length = root.player.length
            }
        }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";

        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
}
