import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.feedback
import Quickshell.Hyprland
import Quickshell
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: workspaceWidget

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    property var tooltipManager: null

    property int wsBaseIndex: widgetSettings.baseIndex ?? 1
    property int wsCount: widgetSettings.count ?? 9
    property bool showWindows: widgetSettings.showWindows ?? true

    // BarElement configuration - отключаем clickable, чтобы пропускать клики к индикаторам
    hoverable: false
    clickable: false

    // Поддержка прокрутки колесиком как у outfoxxed
    property int scrollAccumulator: 0
    property int currentIndex: 1

    // Reactive occupation map (pattern from caelesia Workspaces.qml)
    readonly property var occupied: {
        const map = {};
        if (Hyprland.workspaces?.values) {
            Hyprland.workspaces.values.forEach(ws => {
                map[ws.id] = (ws.lastIpcObject?.windows ?? 0) > 0;
            });
        }
        return map;
    }


    // nonVisualChildren: [
    //     TooltipItem {
    //         id: workspaceTooltip
    //         tooltip: workspaceWidget.tooltipManager
    //         owner: workspaceWidget
    //         show: workspaceWidget.hovered
    //
    //         Column {
    //             anchors.centerIn: parent
    //             spacing: Config.spacing.extraSmall
    //
    //             MaterialText {
    //                 // text: workspaceWidget.currentDateTime
    //                 text: "Hellow"
    //                 textStyle: "bodyLarge"
    //                 colorRole: "onSurface"
    //                 horizontalAlignment: Text.AlignHCenter
    //                 anchors.horizontalCenter: parent.horizontalCenter
    //                 wrapMode: Text.Wrap
    //             }
    //         }
    //     }
    // ]
    //

    // Обработчик прокрутки колесиком
    wheelHandler: function (wheel) {
        wheel.accepted = true;
        let acc = scrollAccumulator - wheel.angleDelta.y;
        const sign = Math.sign(acc);
        acc = Math.abs(acc);

        const offset = sign * Math.floor(acc / 120);
        scrollAccumulator = sign * (acc % 120);

        if (offset != 0) {
            const targetWorkspace = currentIndex + offset;
            const id = Math.max(wsBaseIndex, Math.min(wsBaseIndex + wsCount - 1, targetWorkspace));
            if (id != currentIndex) {
                currentIndex = id;
                Hyprland.dispatch("workspace " + id);
            }
        }
    }

    // Workspace indicators content
    RowLayout {
        spacing: Config.spacing.extraSmall

        Repeater {
            model: workspaceWidget.wsCount

            Item {
                id: wsItem
                implicitWidth: hasWindows ? windowIconsRow.implicitWidth + 12 : 24
                implicitHeight: 24

                required property int index
                property int wsIndex: workspaceWidget.wsBaseIndex + index
                property bool exists: workspaceWidget.occupied[wsIndex] ?? false
                property bool showIndicator: workspaceWidget.showWindows ? (exists || active) : true
                property bool active: wsIndex === Hyprland.focusedWorkspace?.id

                // Windows on workspace (reactive binding, re-evaluated on toplevels change)
                property var allWindows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsIndex)
                property bool hasWindows: allWindows.length > 0

                // Анимации состояний
                property real animActive: active ? 1 : 0
                Behavior on animActive {
                    NumberAnimation {
                        duration: Config.animations.durationShort
                    }
                }

                property real animExists: exists ? 1 : 0
                Behavior on animExists {
                    NumberAnimation {
                        duration: Config.animations.durationShort
                    }
                }

                // Обновляем currentIndex при изменении активного workspace
                onActiveChanged: {
                    if (active)
                        workspaceWidget.currentIndex = wsIndex;
                }

                // Плавная анимация размера
                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Config.animations.durationMedium
                        easing.type: Easing.OutCubic
                    }
                }

                // Подложка для активного workspace с иконками
                Rectangle {
                    id: activeBackground
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Config.shape.small
                    color: Config.colors.primary
                    opacity: active && hasWindows ? 0.15 : 0
                    z: -1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animations.durationMedium
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Workspace indicator circle (точка) - только для пустых workspace
                Rectangle {
                    id: wsIndicator
                    width: Config.typography.titleMedium.size
                    height: Config.typography.titleMedium.size
                    anchors.centerIn: parent
                    radius: Config.shape.small
                    visible: !hasWindows

                    // Масштабирование на основе состояния
                    scale: {
                        if (active)
                            return 1.0 + animActive * 0.15;
                        if (showIndicator)
                            return 0.8;
                        return 0.4;
                    }

                    // Интерполяция цветов на основе состояния
                    color: {
                        if (active)
                            return Config.colors.primary;
                        if (showIndicator)
                            return Config.colors.secondaryContainer;
                        return Config.colors.outline;
                    }

                    // Shadow for active workspace
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: active ? 1 : 0
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

                // Material Icons для окон - горизонтальный ряд
                Row {
                    id: windowIconsRow
                    anchors.centerIn: parent
                    spacing: 2
                    visible: hasWindows
                    opacity: hasWindows ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animations.durationShort
                        }
                    }

                    Repeater {
                        model: wsItem.allWindows

                        MaterialIcon {
                            required property var modelData

                            iconName: IconCategoryResolver.getAppCategoryIcon(modelData.lastIpcObject?.class, "terminal")
                            fontSize: Config.typography.bodyMedium.size
                            iconColor: active ? Config.colors.primary : Config.colors.onSurfaceVariant

                            // Плавная анимация появления
                            scale: 1
                            opacity: 1

                            Component.onCompleted: {
                                scale = 0;
                                opacity = 0;
                                scaleAnim.start();
                                opacityAnim.start();
                            }

                            NumberAnimation on scale {
                                id: scaleAnim
                                to: 1
                                duration: Config.animations.durationMedium
                                easing.type: Easing.OutBack
                                running: false
                            }

                            NumberAnimation on opacity {
                                id: opacityAnim
                                to: 1
                                duration: Config.animations.durationShort
                                running: false
                            }

                            Behavior on iconColor {
                                ColorAnimation {
                                    duration: Config.animations.durationMedium
                                }
                            }

                            MouseArea {
                                id: iconMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton

                                onClicked: {
                                    // Фокус на конкретное окно
                                    Hyprland.dispatch("focuswindow address:" + modelData.address);
                                }

                                // Ripple effect на hover
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.containsMouse ? parent.width + 4 : parent.width
                                    height: width
                                    radius: width / 2
                                    color: Config.colors.onSurface
                                    opacity: parent.containsMouse ? 0.08 : 0.0
                                    z: -1

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

                // Click interaction для всего workspace item
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: {
                        if (mouse.button === Qt.RightButton && widgetConfig?.clickAction) {
                            GlobalStates.handleClickAction(widgetConfig.clickAction);
                            return;
                        }

                        if (mouse.button === Qt.LeftButton) {
                            Hyprland.dispatch("workspace " + wsIndex);
                        }
                    }
                }
            }
        }
    }
}
