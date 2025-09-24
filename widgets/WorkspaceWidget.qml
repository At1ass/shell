import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Column {
    id: workspaceWidget

    property int activeWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Reactive computation like in Caelesia
    readonly property var occupiedWorkspaces: {
        let result = {}
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            Hyprland.workspaces.values.forEach(workspace => {
                result[workspace.id] = (workspace.lastIpcObject?.windows || 0) > 0
            })
        }
        return result
    }

    spacing: 2

    Rectangle {
        id: workspaceContainer
        width: workspaceRow.width + 16
        height: 32
        color: "#49454f"
        radius: 16

        Row {
            id: workspaceRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: 9 // Workspaces 1-9

                Item {
                    width: 20
                    height: 20

                    property int wsId: index + 1
                    property bool isActive: workspaceWidget.activeWorkspaceId === wsId
                    property bool hasWindows: workspaceWidget.occupiedWorkspaces[wsId] ?? false

                    // Workspace indicator circle
                    Rectangle {
                        id: wsIndicator
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        radius: 8

                        // Use scale animation instead of size animation for smoothness
                        scale: {
                            if (isActive) return 1.0
                            if (hasWindows) return 0.75
                            return 0.375  // 6/16 = 0.375
                        }

                        color: {
                            if (isActive) return "#d0bcff"
                            if (hasWindows) return "#ccc2dc"
                            return "#938f99"
                        }

                        // Shadow for active workspace
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: isActive ? 1 : 0
                            color: "#000000"
                            opacity: isActive ? 0.1 : 0
                            radius: parent.radius
                            z: -1
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // No text numbers - clean Material Design

                    // Click interaction
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            Hyprland.dispatch("workspace " + wsId)
                        }

                        // Ripple effect
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.containsMouse ? 24 : 20
                            height: width
                            radius: width / 2
                            color: "#e6e1e5"
                            opacity: parent.containsMouse ? 0.04 : 0.0

                            Behavior on width {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}