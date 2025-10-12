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

            implicitWidth: 320
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
                        duration: Config.motion.duration.short4
                        easing.type: Config.motion.easing.emphasized
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.motion.duration.short4
                        easing.type: Config.motion.easing.emphasized
                    }
                }

                MaterialCard {
                    id: osdCard
                    width: 320
                    height: 100
                    color: Config.colors.surfaceContainerHigh
                    radius: Config.shape.extraLarge

                    // M3 elevation через surface tint (вместо DropShadow)
                    // border уже есть в MaterialCard через outlined: true
                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        color: Config.colors.primary
                        opacity: 0.08
                    }
                    // Optional outline
                    Rectangle {
                        anchors.fill: parent
                        radius: osdCard.radius
                        border.color: Config.colors.outlineVariant
                        border.width: 1
                        color: "transparent"
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Config.spacing.large
                        spacing: Config.spacing.large

                        // Иконка громкости
                        Rectangle {
                            width: 56
                            height: 56
                            radius: Config.shape.full
                            color: root.currentMuted ? Config.colors.errorContainer : Config.colors.primaryContainer

                            Behavior on color {
                                ColorAnimation { duration: Config.motion.duration.short4 }
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
                                iconColor: root.currentMuted ? Config.colors.onErrorContainer : Config.colors.onPrimaryContainer
                                backgroundColor: "transparent"

                                Behavior on iconColor {
                                    ColorAnimation { duration: Config.motion.duration.short4 }
                                }
                            }
                        }

                        // Информация о громкости
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Config.spacing.extraSmall

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Config.spacing.small

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
                                radius: Config.shape.full
                                color: Config.colors.surfaceContainerHighest

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * root.currentVolume
                                    height: parent.height
                                    radius: Config.shape.full
                                    color: root.currentMuted ? Config.colors.error : Config.colors.primary

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Config.motion.duration.short4
                                            easing.type: Config.motion.easing.emphasized
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: Config.motion.duration.short4 }
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
