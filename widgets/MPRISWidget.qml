import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.components.base
import qs.components.tooltip
import qs.config
import qs.services

BarElement {
    id: root
    clickable: false
    hoverable: true

    property var tooltipManager: null
    property bool menuOpen: false

    // Hide widget when no player is active
    visible: (typeof MprisController !== 'undefined') && MprisController.activePlayer !== null

    implicitWidth: content.width + 12
    // minWidth: content.implicitWidth

    nonVisualChildren: [
        // Hover tooltip with media info (outfoxxed style)

        TooltipItem {
            id: hoverTooltip
            tooltip: root.tooltipManager
            owner: root
            isMenu: false
            hoverable: false
            show: root.hovered && (typeof MprisController !== 'undefined') && !!MprisController.activePlayer && !root.menuOpen

            backgroundComponent: Component {
                Rectangle {
                    radius: Config.shape.large
                    color: Config.colors.surfaceContainerHigh
                    border.color: Config.colors.outlineVariant
                }
            }

            RowLayout {
                spacing: Config.spacing.medium
                implicitWidth: 350

                // Small album art in tooltip
                Rectangle {
                    width: 64
                    height: 64
                    radius: Config.shape.medium
                    color: Config.colors.surfaceContainer
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (typeof MprisController !== 'undefined') ? (MprisController.activeTrack?.artUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready
                    }

                    MaterialText {
                        anchors.centerIn: parent
                        text: "♪"
                        font.pixelSize: 24
                        colorRole: "surfaceVariantText"
                        opacity: 0.6
                        visible: parent.children[0].status !== Image.Ready
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.small

                    MaterialText {
                        text: (typeof MprisController !== 'undefined') ? (MprisController.activeTrack?.title || "Unknown Title") : "Unknown Title"
                        textStyle: "titleMedium"
                        colorRole: "surfaceText"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    MaterialText {
                        text: (typeof MprisController !== 'undefined') ? (MprisController.activeTrack?.artist || "Unknown Artist") : "Unknown Artist"
                        textStyle: "bodyMedium"
                        colorRole: "surfaceVariantText"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    MaterialText {
                        text: (typeof MprisController !== 'undefined') ? ((MprisController.activePlayer?.identity || "Media Player") + " - " + hoverTooltip.formatTime(MprisController.activePlayer?.position || 0) + " / " + hoverTooltip.formatTime(MprisController.activePlayer?.length || 0)) : "Media Player - 0:00 / 0:00"
                        textStyle: "bodySmall"
                        colorRole: "surfaceVariantText"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        color: Config.colors.surfaceContainerHighest
                        radius: 4

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: (typeof MprisController !== 'undefined' && MprisController.activePlayer?.length > 0) ? parent.width * (MprisController.activePlayer.position / MprisController.activePlayer.length) : 0
                            color: Config.colors.primary
                            radius: parent.radius
                        }
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
        },

        // Player selection menu (right-click)
        TooltipItem {
            id: playerMenu
            tooltip: root.tooltipManager
            owner: root
            isMenu: true
            hoverable: true
            show: root.menuOpen
            animateSize: false

            backgroundComponent: Component {
                Rectangle {
                    radius: Config.shape.extraLarge
                    color: Config.colors.surfaceContainerHigh
                    border.color: Config.colors.outlineVariant
                }
            }

            onClose: root.menuOpen = false

            // Loader {
            //     id: menuLoader
            //     active: root.menuOpen || playerMenu.visible
            //
            //     sourceComponent: ColumnLayout {
            ColumnLayout {
                // anchors.fill: parent
                spacing: Config.spacing.large
                implicitWidth: 400
                // implicitHeight: 500

                // Player selector at top
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 80

                    MaterialText {
                        text: qsTr("Выбор источника")
                        textStyle: "titleSmall"
                        colorRole: "surfaceVariantText"
                        anchors.top: parent.top
                        Layout.alignment: Qt.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        anchors.topMargin: 20
                        spacing: Config.spacing.medium

                        Repeater {
                            model: Mpris.players

                            delegate: Rectangle {
                                width: 50
                                height: 50
                                radius: 25
                                color: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ? Config.colors.primaryContainer : Config.colors.surfaceContainer
                                border.width: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ? 2 : 0
                                border.color: Config.colors.primary

                                MaterialText {
                                    anchors.centerIn: parent
                                    text: (modelData.identity || "?").charAt(0).toUpperCase()
                                    textStyle: "titleMedium"
                                    colorRole: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ? "primaryText" : "surfaceText"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (typeof MprisController !== 'undefined') {
                                            MprisController.setActivePlayer(modelData);
                                            root.menuOpen = false;
                                        }
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                    }

                    MaterialText {
                        visible: Mpris.players.count === 0
                        text: "Нет доступных плееров"
                        textStyle: "bodyMedium"
                        colorRole: "surfaceVariantText"
                        anchors.centerIn: parent
                    }
                }

                // Album art in center
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        id: albumArt
                        anchors.centerIn: parent
                        width: 200
                        height: 200
                        radius: Config.shape.large
                        color: Config.colors.surfaceContainerHigh
                        border.width: 1
                        border.color: Config.colors.outlineVariant
                        clip: true

                        Image {
                            id: albumImage
                            anchors.fill: parent
                            source: (typeof MprisController !== 'undefined') ? (MprisController.activeTrack?.artUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            visible: status === Image.Ready
                            opacity: 1.0

                            // Smooth transition when art changes
                            Connections {
                                target: (typeof MprisController !== 'undefined') ? MprisController : null

                                function onTrackChanged() {
                                    if (typeof MprisController !== 'undefined') {
                                        // Fade out current image, then update source
                                        albumImage.opacity = 0;
                                        albumImage.source = MprisController.activeTrack?.artUrl || "";
                                    }
                                }
                            }

                            onStatusChanged: {
                                if (status === Image.Ready && opacity === 0) {
                                    // Fade in when new image is loaded
                                    opacity = 1.0;
                                }
                            }

                            Behavior on opacity {
                                OpacityAnimator {
                                    duration: 400
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        // Placeholder when no art or loading
                        MaterialText {
                            anchors.centerIn: parent
                            text: albumImage.status === Image.Loading ? "⏳" : "♪"
                            font.pixelSize: 64
                            colorRole: "surfaceVariantText"
                            opacity: albumImage.visible ? 0 : 0.6
                            visible: !albumImage.visible

                            Behavior on opacity {
                                OpacityAnimator {
                                    duration: 300
                                }
                            }
                        }
                    }
                }

                // Track info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Config.spacing.small

                    MaterialText {
                        text: (typeof MprisController !== 'undefined') ? (MprisController.activeTrack?.title || "Нет названия") : "Нет названия"
                        textStyle: "headlineSmall"
                        colorRole: "surfaceText"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 350
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                    }

                    MaterialText {
                        visible: (typeof MprisController !== 'undefined') && !!(MprisController.activeTrack?.artist)
                        text: {
                            if (typeof MprisController === 'undefined')
                                return "";
                            const artist = MprisController.activeTrack?.artist || "";
                            const album = MprisController.activeTrack?.album || "";
                            return album && album !== "Unknown Album" ? `${artist} — ${album}` : artist;
                        }
                        textStyle: "bodyLarge"
                        colorRole: "surfaceVariantText"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 350
                        elide: Text.ElideRight
                    }

                    MaterialText {
                        text: (typeof MprisController !== 'undefined') ? (MprisController.activePlayer?.identity || "Media Player") : "Media Player"
                        textStyle: "bodyMedium"
                        colorRole: "surfaceVariantText"
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.7
                    }
                }

                // Controls at bottom
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Config.spacing.large

                    MaterialButton {
                        text: "⏮"
                        variant: "filledTonal"
                        enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
                        onClicked: {
                            if (typeof MprisController !== 'undefined')
                                MprisController.previous();
                        }
                    }

                    MaterialButton {
                        text: (typeof MprisController !== 'undefined' && MprisController.isPlaying) ? "⏸" : "▶"
                        variant: "filled"
                        enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
                        onClicked: {
                            if (typeof MprisController !== 'undefined')
                                MprisController.togglePlaying();
                        }
                    }

                    MaterialButton {
                        text: "⏭"
                        variant: "filledTonal"
                        enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
                        onClicked: {
                            if (typeof MprisController !== 'undefined')
                                MprisController.next();
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
                // }
            }
        }
    ]

    // Main content - compact display on bar
    RowLayout {
        id: content
        // anchors.centerIn: parent
        spacing: Config.spacing.small
        // width: childrenRect.width

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
                onClicked: {
                    if (mouse.button === Qt.RightButton) {
                        root.menuOpen = !root.menuOpen;
                        return;
                    }
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
                onClicked: {
                    if (mouse.button === Qt.RightButton) {
                        root.menuOpen = !root.menuOpen;
                        return;
                    }
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
                onClicked: {
                    if (mouse.button === Qt.RightButton) {
                        root.menuOpen = !root.menuOpen;
                        return;
                    }
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
                running: MprisController.isPlaying && (hoverTooltip.visible || playerMenu.visible)
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
