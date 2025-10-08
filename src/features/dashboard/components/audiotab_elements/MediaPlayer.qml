import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large
    // Layout.preferredHeight: 350

    // Clip content for rounded corners
    clip: true

    // Empty state when no player is active
    EmptyState {
        visible: !MprisController.activePlayer
        anchors.fill: parent
        anchors.margins: Config.spacing.medium

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

            // Album art image
            Image {
                id: albumArtBackground
                anchors.fill: parent
                source: MprisController.activeTrack?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true

                layer.enabled: true
                layer.effect: FastBlur {
                    radius: 64
                }

                // Overlay to dim background
                Rectangle {
                    anchors.fill: parent
                    color: Config.colors.surfaceContainerHigh
                    opacity: 0.85
                }
            }
        }

        // ===== MAIN CONTENT =====
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.large
            spacing: Config.spacing.medium

            // ===== HEADER: SOURCE SELECTOR =====
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.small

                MaterialText {
                    text: "Playing from"
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                }

                Item { Layout.fillWidth: true }

                // Source selector dropdown
                MaterialCard {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: sourceRow.implicitWidth + Config.spacing.medium * 2
                    color: sourceMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : Config.colors.surfaceContainer
                    radius: Config.shape.full

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    RowLayout {
                        id: sourceRow
                        anchors.centerIn: parent
                        spacing: Config.spacing.extraSmall

                        // Player icon (from desktop entry or fallback)
                        MaterialIcon {
                            iconName: "music_note"
                            fontSize: 16
                            iconColor: Config.colors.onSurfaceVariant
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            text: MprisController.identity || "Unknown Player"
                            textStyle: "labelMedium"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                        }

                        MaterialIcon {
                            iconName: "arrow_drop_down"
                            fontSize: 16
                            iconColor: Config.colors.onSurfaceVariant
                            backgroundColor: "transparent"
                            visible: MprisController.availablePlayers.length > 1
                        }
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
            }

            Item { Layout.fillHeight: true }
            // ===== ALBUM ART (optional, smaller) =====
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200
                radius: Config.shape.medium
                color: Config.colors.surfaceContainerHighest
                visible: MprisController.activeTrack?.artUrl !== ""

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 8
                    samples: 17
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

                Image {
                    anchors.fill: parent
                    source: MprisController.activeTrack?.artUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 80
                            height: 80
                            radius: Config.shape.medium
                        }
                    }
                }
            }


            // ===== TRACK INFO =====
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                MaterialText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    // Layout.maximumWidth: parent.width
                    text: MprisController.activeTrack?.title ?? "Unknown Title"
                    textStyle: "titleLarge"
                    colorRole: "onSurface"
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                MaterialText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    text: MprisController.activeTrack?.artist ?? "Unknown Artist"
                    textStyle: "bodyMedium"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                MaterialText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    text: MprisController.activeTrack?.album ?? ""
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== "" && text !== "Unknown Album"
                }
            }
        }

            // ===== POSITION SLIDER =====
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.extraSmall

                // Interactive slider
                MaterialSlider {
                    id: positionSlider
                    Layout.fillWidth: true
                    from: 0
                    to: MprisController.length > 0 ? MprisController.length : 1
                    value: MprisController.position
                    enabled: MprisController.canSeek && MprisController.positionSupported

                    onMoved: {
                        MprisController.setPosition(value)
                    }
                }

                // Time labels
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.extraSmall

                    MaterialText {
                        text: formatTime(MprisController.position)
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                    }

                    Item { Layout.fillWidth: true }

                    MaterialText {
                        text: formatTime(MprisController.length)
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                    }
                }
            }

            // ===== PLAYBACK CONTROLS =====
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                // Shuffle
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: MprisController.shuffle ? Config.colors.primaryContainer : "transparent"
                    opacity: MprisController.shuffleSupported ? 1.0 : 0.38

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "shuffle"
                        fontSize: 20
                        iconColor: MprisController.shuffle ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        backgroundColor: "transparent"

                        Behavior on iconColor {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }
                    }

                    StateLayer {
                        layerColor: MprisController.shuffle ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        hovered: shuffleMouseArea.containsMouse
                        pressed: shuffleMouseArea.pressed
                    }

                    MouseArea {
                        id: shuffleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: MprisController.shuffleSupported ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.shuffleSupported && MprisController.canControl
                        onClicked: MprisController.toggleShuffle()
                    }
                }

                // Previous
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: "transparent"
                    opacity: MprisController.canGoPrevious ? 1.0 : 0.38

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "skip_previous"
                        fontSize: 28
                        iconColor: Config.colors.onSurface
                        backgroundColor: "transparent"
                    }

                    StateLayer {
                        layerColor: Config.colors.onSurface
                        hovered: prevMouseArea.containsMouse
                        pressed: prevMouseArea.pressed
                    }

                    MouseArea {
                        id: prevMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: MprisController.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.canGoPrevious
                        onClicked: MprisController.previous()
                    }
                }

                // Play/Pause (FAB style)
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: Config.colors.primaryContainer

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 2
                        radius: 6
                        samples: 13
                        color: Qt.rgba(0, 0, 0, 0.25)
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: MprisController.isPlaying ? "pause" : "play_arrow"
                        fontSize: 32
                        iconColor: Config.colors.onPrimaryContainer
                        backgroundColor: "transparent"
                    }

                    StateLayer {
                        layerColor: Config.colors.onPrimaryContainer
                        hovered: playMouseArea.containsMouse
                        pressed: playMouseArea.pressed
                    }

                    MouseArea {
                        id: playMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: MprisController.canTogglePlaying ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.canTogglePlaying
                        onClicked: MprisController.togglePlaying()
                    }
                }

                // Next
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    color: "transparent"
                    opacity: MprisController.canGoNext ? 1.0 : 0.38

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "skip_next"
                        fontSize: 28
                        iconColor: Config.colors.onSurface
                        backgroundColor: "transparent"
                    }

                    StateLayer {
                        layerColor: Config.colors.onSurface
                        hovered: nextMouseArea.containsMouse
                        pressed: nextMouseArea.pressed
                    }

                    MouseArea {
                        id: nextMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: MprisController.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.canGoNext
                        onClicked: MprisController.next()
                    }
                }

                // Loop
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: MprisController.loopState !== MprisLoopState.None ? Config.colors.primaryContainer : "transparent"
                    opacity: MprisController.loopSupported ? 1.0 : 0.38

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: {
                            if (MprisController.loopState === MprisLoopState.Track) return "repeat_one"
                            if (MprisController.loopState === MprisLoopState.Playlist) return "repeat"
                            return "repeat"
                        }
                        fontSize: 20
                        iconColor: MprisController.loopState !== MprisLoopState.None ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        backgroundColor: "transparent"

                        Behavior on iconColor {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }
                    }

                    StateLayer {
                        layerColor: MprisController.loopState !== MprisLoopState.None ? Config.colors.onPrimaryContainer : Config.colors.onSurface
                        hovered: loopMouseArea.containsMouse
                        pressed: loopMouseArea.pressed
                    }

                    MouseArea {
                        id: loopMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: MprisController.loopSupported ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: MprisController.loopSupported && MprisController.canControl
                        onClicked: MprisController.toggleLoop()
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ===== SOURCE SELECTOR MENU =====
        Rectangle {
            id: sourceMenu
            visible: false
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Config.spacing.large
            anchors.topMargin: Config.spacing.large + 40
            width: 200
            height: Math.min(sourceMenuContent.implicitHeight, 300)
            radius: Config.shape.medium
            color: Config.colors.surfaceContainerHigh

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 4
                radius: 8
                samples: 17
                color: Qt.rgba(0, 0, 0, 0.25)
            }

            ColumnLayout {
                id: sourceMenuContent
                anchors.fill: parent
                anchors.margins: Config.spacing.extraSmall
                spacing: 0

                Repeater {
                    model: MprisController.availablePlayers

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property var player: modelData
                        property bool isActive: player === MprisController.activePlayer

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Config.shape.extraSmall
                        color: isActive ? Config.colors.secondaryContainer :
                               (playerMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Config.spacing.small
                            spacing: Config.spacing.small

                            MaterialIcon {
                                iconName: player.isPlaying ? "play_circle" : "music_note"
                                fontSize: 24
                                iconColor: isActive ? Config.colors.onSecondaryContainer : Config.colors.onSurfaceVariant
                                backgroundColor: "transparent"
                            }

                            MaterialText {
                                Layout.fillWidth: true
                                text: player.identity || "Unknown Player"
                                textStyle: "bodyMedium"
                                colorRole: isActive ? "onSecondaryContainer" : "onSurface"
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                iconName: "check"
                                fontSize: 20
                                iconColor: Config.colors.primary
                                backgroundColor: "transparent"
                                visible: isActive
                            }
                        }

                        MouseArea {
                            id: playerMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MprisController.switchToPlayer(index)
                                sourceMenu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"

        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // Click outside to close menu
    MouseArea {
        anchors.fill: parent
        enabled: sourceMenu.visible
        onClicked: sourceMenu.visible = false
        z: -1
    }
}
