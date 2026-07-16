import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    id: root
    color: Theme.surfaceContainerHigh
    radius: 0  // no rounding
    // Layout.preferredHeight: 350

    // Clip content
    clip: true

    // Empty state when no player is active
    EmptyState {
        visible: !MprisController.activePlayer
        anchors.fill: parent
        anchors.margins: Tokens.spacing.medium

        iconName: "music_note"
        title: "No media playing"
        subtitle: "Start playing music to see controls"
        iconContainerSize: 64
        iconSize: 40
    }

    // Media player content (visible when player is active)
    Item {
        id: playerContent
        visible: MprisController.activePlayer
        anchors.fill: parent

        // ===== BACKGROUND: ALBUM ART WITH BLUR =====
        Item {
            id: backgroundLayer
            anchors.fill: parent
            visible: MprisController.activeTrack?.artUrl !== ""

            // Album art image (hidden)
            Image {
                id: albumArtBackground
                anchors.fill: parent
                source: MprisController.activeTrack?.artUrl ?? ""
                sourceSize.width: 400
                sourceSize.height: 400
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            // MultiEffect applies the blur
            MultiEffect {
                anchors.fill: parent
                source: albumArtBackground
                blurEnabled: true
                blur: 1.0  // maximum blur (was radius: 40)
                blurMax: 32
            }

            // Overlay to dim background
            Rectangle {
                anchors.fill: parent
                color: Theme.surfaceContainerHigh
                opacity: 0.85
            }
        }

        // ===== MAIN CONTENT =====
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            // ===== ALBUM ART (optional, smaller) =====
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 200
                    visible: MprisController.activeTrack?.artUrl !== ""

                    // Source image (hidden)
                    Image {
                        id: albumArtThumb
                        anchors.fill: parent
                        source: MprisController.activeTrack?.artUrl ?? ""
                        sourceSize.width: 200
                        sourceSize.height: 200
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    // MultiEffect applies the rounding mask
                    MultiEffect {
                        anchors.fill: parent
                        source: albumArtThumb
                        maskEnabled: true
                        maskSource: maskItem
                    }

                    // Rounding mask
                    Item {
                        id: maskItem
                        width: 200
                        height: 200
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            width: 200
                            height: 200
                            radius: Tokens.shape.medium
                            color: "white"
                        }
                    }

                    // Border on top
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.shape.medium
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.outlineVariant
                    }
                    MouseArea {
                        id: sourceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: MprisController.availablePlayers.length > 1
                        onClicked: sourceMenu.visible = !sourceMenu.visible
                    }
                }

                // ===== TRACK INFO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    MaterialMarqueeText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: MprisController.activeTrack?.title ?? "Unknown Title"
                        textStyle: "titleLarge"
                        colorRole: "onSurface"
                        weight: Font.Bold
                        align: Text.AlignHCenter
                    }
                    MaterialMarqueeText {
                        Layout.alignment: Qt.AlignHCenter
                        // Layout.maximumWidth: parent.width
                        Layout.fillWidth: true
                        text: {
                            let artist = MprisController.activeTrack?.artist ?? "Unknown Artist"
                            let album = MprisController.activeTrack?.album ?? "Unknown Album"
                            return artist + (album !== "" && album !== "Unknown Album" ? " - " + album : "");
                        }
                        textStyle: "bodyMedium"
                        colorRole: "onSurfaceVariant"
                        // elide: Text.ElideRight
                        align: Text.AlignHCenter
                    }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                // Interactive slider
                MaterialSlider {
                    id: positionSlider
                    Layout.fillWidth: true
                    from: 0
                    to: MprisController.length > 0 ? MprisController.length : 1
                    value: MprisController.position
                    enabled: MprisController.canSeek && MprisController.positionSupported

                    onMoved: {
                        MprisController.setPosition(value);
                    }
                }

                // Time labels
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        text: formatTime(MprisController.position)
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    MaterialText {
                        text: formatTime(MprisController.length)
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                // Shuffle
                IconButton {
                    iconName: "shuffle"
                    iconSize: Tokens.iconSize.medium
                    variant: MprisController.shuffle ? "tonal" : "standard"
                    enabled: MprisController.shuffleSupported && MprisController.canControl
                    onClicked: MprisController.toggleShuffle()
                }

                // Previous
                IconButton {
                    iconName: "skip_previous"
                    iconSize: 28
                    containerSize: 48
                    variant: "standard"
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }

                // Play/Pause (FAB style)
                IconButton {
                    iconName: MprisController.isPlaying ? "pause" : "play_arrow"
                    iconSize: Tokens.iconSize.extraLarge
                    containerSize: 56
                    touchTargetSize: 56
                    variant: "tonal"
                    enabled: MprisController.canTogglePlaying
                    onClicked: MprisController.togglePlaying()
                }

                // Next
                IconButton {
                    iconName: "skip_next"
                    iconSize: 28
                    containerSize: 48
                    variant: "standard"
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }

                // Loop
                IconButton {
                    iconName: {
                        if (MprisController.loopState === MprisLoopState.Track)
                            return "repeat_one"
                        return "repeat"
                    }
                    iconSize: Tokens.iconSize.medium
                    variant: MprisController.loopState !== MprisLoopState.None ? "tonal" : "standard"
                    enabled: MprisController.loopSupported && MprisController.canControl
                    onClicked: MprisController.toggleLoop()
                }
            }
                }

            }

            Item {
                Layout.fillHeight: true
            }
        }

        // ===== SOURCE SELECTOR MENU =====
        Rectangle {
            id: sourceMenu
            visible: false
            anchors.top: parent.top
            // anchors.right: parent.right
            anchors.left: parent.left
            anchors.margins: Tokens.spacing.large
            anchors.topMargin: Tokens.spacing.large + 40
            width: 200
            height: Math.min(sourceMenuContent.implicitHeight + Tokens.spacing.extraSmall * 2, 300)
            radius: Tokens.shape.medium
            color: Theme.surfaceContainerHigh

            // M3 elevation via border + surface tint (instead of DropShadow)
            border.width: 1
            border.color: Theme.outlineVariant

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                color: Theme.primary
                opacity: 0.05
            }

            ColumnLayout {
                id: sourceMenuContent
                anchors.fill: parent
                anchors.margins: Tokens.spacing.extraSmall
                spacing: 0

                Repeater {
                    model: MprisController.availablePlayers

                    delegate: ListItem {
                        required property var modelData
                        required property int index
                        property var player: modelData
                        property bool isActive: player === MprisController.activePlayer

                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Tokens.shape.extraSmall
                        color: isActive ? Theme.secondaryContainer : "transparent"
                        headline: player.identity || "Unknown Player"
                        leadingIcon: player.isPlaying ? "play_circle" : "music_note"
                        leadingIconColor: isActive ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
                        trailingIcon: isActive ? "check" : ""
                        trailingIconColor: Theme.primary
                        margin: Tokens.spacing.small

                        onClicked: {
                            MprisController.switchToPlayer(index)
                            sourceMenu.visible = false
                        }
                    }
                }
            }
        }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";

        const hours = Math.floor(seconds / 3600);
        const mins = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        if (hours > 0)
        return hours + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // Click outside to close menu
    MouseArea {
        anchors.fill: parent
        enabled: sourceMenu.visible
        onClicked: sourceMenu.visible = false
        z: -1
    }
}
