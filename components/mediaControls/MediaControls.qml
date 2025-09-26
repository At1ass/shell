import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.services
import qs.config

Scope {
    id: root

    Loader {
        id: mediaControlsLoader
        active: GlobalStates.mediaControlsOpen

        onActiveChanged: {
            console.log("MediaControls active changed to:", active)
        }

        sourceComponent: PanelWindow {
            id: mediaWindow
            color: "transparent"

            // Позиционирование рядом с медиа виджетом
            anchors.left: false
            anchors.top: true
            anchors.right: false
            anchors.bottom: false

            implicitWidth: 400
            implicitHeight: content.implicitHeight

            // Временное позиционирование - потом сделаем адаптивное
            margins {
                left: 100
                top: 60
            }

            mask: Region {
                item: mediaBackground
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            WlrLayershell.namespace: "quickshell:mediaControls"
            WlrLayershell.layer: WlrLayer.Overlay

            // Автозакрытие при клике вне области
            HyprlandFocusGrab {
                id: focusGrab
                active: mediaControlsLoader.active && GlobalStates.mediaControlsOpen
                windows: [mediaWindow]
                onCleared: () => {
                    console.log("MediaControls focus lost, closing")
                    GlobalStates.mediaControlsOpen = false
                }
                onActiveChanged: {
                    console.log("HyprlandFocusGrab active changed to:", active, "mediaControlsOpen:", GlobalStates.mediaControlsOpen)
                }
            }

            // Закрытие по Escape через Item внутри окна
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        console.log("Escape pressed, closing MediaControls")
                        GlobalStates.mediaControlsOpen = false
                    }
                }
            }

            Rectangle {
                id: mediaBackground
                anchors.fill: parent
                color: Config.colors.surfaceContainerHigh
                radius: Config.shape.large
                border.width: 1
                border.color: Config.colors.outlineVariant

                // Простая тень
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: Config.spacing.small
                    anchors.leftMargin: Config.spacing.small
                    color: Qt.alpha("#000000", 0.1)
                    radius: Config.shape.large
                    z: -1
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Config.spacing.large
                    spacing: Config.spacing.medium

                    // Заголовок
                    Text {
                        Layout.fillWidth: true
                        text: "Медиа управление"
                        color: Config.colors.surfaceText
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Информация о треке
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Config.spacing.small

                        Text {
                            Layout.fillWidth: true
                            text: (typeof MprisController !== 'undefined' && MprisController.activeTrack)
                                ? MprisController.activeTrack.title || "Unknown Title"
                                : "No track"
                            color: Config.colors.surfaceText
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (typeof MprisController !== 'undefined' && MprisController.activeTrack)
                                ? MprisController.activeTrack.artist || "Unknown Artist"
                                : "No artist"
                            color: Config.colors.surfaceVariantText
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Кнопки управления
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Config.spacing.medium

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: (typeof MprisController !== 'undefined' && MprisController.canGoPrevious)
                                ? Config.colors.primary : Config.colors.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: Config.colors.primaryText || "#FFFFFF"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
                                onClicked: {
                                    if (typeof MprisController !== 'undefined') {
                                        MprisController.previous()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 50
                            height: 50
                            radius: 25
                            color: (typeof MprisController !== 'undefined' && MprisController.canTogglePlaying)
                                ? Config.colors.primary : Config.colors.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: (typeof MprisController !== 'undefined' && MprisController.isPlaying) ? "⏸" : "▶"
                                color: Config.colors.primaryText
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: (typeof MprisController !== 'undefined') && MprisController.canTogglePlaying
                                onClicked: {
                                    if (typeof MprisController !== 'undefined') {
                                        MprisController.togglePlaying()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: (typeof MprisController !== 'undefined' && MprisController.canGoNext)
                                ? Config.colors.primary : Config.colors.surfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: Config.colors.primaryText
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: (typeof MprisController !== 'undefined') && MprisController.canGoNext
                                onClicked: {
                                    if (typeof MprisController !== 'undefined') {
                                        MprisController.next()
                                    }
                                }
                            }
                        }
                    }

                    // Информация о плеере
                    Text {
                        Layout.fillWidth: true
                        text: (typeof MprisController !== 'undefined' && MprisController.activePlayer)
                            ? MprisController.activePlayer.identity || "Unknown Player"
                            : "No active player"
                        color: Config.colors.surfaceVariantText
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
