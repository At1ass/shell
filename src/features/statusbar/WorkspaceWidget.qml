import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import Quickshell.Hyprland
import qs.src.ui.base
import qs.src.core.config

BarElement {
    id: workspaceWidget

    property int wsBaseIndex: 1
    property int wsCount: 9

    // BarElement configuration - отключаем clickable, чтобы пропускать клики к индикаторам
    hoverable: true
    clickable: false

    // Поддержка прокрутки колесиком как у outfoxxed
    property int scrollAccumulator: 0
    property int currentIndex: 1

    // Реактивная система отслеживания workspace - как у outfoxxed
    signal workspaceAdded(workspace: var)

    // Обработчик прокрутки колесиком
    wheelHandler: function(wheel) {
        wheel.accepted = true
        let acc = scrollAccumulator - wheel.angleDelta.y
        const sign = Math.sign(acc)
        acc = Math.abs(acc)

        const offset = sign * Math.floor(acc / 120)
        scrollAccumulator = sign * (acc % 120)

        if (offset != 0) {
            const targetWorkspace = currentIndex + offset
            const id = Math.max(wsBaseIndex, Math.min(wsBaseIndex + wsCount - 1, targetWorkspace))
            if (id != currentIndex) {
                currentIndex = id
                Hyprland.dispatch("workspace " + id)
            }
        }
    }

    // Невизуальные элементы
    nonVisualChildren: [
        Connections {
            target: Hyprland.workspaces

            function onObjectInsertedPost(workspace) {
                workspaceWidget.workspaceAdded(workspace)
            }
        }
    ]

    // Workspace indicators content
    Row {
        spacing: Config.spacing.small

        Repeater {
            model: workspaceWidget.wsCount

            Item {
                id: wsItem
                width: 24
                height: 24

                required property int index
                property int wsIndex: workspaceWidget.wsBaseIndex + index
                property var workspace: null
                property bool exists: workspace != null
                // Показываем как активный только workspace в фокусе (не просто активный на мониторе)
                property bool active: workspace?.id === Hyprland.focusedWorkspace?.id

                // Анимации состояний как у outfoxxed
                property real animActive: active ? 1 : 0
                Behavior on animActive {
                    NumberAnimation {
                        duration: Config.animations.durationShort
                    }
                }

                property real animExists: exists ? 1 : 0
                Behavior on animExists { NumberAnimation { duration: Config.animations.durationShort } }

                // Обновляем currentIndex при изменении активного workspace
                onActiveChanged: {
                    if (active) workspaceWidget.currentIndex = wsIndex
                }

                // Подключение к системе workspace
                Connections {
                    target: workspaceWidget

                    function onWorkspaceAdded(workspace) {
                        if (workspace.id == wsItem.wsIndex) {
                            wsItem.workspace = workspace
                        }
                    }
                }

                // Workspace indicator circle
                Rectangle {
                    id: wsIndicator
                    anchors.centerIn: parent
                    width: Config.typography.titleMedium.size
                    height: Config.typography.titleMedium.size
                    radius: Config.shape.small

                    // Масштабирование на основе состояния
                    scale: {
                        if (active) return 1.0 + animActive * 0.15
                        if (exists) return 0.8
                        return 0.4
                    }

                    // Интерполяция цветов на основе состояния
                    color: {
                        if (active) return Config.colors.primary
                        if (exists) return Config.colors.secondaryContainer
                        return Config.colors.outline
                    }

                    // Shadow for active workspace
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: active ? 1 : 0
                        // color: "#000000"
                        color: Config.colors.onSurface
                        opacity: active ? 0.10 : 0
                        radius: parent.radius
                        z: -1
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Config.animations.durationMedium
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animations.durationMedium
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Click interaction
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        Hyprland.dispatch("workspace " + wsIndex)
                    }

                    // Ripple effect
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.containsMouse ? 24 : 20
                        height: width
                        radius: width / 2
                        // color: Config.colors.textPrimary
                        color: Config.colors.onPrimary
                        opacity: parent.containsMouse ? 0.04 : 0.0

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animations.durationShort
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animations.durationShort
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }


    // Инициализация существующих workspace
    Component.onCompleted: {
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            Hyprland.workspaces.values.forEach(workspace => {
                workspaceWidget.workspaceAdded(workspace)
            })
        }
    }
}
