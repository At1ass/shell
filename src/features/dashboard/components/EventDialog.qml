import QtQuick
import QtQuick.Layouts
import Calendar
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.ui.inputs
import qs.src.core.config

Dialog {
    id: root

    dialogWidth: 440
    dialogHeight: 560

    property bool isEditMode: false
    property var eventData: null
    property date selectedDate: new Date()
    property bool dirty: false

    // fields: QVariantMap matching IcalParser::buildIcsString shape
    signal eventSaved(var fields)
    signal eventDeleted(string uid, bool isRecurring)

    // Override Dialog.requestClose so scrim click prompts when dirty.
    function requestClose() {
        if (dirty) discardConfirm.visible = true
        else close()
    }

    // ── Validation ────────────────────────────────────────────────
    readonly property var _timeRe: /^([01]\d|2[0-3]):[0-5]\d$/
    readonly property var _dateRe: /^\d{4}-\d{2}-\d{2}$/

    readonly property string _validationError: {
        if (titleField.text.trim() === "") return "Title is required"
        if (!_timeRe.test(startTimeField.text)) return "Invalid start time (HH:MM)"
        if (!_timeRe.test(endTimeField.text))   return "Invalid end time (HH:MM)"
        const sParts = startTimeField.text.split(":")
        const eParts = endTimeField.text.split(":")
        const sMin = parseInt(sParts[0])*60 + parseInt(sParts[1])
        const eMin = parseInt(eParts[0])*60 + parseInt(eParts[1])
        if (eMin <= sMin) return "End must be after start"
        if (recurrenceCombo.currentIndex !== 0 && untilField.text.length > 0) {
            if (!_dateRe.test(untilField.text)) return "Until: yyyy-MM-dd"
            const u = new Date(untilField.text)
            if (isNaN(u.getTime())) return "Invalid until date"
        }
        return ""
    }
    readonly property bool _isValid: _validationError === ""

    function openDialog(editMode, data, date) {
        isEditMode = editMode
        eventData = data
        selectedDate = date || new Date()

        if (editMode && data) {
            titleField.text = data.title || ""
            startTimeField.text = data.start ? Qt.formatTime(data.start, "HH:mm") : ""
            endTimeField.text   = data.end   ? Qt.formatTime(data.end,   "HH:mm") : ""
            descriptionField.text = data.description || ""
            locationField.text = data.location || ""
            categoriesField.text = (data.categories || []).join(", ")

            const recurrenceValues = ["none", "daily", "weekly", "monthly", "yearly"]
            const idx = recurrenceValues.indexOf(data.recurrence || "none")
            recurrenceCombo.currentIndex = idx >= 0 ? idx : 0

            untilField.text = data.recurrenceUntil
                ? Qt.formatDate(data.recurrenceUntil, "yyyy-MM-dd")
                : ""

            const calIdx = CalendarBackend.calendars.indexOf(data.calendar)
            calendarCombo.currentIndex = calIdx >= 0 ? calIdx : 0
        } else {
            titleField.text = ""
            descriptionField.text = ""
            locationField.text = ""
            categoriesField.text = ""
            untilField.text = ""
            recurrenceCombo.currentIndex = 0
            const now = new Date()
            startTimeField.text = Qt.formatTime(now, "HH:mm")
            const endDate = new Date(now.getTime() + 60 * 60 * 1000)
            endTimeField.text = Qt.formatTime(endDate, "HH:mm")
            calendarCombo.currentIndex = 0
        }

        root.open()
        titleField.inputItem.forceActiveFocus()
        // Reset AFTER field assignments — those fired onTextChanged and
        // would have flipped dirty=true otherwise.
        dirty = false
    }

    // Build a QVariantMap for CalendarBackend.addEvent / editEvent.
    // Times are merged into selectedDate.
    function _buildFields() {
        const recurrenceValues = ["none", "daily", "weekly", "monthly", "yearly"]
        const startParts = startTimeField.text.split(":")
        const endParts   = endTimeField.text.split(":")

        const startDt = new Date(selectedDate)
        startDt.setHours(parseInt(startParts[0]) || 0,
                         parseInt(startParts[1]) || 0, 0, 0)
        const endDt = new Date(selectedDate)
        endDt.setHours(parseInt(endParts[0]) || 0,
                       parseInt(endParts[1]) || 0, 0, 0)

        const cats = categoriesField.text.trim().length > 0
            ? categoriesField.text.split(",").map(s => s.trim()).filter(s => s.length > 0)
            : []

        const fields = {
            calendar:    calendarCombo.currentText || "",
            title:       titleField.text.trim(),
            description: descriptionField.text.trim(),
            location:    locationField.text.trim(),
            categories:  cats,
            start:       startDt,
            end:         endDt,
            allDay:      false,
            recurrence:  recurrenceValues[recurrenceCombo.currentIndex] || "none"
        }
        if (recurrenceCombo.currentIndex !== 0 && _dateRe.test(untilField.text)) {
            fields.recurrenceUntil = new Date(untilField.text)
        }
        return fields
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

                MaterialTextField {
                    id: titleField
                    Layout.fillWidth: true
                    placeholderText: "Event title"
                    onTextEdited: root.dirty = true
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

                    MaterialTextField {
                        id: startTimeField
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        validator: RegularExpressionValidator { regularExpression: root._timeRe }
                        onTextEdited: root.dirty = true
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

                    MaterialTextField {
                        id: endTimeField
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        validator: RegularExpressionValidator { regularExpression: root._timeRe }
                        onTextEdited: root.dirty = true
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

                MaterialTextField {
                    id: locationField
                    Layout.fillWidth: true
                    placeholderText: "Add location"
                    onTextEdited: root.dirty = true
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

                MaterialTextArea {
                    id: descriptionField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    placeholderText: "Add description"
                    onTextEdited: root.dirty = true
                }

                // Clickable links extracted from description
                MaterialText {
                    readonly property string rawText: descriptionField.text
                    readonly property var urls: rawText.match(/https?:\/\/[^\s<>"{}|\\^`\[\]]+/g) || []
                    visible: urls.length > 0
                    text: urls.map(u => '<a href="' + u + '" style="color:' + Theme.primary + ';">' + u + '</a>').join("<br>")
                    textFormat: Text.RichText
                    textStyle: "labelMedium"
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                    onLinkActivated: (link) => Qt.openUrlExternally(link)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }

            // Calendar selector + Recurrence
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialComboBox {
                    id: calendarCombo
                    Layout.fillWidth: true
                    model: CalendarBackend.calendars
                    label: "Calendar"
                    onCurrentIndexChanged: root.dirty = true
                }

                MaterialComboBox {
                    id: recurrenceCombo
                    Layout.fillWidth: true
                    model: ["None", "Daily", "Weekly", "Monthly", "Yearly"]
                    label: "Repeat"
                    onCurrentIndexChanged: root.dirty = true
                }
            }

            // Repeat until — only relevant when recurrence is set
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall
                visible: recurrenceCombo.currentIndex !== 0

                MaterialText {
                    text: "Repeat until"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                // No inputMask here: with a mask the "empty" field contains the mask
                // literals, so the optional-until check `length > 0` was always true
                // and recurring events could never be saved without a date.
                MaterialTextField {
                    id: untilField
                    Layout.fillWidth: true
                    placeholderText: "yyyy-MM-dd (optional)"
                    validator: RegularExpressionValidator { regularExpression: root._dateRe }
                    onTextEdited: root.dirty = true
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

                MaterialTextField {
                    id: categoriesField
                    Layout.fillWidth: true
                    placeholderText: "work, personal, ..."
                    onTextEdited: root.dirty = true
                }
            }

            // Validation hint — surfaces why Save is disabled
            MaterialText {
                Layout.fillWidth: true
                text: root._validationError
                textStyle: "labelSmall"
                color: Theme.error
                visible: !root._isValid && titleField.text.length > 0
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: Tokens.spacing.small }

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
                            root.eventDeleted(root.eventData.uid,
                                              root.eventData.isRecurringMaster === true)
                            root.close()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                MaterialButton {
                    text: "Cancel"
                    variant: "text"
                    onClicked: root.requestClose()
                }

                MaterialButton {
                    text: root.isEditMode ? "Save" : "Add"
                    variant: "filled"
                    enabled: root._isValid
                    onClicked: {
                        root.eventSaved(root._buildFields())
                        root.close()
                    }
                }
            }
        }
    }

    // Discard-confirmation overlay shown when user tries to dismiss
    // a dialog that has unsaved changes.
    Rectangle {
        id: discardConfirm
        anchors.fill: parent
        color: Qt.alpha(Theme.scrim, Tokens.state.scrimOpacity)
        visible: false
        z: 10

        MouseArea { anchors.fill: parent }  // swallow clicks

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.spacing.large * 2, 360)
            height: discardCol.implicitHeight + Tokens.spacing.large * 2
            radius: Tokens.shape.large
            color: Theme.surfaceContainerHighest

            ColumnLayout {
                id: discardCol
                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
                spacing: Tokens.spacing.medium

                MaterialText {
                    text: "Discard changes?"
                    textStyle: "titleMedium"
                    colorRole: "onSurface"
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                MaterialText {
                    text: "Unsaved changes will be lost."
                    textStyle: "bodyMedium"
                    colorRole: "onSurfaceVariant"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Item { Layout.fillWidth: true }

                    MaterialButton {
                        text: "Keep editing"
                        variant: "text"
                        onClicked: discardConfirm.visible = false
                    }
                    MaterialButton {
                        text: "Discard"
                        variant: "filled"
                        onClicked: {
                            discardConfirm.visible = false
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
