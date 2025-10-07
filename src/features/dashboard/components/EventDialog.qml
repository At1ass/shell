import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

Dialog {
    id: root

    dialogWidth: 400

    property bool isEditMode: false
    property var eventData: null
    property date selectedDate: new Date()

    signal eventSaved(string title, string startTime, string endTime, string color)
    signal eventDeleted(int eventId)

    function openDialog(editMode, data, date) {
        isEditMode = editMode
        eventData = data
        selectedDate = date || new Date()

        if (editMode && data) {
            titleField.text = data.title
            startTimeField.text = data.startTime
            endTimeField.text = data.endTime
            colorSegmented.selectedColor = data.color
        } else {
            titleField.text = ""
            const now = new Date()
            startTimeField.text = Qt.formatTime(now, "HH:mm")
            const endDate = new Date(now.getTime() + 60 * 60 * 1000)
            endTimeField.text = Qt.formatTime(endDate, "HH:mm")
            colorSegmented.selectedColor = "primary"
        }

        root.open()
        titleField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.large
        spacing: Config.spacing.medium

        // Header
        MaterialText {
            text: root.isEditMode ? "Edit Event" : "New Event"
            textStyle: "headlineSmall"
            colorRole: "onSurface"
            font.weight: Font.Bold
        }

        // Title field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.extraSmall

            MaterialText {
                text: "Title"
                textStyle: "labelMedium"
                colorRole: "onSurfaceVariant"
            }

            TextField {
                id: titleField
                Layout.fillWidth: true
                placeholderText: "Event title"
                color: Config.colors.onSurface
                font.pixelSize: Config.typography.bodyLarge.size
                background: Rectangle {
                    radius: Config.shape.small
                    color: Config.colors.surfaceContainerHighest
                    border.width: titleField.activeFocus ? 2 : 1
                    border.color: titleField.activeFocus ? Config.colors.primary : Config.colors.outline
                }
                padding: Config.spacing.small
            }
        }

        // Time fields
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.extraSmall

                MaterialText {
                    text: "Start time"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextField {
                    id: startTimeField
                    Layout.fillWidth: true
                    placeholderText: "HH:MM"
                    color: Config.colors.onSurface
                    font.pixelSize: Config.typography.bodyLarge.size
                    inputMask: "99:99"
                    background: Rectangle {
                        radius: Config.shape.small
                        color: Config.colors.surfaceContainerHighest
                        border.width: startTimeField.activeFocus ? 2 : 1
                        border.color: startTimeField.activeFocus ? Config.colors.primary : Config.colors.outline
                    }
                    padding: Config.spacing.small
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacing.extraSmall

                MaterialText {
                    text: "End time"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextField {
                    id: endTimeField
                    Layout.fillWidth: true
                    placeholderText: "HH:MM"
                    color: Config.colors.onSurface
                    font.pixelSize: Config.typography.bodyLarge.size
                    inputMask: "99:99"
                    background: Rectangle {
                        radius: Config.shape.small
                        color: Config.colors.surfaceContainerHighest
                        border.width: endTimeField.activeFocus ? 2 : 1
                        border.color: endTimeField.activeFocus ? Config.colors.primary : Config.colors.outline
                    }
                    padding: Config.spacing.small
                }
            }
        }

        // Priority/Color selector
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.extraSmall

            MaterialText {
                text: "Priority"
                textStyle: "labelMedium"
                colorRole: "onSurfaceVariant"
            }

            Item {
                id: colorSegmented
                Layout.fillWidth: true
                height: 48

                property string selectedColor: "primary"

                RowLayout {
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: [
                            { color: "primary", label: "High", displayColor: Config.colors.primary },
                            { color: "secondary", label: "Medium", displayColor: Config.colors.secondary },
                            { color: "tertiary", label: "Low", displayColor: Config.colors.tertiary }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Config.shape.small
                            color: colorSegmented.selectedColor === modelData.color ?
                                   modelData.displayColor : Config.colors.surfaceContainerHighest
                            border.width: 1
                            border.color: modelData.displayColor

                            Behavior on color {
                                ColorAnimation { duration: Config.motion.duration.short4 }
                            }

                            MaterialText {
                                anchors.centerIn: parent
                                text: modelData.label
                                textStyle: "labelLarge"
                                colorRole: colorSegmented.selectedColor === modelData.color ?
                                           "onPrimary" : "onSurface"
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: colorSegmented.selectedColor = modelData.color
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            // Delete button (only in edit mode)
            IconButton {
                visible: root.isEditMode
                variant: "standard"
                iconName: "delete"
                iconSize: Config.iconSize.large
                iconColor: Config.colors.error
                onClicked: {
                    if (root.eventData && root.eventData.id) {
                        eventDeleted(root.eventData.id)
                        root.close()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Cancel button
            MaterialButton {
                text: "Cancel"
                variant: "text"
                onClicked: root.close()
            }

            // Save button
            MaterialButton {
                text: root.isEditMode ? "Save" : "Add"
                variant: "filled"
                enabled: titleField.text.trim() !== ""
                onClicked: {
                    eventSaved(
                        titleField.text,
                        startTimeField.text,
                        endTimeField.text,
                        colorSegmented.selectedColor
                    )
                    root.close()
                }
            }
        }
    }
}