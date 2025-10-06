import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import qs.src.core.config
import qs.src.features.mediaControls.components
import qs.src.ui.base
import qs.src.core.services

Rectangle {
    id: root

    // Свойства плеера по методу end_4
    property var player: (typeof MprisController !== 'undefined') ? MprisController.activePlayer : null
    property var track: player ? player.trackData : null
    property bool isPlaying: player?.playbackState == MprisPlaybackState.Playing || false

    // Position tracking timer (как в end_4)
    // Timer {
    //     running: root.isPlaying
    //     interval: 1000 // Обновляем каждую секунду
    //     repeat: true
    //     onTriggered: {
    //         if (root.player) {
    //             root.player.positionChanged();
    //         }
    //     }
    // }

    // Прямые алиасы для position и length
    property real position: player?.position || 0
    property real length: player?.length || 0

    width: 600
    height: 220
    radius: Config.shape.extraLarge
    color: Config.colors.surfaceContainerHigh
    border.width: 1
    border.color: Config.colors.outlineVariant

    // Component.onCompleted: {
    //     console.log("PlayerCard initialized with player:", player ? player.identity : "none");
    //     bkg.updateArt(false);
    // }

    BackgroundArt {
        id: bkg
        anchors.fill: parent
        overlay.color: "#80000000"
        blurRadius: 100
        blurSamples: 201

        // function updateArt(reverse: bool) {
        //     console.log("update art", MprisController.activePlayer.trackArtUrl);
        //     // console.log("update art", MprisController.activePlayer.artUrl);
        //     this.setArt(MprisController.activePlayer.trackArtUrl, reverse, false);
        //     // this.setArt(MprisController.activePlayer.artUrl, reverse, false);
        // }

        Component.onCompleted: {
            setArt(MprisController.activeTrack.artUrl, false, true);
            // setArt(MprisController.activeTrack.trackArtUrl, false, true);
        }

        Connections {
            target: MprisController

            function onTrackChanged(reverse: bool) {
                // bkg.updateArt(reverse);
                bkg.setArt(MprisController.activeTrack.artUrl, reverse, false);
            }
        }

    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.large
        spacing: Config.spacing.large

        // Album artwork
        Item {
            Layout.preferredWidth: 180
            Layout.preferredHeight: 180
            Layout.alignment: Qt.AlignVertically | Qt.AlignLeft

            Image {
                id: img
                anchors.fill: parent
                anchors.margins: 1
                // radius: parent.radius - 1
                source: (typeof MprisController !== 'undefined' && root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                property bool rounded: true
                property bool adapt: true
                fillMode: Image.PreserveAspectCrop
                visible: source !== ""
                smooth: true
                layer.enabled: rounded
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: img.width
                        height: img.height
                        Rectangle {
                            anchors.centerIn: parent
                            width: img.adapt ? img.width : Math.min(img.width, img.height)
                            height: img.adapt ? img.height : width
                            radius: Config.shape.large
                        }
                    }
                }

                // Hover effect
                Rectangle {
                    anchors.fill: parent
                    // radius: parent.radius
                    radius: Config.shape.large
                    color: Qt.alpha(Config.colors.primary, artworkMouse.containsMouse ? 0.08 : 0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    id: artworkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (typeof MprisController !== 'undefined') {
                            MprisController.togglePlaying();
                        }
                    }
                }
            }
        }

        // Track info and controls
        ColumnLayout {
            // Layout.fillWidth: true
            // Layout.fillHeight: true
            spacing: Config.spacing.small

            // Track information
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.extraSmall

                // Title
                MaterialText {
                    id: titleText
                    Layout.fillWidth: true
                    text: (typeof MprisController !== 'undefined' && MprisController.activeTrack) ? MprisController.activeTrack.title || "Unknown Title" : "No track"
                    textStyle: "titleLarge"
                    colorRole: "onSurface"
                    elide: Text.ElideRight
                    maximumLineCount: 2

                    // Text change animation
                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation {
                                target: titleText
                                property: "opacity"
                                to: 0
                                duration: 100
                            }
                            PropertyAction {
                                target: titleText
                                property: "text"
                            }
                            NumberAnimation {
                                target: titleText
                                property: "opacity"
                                to: 1
                                duration: 200
                            }
                        }
                    }
                }

                // Artist
                MaterialText {
                    id: artistText
                    Layout.fillWidth: true
                    text: (typeof MprisController !== 'undefined' && MprisController.activeTrack) ? MprisController.activeTrack.artist || "Unknown Artist" : "No artist"
                    textStyle: "bodyMedium"
                    colorRole: "onSurface"
                    elide: Text.ElideRight

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation {
                                target: artistText
                                property: "opacity"
                                to: 0
                                duration: 100
                            }
                            PropertyAction {
                                target: artistText
                                property: "text"
                            }
                            NumberAnimation {
                                target: artistText
                                property: "opacity"
                                to: 1
                                duration: 200
                            }
                        }
                    }
                }
            }

            // Time display
            RowLayout {
                // Layout.fillWidth: true

                MaterialText {
                    text: formatTime(root.position) + " / " + formatTime(root.length)
                    textStyle: "labelMedium"
                    colorRole: "onSurface"
                }

                Item {
                    Layout.fillWidth: true
                }

                // Play/Pause button (сверху справа, как в end_4)
                RippleButton {
                    id: playPauseButton
                    iconName: root.isPlaying ? "pause" : "play_arrow"
                    fontSize: Config.typography.headlineLarge.size
                    buttonType: "filled"
                    playing: root.isPlaying
                    enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
                    onClicked: {
                        if (typeof MprisController !== 'undefined') {
                            MprisController.togglePlaying();
                        }
                    }

                    width: 48
                    height: 48
                }
            }

            // Нижний ряд с кнопками Previous/Next и слайдером между ними
            RowLayout {
                id: controlsRow
                // anchors.bottom: parent.bottom
                // anchors.left: parent.left
                // anchors.right: parent.right
                spacing: Config.spacing.small

                // Previous
                RippleButton {
                    iconName: "skip_previous"
                    fontSize: Config.typography.headlineLarge.size
                    color: "transparent"
                    // color: "red"
                    width: 40
                    height: 40
                    enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
                    onClicked: {
                        if (typeof MprisController !== 'undefined') {
                            MprisController.previous();
                        }
                    }
                }

                // Слайдер в центре
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    AnimatedProgressBar {
                        id: compactSlider
                        anchors.centerIn: parent
                        width: parent.width
                        height: 8

                        // Продвинутая логика слайдера
                        property bool bindSlider: true
                        property real boundAnimStart: 0
                        property real boundAnimFactor: 1
                        property real lastPosition: 0
                        property real lastLength: 0
                        property real boundPosition: {
                            const ppos = player.position / player.length;
                            const bpos = boundAnimStart;
                            return (ppos * boundAnimFactor) + (bpos * (1.0 - boundAnimFactor));
                        }

                        NumberAnimation {
                            id: boundAnim
                            target: compactSlider
                            property: "boundAnimFactor"
                            from: 0
                            to: 1
                            duration: 600
                            easing.type: Easing.OutExpo
                        }

                        Connections {
                            target: player
                            function onPositionChanged() {
                                if (false && player.position == 0 && compactSlider.lastPosition != 0 && !boundAnim.running) {
                                    compactSlider.boundAnimStart = compactSlider.lastPosition / compactSlider.lastLength;
                                    boundAnim.start();
                                }
                                compactSlider.lastPosition = player.position;
                                compactSlider.lastLength = player.length;
                            }
                        }

                        ColorQuantizer {
                            id: quant
                            rescaleSize: 200
                            depth: 0
                            source: MprisController.activePlayer.trackArtUrl
                            onColorsChanged: console.log(colors)
                        }

                        grooveColor: quant.colors.length === 0 ? "#30ceffff" : Qt.alpha(quant.colors[0], 0.5)
                        barColor: quant.colors.length === 0 ? "#80ceffff" : Qt.alpha(Qt.lighter(quant.colors[0]), 0.9)

                        Behavior on grooveColor {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        Behavior on barColor {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        enabled: player.canSeek
                        from: 0
                        to: 1

                        onPressedChanged: {
                            if (!pressed && player && player.canSeek) {
                                player.position = value * player.length;
                            }
                            bindSlider = !pressed;
                        }

                        Binding {
                            when: compactSlider.bindSlider
                            compactSlider.value: compactSlider.boundPosition
                        }
                    }
                }

                // Next
                RippleButton {
                    iconName: "skip_next"
                    fontSize: Config.typography.headlineLarge.size
                    color: "transparent"
                    // iconStyle: "bold"
                    // fallbackText: "⏭"
                    width: 40
                    height: 40
                    enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
                    onClicked: {
                        if (typeof MprisController !== 'undefined') {
                            MprisController.next();
                        }
                    }
                }
            }
            RowLayout {
                id: playerSelector
                property Item selectedPlayerDisplay: null
                onSelectedPlayerDisplayChanged: console.log(selectedPlayerDisplay)
                Layout.alignment: Qt.AlignRight
                MaterialText {
                    text: MprisController.activePlayer ? MprisController.activePlayer.identity : "No player"
                    textStyle: "bodyMedium"
                    colorRole: "onSurface"
                    Layout.alignment: Qt.AlignLeft
                    Layout.margins: 5

                }

                Item {
                    implicitWidth: 28
                    implicitHeight: 28

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: {
                            return "root:icons/SVGs/bold/play-bold"
                        }

                        sourceSize.width: 50
                        sourceSize.height: 50
                        cache: false

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                console.log("Quit clicked");
                                MprisController.quit();
                            }
                        }
                    }
                }

                Item {
                    implicitWidth: 28
                    implicitHeight: 28

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: {
                            return "root:icons/SVGs/bold/play-bold"
                        }

                        sourceSize.width: 50
                        sourceSize.height: 50
                        cache: false

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                console.log("Raise clicked");
                                MprisController.raise();
                            }
                        }
                    }
                }


                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: Mpris.players

                    MouseArea {
                        required property MprisPlayer modelData
                        readonly property bool selected: modelData == player
                        onSelectedChanged: if (selected)
                            playerSelector.selectedPlayerDisplay = this

                        implicitWidth: childrenRect.width
                        implicitHeight: childrenRect.height

                        onClicked: MprisController.setActivePlayer(modelData)

                        Item {
                            implicitWidth: 28
                            implicitHeight: 28

                            Image {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: {
                                    const entry = DesktopEntries.heuristicLookup(modelData.identity) ??
                                                  DesktopEntries.heuristicLookup(modelData.desktopEntry);
                                    console.log(`ent ${entry} id ${modelData.desktopEntry}`);
                                    if (entry?.icon)
                                        return Quickshell.iconPath(entry?.icon);
                                    else
                                        return "root:icons/SVGs/bold/play-bold"
                                }

                                sourceSize.width: 50
                                sourceSize.height: 50
                                cache: false
                            }
                        }
                    }
                    //}
                }
                // }
            }
        }
    }

    // Helper functions
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";

        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
}
