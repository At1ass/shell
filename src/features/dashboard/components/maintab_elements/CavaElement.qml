import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

MaterialCard {
    Layout.row: 3
    Layout.column: 6
    Layout.columnSpan: 4
    Layout.rowSpan: 1
    Layout.fillWidth: true
    Layout.preferredHeight: 120
    Layout.preferredWidth: 220
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: 4

        // Visualizer bars
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                anchors.fill: parent
                anchors.bottomMargin: 4
                spacing: 3

                Repeater {
                    model: 20

                    Rectangle {
                        width: 8
                        anchors.bottom: parent.bottom
                        radius: 2

                        property real barHeight: {
                            // Mock data - random heights
                            var heights = [0.2, 0.5, 0.8, 0.6, 0.9, 0.4, 0.7, 0.3, 0.85, 0.5, 0.65, 0.9, 0.45, 0.75, 0.55, 0.8, 0.4, 0.6, 0.3, 0.7];
                            return heights[index];
                        }

                        height: parent.height * barHeight

                        color: {
                            if (barHeight > 0.7)
                                return Config.colors.primary;
                            if (barHeight > 0.4)
                                return Config.colors.tertiary;
                            return Config.colors.primaryContainer;
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: Config.motion.duration.medium2
                                easing.type: Config.motion.easing.emphasizedDecelerate
                            }
                        }

                        // Animation loop
                        SequentialAnimation on barHeight {
                            running: true
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: Math.random() * 0.9 + 0.1
                                duration: 300 + Math.random() * 200
                                easing.type: Config.motion.easing.standard
                            }

                            PauseAnimation {
                                duration: 50
                            }
                        }
                    }
                }
            }
        }
    }
}
