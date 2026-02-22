import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

Scope {
    id: root

    property bool osdVisible: false
    property real currentVolume: 0
    property bool currentMuted: false

    // Таймер автоскрытия
    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: root.osdVisible = false
    }

    // Слушаем изменения громкости
    Connections {
        target: AudioService
        function onVolumeChanged(volume, muted) {
            root.currentVolume = volume
            root.currentMuted = muted
            root.osdVisible = true
            hideTimer.restart()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWindow
            visible: root.osdVisible
            required property var modelData

            color: "transparent"
            anchors {
                top: true
                left: false
                right: false
                bottom: false
            }

            margins {
                top: 80
            }

            implicitWidth: 380
            implicitHeight: 120

            WlrLayershell.namespace: "quickshell:volumeosd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore

            // OSD контейнер с анимацией
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: osdCard.width
                height: osdCard.height

                // Анимация появления/исчезновения
                opacity: root.osdVisible ? 1 : 0
                scale: root.osdVisible ? 1 : 0.9

                Behavior on opacity {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.emphasized
                    }
                }

                MaterialCard {
                    id: osdCard
                    width: 380
                    height: 100
                    color: Theme.surfaceContainerHigh
                    radius: Tokens.shape.extraLarge

                    // M3 elevation через surface tint (вместо DropShadow)
                    // border уже есть в MaterialCard через outlined: true
                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        color: Theme.primary
                        opacity: 0.08
                    }
                    // Optional outline
                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        border.color: Theme.outlineVariant
                        border.width: 1
                        color: "transparent"
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.large
                        spacing: Tokens.spacing.large

                        // Иконка громкости
                        Rectangle {
                            width: 56
                            height: 56
                            radius: Tokens.shape.full
                            color: root.currentMuted ? Theme.errorContainer : Theme.primaryContainer

                            Behavior on color {
                                ColorAnimation { duration: Tokens.motion.duration.short4 }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: {
                                    if (root.currentMuted) return "volume_off"
                                    const v = root.currentVolume
                                    if (v <= 0.001) return "volume_mute"
                                    if (v < 0.34) return "volume_down"
                                    return "volume_up"
                                }
                                fontSize: 32
                                iconColor: root.currentMuted ? Theme.onErrorContainer : Theme.onPrimaryContainer
                                backgroundColor: "transparent"

                                Behavior on iconColor {
                                    ColorAnimation { duration: Tokens.motion.duration.short4 }
                                }
                            }
                        }

                        // Информация о громкости
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialText {
                                    text: root.currentMuted ? "Звук выключен" : "Громкость"
                                    textStyle: "titleMedium"
                                    colorRole: "onSurface"
                                    font.weight: Font.Medium
                                }

                                Item { Layout.fillWidth: true }

                                MaterialText {
                                    text: Math.round(root.currentVolume * 100) + "%"
                                    textStyle: "titleLarge"
                                    colorRole: "primary"
                                    font.weight: Font.Bold
                                }
                            }

                            // Прогресс-бар
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: Tokens.shape.full
                                color: Theme.surfaceContainerHighest

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * root.currentVolume
                                    height: parent.height
                                    radius: Tokens.shape.full
                                    color: root.currentMuted ? Theme.error : Theme.primary

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Tokens.motion.duration.short4
                                            easing.type: Tokens.motion.easing.emphasized
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: Tokens.motion.duration.short4 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
