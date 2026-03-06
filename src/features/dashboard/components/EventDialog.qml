import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services

Dialog {
    id: root

    dialogWidth: 440
    dialogHeight: 560

    property bool isEditMode: false
    property var eventData: null
    property date selectedDate: new Date()

    signal eventSaved(string title, string startTime, string endTime,
                      string calendar, string description, string location,
                      string categories, string recurrence, string until)
    signal eventDeleted(string uid, string calendar)

    function openDialog(editMode, data, date) {
        isEditMode = editMode
        eventData = data
        selectedDate = date || new Date()

        if (editMode && data) {
            titleField.text = data.title || ""
            startTimeField.text = data.startTime || ""
            endTimeField.text = data.endTime || ""
            descriptionField.text = data.description || ""
            locationField.text = data.location || ""
            categoriesField.text = data.categories || ""
            recurrenceCombo.currentIndex = 0
            // Set calendar
            const calIdx = CalendarService.calendars.indexOf(data.calendar)
            calendarCombo.currentIndex = calIdx >= 0 ? calIdx : 0
        } else {
            titleField.text = ""
            descriptionField.text = ""
            locationField.text = ""
            categoriesField.text = ""
            recurrenceCombo.currentIndex = 0
            const now = new Date()
            startTimeField.text = Qt.formatTime(now, "HH:mm")
            const endDate = new Date(now.getTime() + 60 * 60 * 1000)
            endTimeField.text = Qt.formatTime(endDate, "HH:mm")
            calendarCombo.currentIndex = 0
        }

        root.open()
        titleField.forceActiveFocus()
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        contentHeight: formLayout.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: formLayout
            width: parent.width

            spacing: Tokens.spacing.medium

            // Header
            MaterialText {
                text: root.isEditMode ? "Edit Event" : "New Event"
                textStyle: "headlineSmall"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }

            // Title
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: "Title"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Event title"
                    color: Theme.onSurface
                    font.pixelSize: Tokens.typography.bodyLarge.size
                    background: Rectangle {
                        radius: Tokens.shape.small
                        color: Theme.surfaceContainerHighest
                        border.width: titleField.activeFocus ? 2 : 1
                        border.color: titleField.activeFocus ? Theme.primary : Theme.outline
                    }
                    padding: Tokens.spacing.small
                }
            }

            // Time fields
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        text: "Start"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    TextField {
                        id: startTimeField
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        color: Theme.onSurface
                        font.pixelSize: Tokens.typography.bodyLarge.size
                        inputMask: "99:99"
                        background: Rectangle {
                            radius: Tokens.shape.small
                            color: Theme.surfaceContainerHighest
                            border.width: startTimeField.activeFocus ? 2 : 1
                            border.color: startTimeField.activeFocus ? Theme.primary : Theme.outline
                        }
                        padding: Tokens.spacing.small
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        text: "End"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    TextField {
                        id: endTimeField
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        color: Theme.onSurface
                        font.pixelSize: Tokens.typography.bodyLarge.size
                        inputMask: "99:99"
                        background: Rectangle {
                            radius: Tokens.shape.small
                            color: Theme.surfaceContainerHighest
                            border.width: endTimeField.activeFocus ? 2 : 1
                            border.color: endTimeField.activeFocus ? Theme.primary : Theme.outline
                        }
                        padding: Tokens.spacing.small
                    }
                }
            }

            // Location
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: "Location"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextField {
                    id: locationField
                    Layout.fillWidth: true
                    placeholderText: "Add location"
                    color: Theme.onSurface
                    font.pixelSize: Tokens.typography.bodyLarge.size
                    background: Rectangle {
                        radius: Tokens.shape.small
                        color: Theme.surfaceContainerHighest
                        border.width: locationField.activeFocus ? 2 : 1
                        border.color: locationField.activeFocus ? Theme.primary : Theme.outline
                    }
                    padding: Tokens.spacing.small
                }
            }

            // Description
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: "Description"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextArea {
                    id: descriptionField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    placeholderText: "Add description"
                    color: Theme.onSurface
                    font.pixelSize: Tokens.typography.bodyMedium.size
                    wrapMode: TextArea.Wrap
                    background: Rectangle {
                        radius: Tokens.shape.small
                        color: Theme.surfaceContainerHighest
                        border.width: descriptionField.activeFocus ? 2 : 1
                        border.color: descriptionField.activeFocus ? Theme.primary : Theme.outline
                    }
                    padding: Tokens.spacing.small
                }
            }

            // Calendar selector + Recurrence
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialComboBox {
                    id: calendarCombo
                    Layout.fillWidth: true
                    model: CalendarService.calendars
                    label: "Calendar"
                }

                MaterialComboBox {
                    id: recurrenceCombo
                    Layout.fillWidth: true
                    model: ["None", "Daily", "Weekly", "Monthly", "Yearly"]
                    label: "Repeat"
                }
            }

            // Categories
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: "Categories"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                TextField {
                    id: categoriesField
                    Layout.fillWidth: true
                    placeholderText: "work, personal, ..."
                    color: Theme.onSurface
                    font.pixelSize: Tokens.typography.bodyLarge.size
                    background: Rectangle {
                        radius: Tokens.shape.small
                        color: Theme.surfaceContainerHighest
                        border.width: categoriesField.activeFocus ? 2 : 1
                        border.color: categoriesField.activeFocus ? Theme.primary : Theme.outline
                    }
                    padding: Tokens.spacing.small
                }
            }

            Item { height: Tokens.spacing.small }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    visible: root.isEditMode
                    variant: "standard"
                    iconName: "delete"
                    iconSize: Tokens.iconSize.large
                    iconColor: Theme.error
                    onClicked: {
                        if (root.eventData && root.eventData.uid) {
                            eventDeleted(root.eventData.uid, root.eventData.calendar || "")
                            root.close()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                MaterialButton {
                    text: "Cancel"
                    variant: "text"
                    onClicked: root.close()
                }

                MaterialButton {
                    text: root.isEditMode ? "Save" : "Add"
                    variant: "filled"
                    enabled: titleField.text.trim() !== ""
                    onClicked: {
                        const recurrenceValues = ["none", "daily", "weekly", "monthly", "yearly"]
                        eventSaved(
                            titleField.text.trim(),
                            startTimeField.text,
                            endTimeField.text,
                            calendarCombo.currentText || "",
                            descriptionField.text.trim(),
                            locationField.text.trim(),
                            categoriesField.text.trim(),
                            recurrenceValues[recurrenceCombo.currentIndex] || "none",
                            "" // until (not implemented in UI yet)
                        )
                        root.close()
                    }
                }
            }
        }
    }
}
