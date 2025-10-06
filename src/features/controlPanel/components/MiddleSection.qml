import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.ui.base

ColumnLayout {
    id: root

    property int currentTab: 0

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Config.spacing.small

    // Tab bar
    Rectangle {
        id: tabBar
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.medium

        RowLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.small
            spacing: 0

            // Tab buttons
            Repeater {
                model: ["Dashboard", "Audio", "Settings"]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Config.shape.small
                    color: index === root.currentTab ? Config.colors.primaryContainer : "transparent"

                    MaterialText {
                        anchors.centerIn: parent
                        text: modelData
                        textStyle: "labelMedium"
                        colorRole: index === root.currentTab ? "onPrimaryContainer" : "onSurface"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentTab = index;
                            console.log("Tab switched to:", modelData);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.motion.duration.short3
                            easing.type: Config.motion.easing.standard
                        }
                    }
                }
            }
        }
    }

    // Tab content area
    Rectangle {
        id: tabContent
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Config.colors.surfaceContainer
        radius: Config.shape.medium

        // Tab content loader
        Loader {
            id: tabLoader
            anchors.fill: parent
            anchors.margins: Config.spacing.medium

            sourceComponent: {
                switch (root.currentTab) {
                case 0:
                    return dashboardTab;
                case 1:
                    return audioTab;
                case 2:
                    return settingsTab;
                default:
                    return dashboardTab;
                }
            }
        }

        // Tab content components
        Component {
            id: dashboardTab
            ColumnLayout {
                anchors.fill: parent
                spacing: Config.spacing.medium

                SystemMetrics {
                }

                NotificationsList {
                }

                SystemTray {
                }
            }
        }

        Component {
            id: audioTab
            AudioControlsTab {
            }
        }

        Component {
            id: settingsTab
            SettingsTab {
            }
        }
    }
}
