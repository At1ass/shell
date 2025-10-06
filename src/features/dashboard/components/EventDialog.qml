import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config

Rectangle {
    id: root
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    visible: false
    opacity: 0

    property bool isEditMode: false
    property var eventData: null
    property date selectedDate: new Date()

    signal eventSaved(string title, string startTime, string endTime, string color)
    signal eventDeleted(int eventId)
    signal cancelled()

    Behavior on opacity {
        NumberAnimation {
            duration: Config.motion.duration.medium2
            easing.type: Config.motion.easing.emphasizedDecelerate
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    function open(editMode, data, date) {
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

        root.visible = true
        root.opacity = 1
        titleField.forceActiveFocus()
    }

    function close() {
        root.opacity = 0
        closeTimer.start()
    }

    Timer {
        id: closeTimer
        interval: Config.motion.duration.medium2
        onTriggered: {
            root.visible = false
            cancelled()
        }
    }

    MaterialCard {
        anchors.centerIn: parent
        width: 400
        height: contentLayout.implicitHeight + Config.spacing.large * 2
        color: Config.colors.surfaceContainerHigh
        radius: Config.shape.extraLarge

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Block clicks
        }

        ColumnLayout {
            id: contentLayout
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
                Rectangle {
                    visible: root.isEditMode
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: deleteMouseArea.containsMouse ? Config.colors.errorContainer : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "delete"
                        fontSize: Config.typography.titleLarge.size
                        iconColor: deleteMouseArea.containsMouse ? Config.colors.onErrorContainer : Config.colors.error
                        backgroundColor: "transparent"
                    }

                    MouseArea {
                        id: deleteMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.eventData && root.eventData.id) {
                                eventDeleted(root.eventData.id)
                                root.close()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Cancel button
                Rectangle {
                    Layout.preferredWidth: cancelText.implicitWidth + Config.spacing.large * 2
                    Layout.preferredHeight: 48
                    radius: 24
                    color: cancelMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialText {
                        id: cancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        textStyle: "labelLarge"
                        colorRole: "primary"
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                // Save button
                Rectangle {
                    Layout.preferredWidth: saveText.implicitWidth + Config.spacing.large * 2
                    Layout.preferredHeight: 48
                    radius: 24
                    color: saveMouseArea.containsMouse ? Config.colors.primaryContainer : Config.colors.primary

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    MaterialText {
                        id: saveText
                        anchors.centerIn: parent
                        text: root.isEditMode ? "Save" : "Add"
                        textStyle: "labelLarge"
                        colorRole: "onPrimary"
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: saveMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
    }
}
