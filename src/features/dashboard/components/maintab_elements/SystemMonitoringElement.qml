import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    RowLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        Repeater {
            model: [
                {
                    label: "CPU",
                    icon: "developer_board",
                    temp: SystemMonitorService.cpuTemp + "°",
                    percent: SystemMonitorService.cpuUsage,
                    value: Math.round(SystemMonitorService.cpuUsage) + "%"
                },
                {
                    label: "GPU",
                    icon: "videogame_asset",
                    temp: SystemMonitorService.gpuTemp + "°",
                    percent: SystemMonitorService.gpuUsage,
                    value: Math.round(SystemMonitorService.gpuUsage) + "%"
                },
                {
                    label: "RAM",
                    icon: "memory",
                    temp: SystemMonitorService.ramUsed + "G",
                    percent: SystemMonitorService.ramUsage,
                    value: Math.round(SystemMonitorService.ramUsage) + "%"
                },
                {
                    label: "Disk",
                    icon: "storage",
                    temp: SystemMonitorService.diskUsed,
                    percent: SystemMonitorService.diskUsage,
                    value: Math.round(SystemMonitorService.diskUsage) + "%"
                }
            ]

            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Animated progress value
                property real animatedProgress: modelData.percent / 100

                Behavior on animatedProgress {
                    NumberAnimation {
                        duration: Config.motion.duration.long2
                        easing.type: Config.motion.easing.emphasizedDecelerate
                    }
                }

                // Circular progress
                Item {
                    width: 70
                    height: 70
                    anchors.centerIn: parent

                    // Background circle
                    Rectangle {
                        anchors.centerIn: parent
                        width: 70
                        height: 70
                        radius: 35
                        color: Config.colors.surfaceContainerHighest
                    }

                    // Progress ring
                    Shape {
                        id: ring
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer   // обычно даёт более гладкую дугу

                        // Усиленное сглаживание (MSAA) для всего элемента
                        layer.enabled: true
                        layer.samples: 4

                        // Те же данные, что и раньше
                        property real progress: parent.parent.animatedProgress   // 0..1
                        property real stroke: 6
                        property real radius: Math.floor((Math.min(width, height) - stroke) / 2)  // вписываем дугу внутрь
                        // половинные пиксели уменьшают «лесенку» на чётных толщ. линий
                        property real cx: Math.round(width / 2) + 0.5
                        property real cy: Math.round(height / 2) + 0.5

                        property color progressColor: {
                            const percent = progress * 100;
                            if (percent < 50)
                                return Config.colors.primary;
                            if (percent < 80)
                                return Config.colors.tertiary;
                            return Config.colors.error;
                        }

                        Behavior on progressColor {
                            ColorAnimation {
                                duration: Config.motion.duration.medium2
                            }
                        }

                        ShapePath {
                            strokeColor: ring.progressColor
                            strokeWidth: ring.stroke
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            fillColor: "transparent"

                            // дуга сверху по часовой
                            PathAngleArc {
                                centerX: ring.cx
                                centerY: ring.cy
                                radiusX: ring.radius
                                radiusY: ring.radius
                                startAngle: -90
                                // маленький минимум, чтобы не терять AA на очень маленьких значениях
                                sweepAngle: Math.max(0.0001, ring.progress * 360)
                            }
                        }
                    }
                    // Canvas {
                    //     id: progressCanvas
                    //     anchors.fill: parent
                    //
                    //     property real progress: parent.parent.animatedProgress
                    //     property color progressColor: {
                    //         const percent = parent.parent.animatedProgress * 100
                    //         if (percent < 50)
                    //             return Config.colors.primary;
                    //         if (percent < 80)
                    //             return Config.colors.tertiary;
                    //         return Config.colors.error;
                    //     }
                    //
                    //     onProgressChanged: requestPaint()
                    //     onProgressColorChanged: requestPaint()
                    //
                    //     onPaint: {
                    //         var ctx = getContext("2d");
                    //         var centerX = width / 2;
                    //         var centerY = height / 2;
                    //         var radius = 32;
                    //         var lineWidth = 6;
                    //
                    //         ctx.clearRect(0, 0, width, height);
                    //
                    //         // Draw progress arc
                    //         ctx.beginPath();
                    //         ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + (progress * 2 * Math.PI), false);
                    //         ctx.lineWidth = lineWidth;
                    //         ctx.strokeStyle = progressColor;
                    //         ctx.lineCap = "round";
                    //         ctx.stroke();
                    //     }
                    //
                    //     Behavior on progressColor {
                    //         ColorAnimation {
                    //             duration: Config.motion.duration.medium2
                    //         }
                    //     }
                    // }

                    // Content inside circle
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        MaterialIcon {
                            iconName: modelData.icon
                            fontSize: Config.typography.titleMedium.size
                            iconColor: Config.colors.primary
                            backgroundColor: "transparent"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        MaterialText {
                            text: modelData.temp
                            textStyle: "labelLarge"
                            colorRole: "onSurface"
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // Percentage badge (top right corner)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -4
                        anchors.topMargin: -4
                        width: 36
                        height: 18
                        radius: 9
                        // color: progressCanvas.progressColor
                        color: ring.progressColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.motion.duration.medium2
                            }
                        }

                        MaterialText {
                            anchors.centerIn: parent
                            text: modelData.value
                            textStyle: "labelSmall"
                            colorRole: "onPrimary"
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
