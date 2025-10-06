import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import Quickshell.Services.Mpris
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import "."

LazyPopup {
    id: root

    ColumnLayout {
        spacing: Config.spacing.large
        implicitWidth: 400
        implicitHeight: 500

        // Player selector at top
        Item {
            Layout.fillWidth: true
            implicitHeight: 80

            MaterialText {
                text: qsTr("Выбор источника")
                textStyle: "titleSmall"
                colorRole: "onSurfaceVariant"
                anchors.top: parent.top
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
                        color: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ?
                               Config.colors.primaryContainer : Config.colors.surfaceContainer
                        border.width: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ? 2 : 0
                        border.color: Config.colors.primary

                        MaterialText {
                            anchors.centerIn: parent
                            text: (modelData.identity || "?").charAt(0).toUpperCase()
                            textStyle: "titleMedium"
                            colorRole: (typeof MprisController !== 'undefined' && modelData === MprisController.activePlayer) ?
                                      "onPrimary" : "onSurface"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (typeof MprisController !== 'undefined') {
                                    MprisController.setActivePlayer(modelData)
                                    root.hide()
                                }
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }
                }
            }

            MaterialText {
                visible: Mpris.players.count === 0
                text: "Нет доступных плееров"
                textStyle: "bodyMedium"
                colorRole: "onSurfaceVariant"
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

                    property bool isFirstLoad: true

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            if (isFirstLoad) {
                                opacity = 1.0
                                isFirstLoad = false
                            } else {
                                opacity = 1.0
                            }
                        }
                    }

                    Connections {
                        target: (typeof MprisController !== 'undefined') ? MprisController : null

                        function onTrackChanged() {
                            if (typeof MprisController !== 'undefined') {
                                if (!albumImage.isFirstLoad) {
                                    albumImage.opacity = 0
                                }
                                albumImage.source = MprisController.activeTrack?.artUrl || ""
                            }
                        }
                    }

                    Behavior on opacity {
                        enabled: !albumImage.isFirstLoad
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
                    colorRole: "onSurfaceVariant"
                    opacity: albumImage.visible ? 0 : 0.6
                    visible: !albumImage.visible

                    Behavior on opacity {
                        OpacityAnimator { duration: 300 }
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
                colorRole: "onSurface"
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 350
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            MaterialText {
                visible: (typeof MprisController !== 'undefined') && !!(MprisController.activeTrack?.artist)
                text: {
                    if (typeof MprisController === 'undefined') return ""
                    const artist = MprisController.activeTrack?.artist || ""
                    const album = MprisController.activeTrack?.album || ""
                    return album && album !== "Unknown Album" ? `${artist} — ${album}` : artist
                }
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 350
                elide: Text.ElideRight
            }

            MaterialText {
                text: (typeof MprisController !== 'undefined') ? (MprisController.activePlayer?.identity || "Media Player") : "Media Player"
                textStyle: "bodyMedium"
                colorRole: "onSurfaceVariant"
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
                    if (typeof MprisController !== 'undefined') MprisController.previous()
                }
            }

            MaterialButton {
                text: (typeof MprisController !== 'undefined' && MprisController.isPlaying) ? "⏸" : "▶"
                variant: "filled"
                enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
                onClicked: {
                    if (typeof MprisController !== 'undefined') MprisController.togglePlaying()
                }
            }

            MaterialButton {
                text: "⏭"
                variant: "filledTonal"
                enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
                onClicked: {
                    if (typeof MprisController !== 'undefined') MprisController.next()
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
