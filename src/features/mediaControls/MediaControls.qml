import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.src.core.services
import qs.src.core.config
import qs.src.features.mediaControls.components

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

            implicitWidth: playerCard.width + 40
            implicitHeight: playerCard.height + 40

            // Временное позиционирование - потом сделаем адаптивное
            margins {
                left: 100
                top: 60
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
                    // Увеличиваем задержку для предотвращения ложных срабатываний
                    focusLostTimer.start()
                }
            }

            // Задержка перед закрытием - увеличена для стабильности
            Timer {
                id: focusLostTimer
                interval: 200
                onTriggered: {
                    GlobalStates.mediaControlsOpen = false
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

            // Красивый плеер с новыми компонентами
            PlayerCard {
                id: playerCard
                anchors.centerIn: parent
                player: (typeof MprisController !== 'undefined') ? MprisController.activePlayer : null

                // Останавливаем таймер при наведении на плеер
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            focusLostTimer.stop()
                        }
                    }
                }
            }
        }
    }
}
