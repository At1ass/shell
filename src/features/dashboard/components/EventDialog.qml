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
    objectName: "calendarEventDialog"

    dialogWidth: 440
    dialogHeight: 640

    property bool isEditMode: false
    property var eventData: null
    property date selectedDate: new Date()
    property bool dirty: false

    // All-day events have no time-of-day; the time row hides and validation
    // skips time checks (they used to hard-block editing all-day events).
    property bool allDayMode: false

    // Whether the user actually touched start/end/all-day. Untouched times
    // are OMITTED from the field map on edits — the backend treats absent
    // keys as "leave as is", which keeps series anchors and multi-day
    // events intact when only the title changes.
    property bool _timesEdited: false

    // fields: QVariantMap matching IcalParser::buildIcsString shape
    signal eventSaved(var fields)
    signal eventDeleted(string uid, bool isRecurring)

    // Override Dialog.requestClose so scrim click prompts when dirty.
    function requestClose() {
        if (saving) return
        if (dirty) discardConfirm.visible = true
        else close()
    }

    // ── Validation ────────────────────────────────────────────────
    readonly property var _timeRe: /^([01]\d|2[0-3]):[0-5]\d$/
    readonly property var _dateRe: /^\d{4}-\d{2}-\d{2}$/

    property string pendingSaveId: ""
    readonly property bool saving: pendingSaveId !== ""
    property string saveError: ""
    property bool _completed: false
    function beginSave(requestId) {
        if (!requestId) { saveError = "Could not start saving. Try again."; return }
        if (!visible || opacity < 1) open()
        pendingSaveId = requestId
        saveError = ""
    }
    function _focusSaveError() { if (visible && saveError !== "" && !saving) saveButton.forceActiveFocus(Qt.OtherFocusReason) }
    function finishSave(requestId, success, message) {
        if (!pendingSaveId || requestId !== pendingSaveId) return
        pendingSaveId = ""
        if (success) { _completed = true; dirty = false; close() }
        else {
            saveError = message || "The event could not be saved. Try again."
            dirty = true
            Qt.callLater(root._focusSaveError)
        }
    }
    function _dateError(text) {
        if (!_dateRe.test(text)) return "Use yyyy-MM-dd"
        return _parseLocalDate(text) ? "" : "This date does not exist"
    }
    function _timeError(text, date) {
        if (!_timeRe.test(text)) return "Use HH:MM (00:00–23:59)"
        if (!date) return ""
        const parts = text.split(":").map(Number)
        const value = new Date(date)
        value.setHours(parts[0], parts[1], 0, 0)
        return value.getHours() === parts[0] && value.getMinutes() === parts[1]
            ? "" : "This local time does not exist on this date"
    }
    readonly property var _fieldErrors: {
        const sd = _parseLocalDate(startDateField.text)
        const ed = _parseLocalDate(endDateField.text)
        const errors = {
            title: titleField.text.trim() ? "" : "A title is required",
            startDate: _dateError(startDateField.text), endDate: _dateError(endDateField.text),
            startTime: allDayMode ? "" : _timeError(startTimeField.text, sd),
            endTime: allDayMode ? "" : _timeError(endTimeField.text, ed),
            until: recurrenceCombo.currentIndex !== 0 && untilField.text ? _dateError(untilField.text) : "",
            calendar: calendarCombo.currentText ? "" : "No calendar is available"
        }
        if (allDayMode && ed && _storageEnd(ed).getFullYear() > 9999) errors.endDate = "Choose an all-day end date before 9999-12-31"
        if (sd && ed && ed.getTime() < sd.getTime()) errors.endDate = "End date must not precede start date"
        if ((!isEditMode || _timesEdited) && !allDayMode && sd && ed && sd.getTime() === ed.getTime() && !errors.startTime && !errors.endTime
                && endTimeField.text <= startTimeField.text) errors.endTime = "End time must be after start time"
        const until = _parseLocalDate(untilField.text)
        if (recurrenceCombo.currentIndex !== 0 && until && sd && until.getTime() < sd.getTime()) errors.until = "Repeat-until date must not precede start date"
        return errors
    }
    readonly property string _validationError: {
        const labels = {title:"Title",startDate:"Start date",endDate:"End date",startTime:"Start time",endTime:"End time",until:"Repeat until",calendar:"Calendar"}
        for (const key of Object.keys(labels)) if (_fieldErrors[key]) return labels[key] + ": " + _fieldErrors[key]
        return ""
    }

    // Parse "yyyy-MM-dd" as a LOCAL date. `new Date(string)` reads it as
    // UTC midnight, which lands one day early west of Greenwich.
    // RFC 5545 stores an all-day DTEND as the EXCLUSIVE next day; humans read
    // the last day the event covers. These two convert between the views.
    function _displayEnd(end, allDay) {
        if (!allDay) return end
        const d = new Date(end)
        d.setDate(d.getDate() - 1)
        return d
    }
    function _storageEnd(lastDay) {
        const d = new Date(lastDay)
        d.setDate(d.getDate() + 1)
        return d
    }

    // Restores a half-composed edit (see openDialog's `pending`).
    function _applyPending(f) {
        if (f.title !== undefined)       titleField.text = f.title
        if (f.description !== undefined) descriptionField.text = f.description
        if (f.location !== undefined)    locationField.text = f.location
        if (f.categories !== undefined)  categoriesField.text = (f.categories || []).join(", ")
        if (f.allDay !== undefined)      allDayMode = f.allDay === true
        if (f.start) {
            startDateField.text = Qt.formatDate(f.start, "yyyy-MM-dd")
            startTimeField.text = Qt.formatTime(f.start, "HH:mm")
        }
        if (f.end) {
            endDateField.text = Qt.formatDate(
                root._displayEnd(f.end, f.allDay === true), "yyyy-MM-dd")
            endTimeField.text = Qt.formatTime(f.end, "HH:mm")
        }
        if (f.recurrence !== undefined) {
            const rv = ["none", "daily", "weekly", "monthly", "yearly"]
            const i = rv.indexOf(f.recurrence)
            recurrenceCombo.currentIndex = i >= 0 ? i : 0
        }
        if (f.recurrenceUntil) untilField.text = Qt.formatDate(f.recurrenceUntil, "yyyy-MM-dd")
        // The user had already composed this, so it IS dirty, and the times
        // must be treated as edited or _buildFields would ignore them.
        dirty = true
        _timesEdited = true
    }

    function _parseLocalDate(text) {
        if (!_dateRe.test(text)) return null
        const parts = text.split("-").map(Number)
        if (parts[0] < 1 || parts[1] < 1 || parts[1] > 12 || parts[2] < 1 || parts[2] > 31) return null
        // setFullYear avoids the Date constructor's 1900 offset for years 0–99.
        const date = new Date(0)
        date.setFullYear(parts[0], parts[1] - 1, parts[2])
        date.setHours(0, 0, 0, 0)
        return date.getFullYear() === parts[0] && date.getMonth() === parts[1] - 1 && date.getDate() === parts[2] ? date : null
    }
    readonly property bool _isValid: _validationError === ""

    // `pending` (optional) restores a half-composed edit — see the cancel path
    // in RecurrenceEditChoice. Without it, answering "cancel" to the
    // this-occurrence-or-series question threw the user's typing away.
    function openDialog(editMode, data, date, pending) {
        if (saving) return
        _completed = false
        saveError = ""
        isEditMode = editMode
        eventData = data
        selectedDate = date || new Date()

        if (editMode && data) {
            titleField.text = data.title || ""
            allDayMode = data.allDay === true
            startTimeField.text = data.start ? Qt.formatTime(data.start, "HH:mm") : ""
            endTimeField.text   = data.end   ? Qt.formatTime(data.end,   "HH:mm") : ""
            startDateField.text = data.start ? Qt.formatDate(data.start, "yyyy-MM-dd") : ""
            // All-day DTEND is exclusive; show the last day the event covers.
            endDateField.text = data.end
                ? Qt.formatDate(root._displayEnd(data.end, data.allDay === true), "yyyy-MM-dd")
                : ""
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
            allDayMode = false
            descriptionField.text = ""
            locationField.text = ""
            categoriesField.text = ""
            untilField.text = ""
            recurrenceCombo.currentIndex = 0
            const now = new Date()
            startTimeField.text = Qt.formatTime(now, "HH:mm")
            const endDate = new Date(now.getTime() + 60 * 60 * 1000)
            endTimeField.text = Qt.formatTime(endDate, "HH:mm")
            const d = Qt.formatDate(selectedDate, "yyyy-MM-dd")
            startDateField.text = d
            const lastDay = new Date(selectedDate)
            lastDay.setDate(lastDay.getDate() + (endDate.getDate() !== now.getDate() ? 1 : 0))
            endDateField.text = Qt.formatDate(lastDay, "yyyy-MM-dd")
            calendarCombo.currentIndex = 0
        }

        if (pending) root._applyPending(pending)

        root.open()
        titleField.inputItem.forceActiveFocus()
        // Reset AFTER field assignments — those fired onTextChanged and
        // would have flipped dirty=true otherwise.
        dirty = !!pending
        _timesEdited = !!pending && (pending.start !== undefined || pending.end !== undefined || pending.allDay !== undefined)
    }

    // Build a QVariantMap for CalendarBackend.addEvent / editEvent.
    // Times are merged into selectedDate. On EDITS, untouched times are
    // omitted entirely (absent key = leave as is on the backend).
    function _buildFields() {
        const recurrenceValues = ["none", "daily", "weekly", "monthly", "yearly"]

        const cats = categoriesField.text.trim().length > 0
            ? categoriesField.text.split(",").map(s => s.trim()).filter(s => s.length > 0)
            : []

        const fields = {
            calendar:    calendarCombo.currentText || "",
            title:       titleField.text.trim(),
            description: descriptionField.text.trim(),
            location:    locationField.text.trim(),
            categories:  cats,
            recurrence:  recurrenceValues[recurrenceCombo.currentIndex] || "none"
        }

        if (!isEditMode || _timesEdited) {
            fields.allDay = allDayMode
            const sd = _parseLocalDate(startDateField.text) || new Date(selectedDate)
            const ed = _parseLocalDate(endDateField.text)   || new Date(sd)
            if (allDayMode) {
                const dayStart = new Date(sd)
                dayStart.setHours(0, 0, 0, 0)
                // The field holds the LAST covered day; storage wants the
                // exclusive next one.
                const dayEnd = _storageEnd(ed)
                dayEnd.setHours(0, 0, 0, 0)
                fields.start = dayStart
                fields.end = dayEnd
            } else {
                const startParts = startTimeField.text.split(":")
                const endParts   = endTimeField.text.split(":")
                const startDt = new Date(sd)
                startDt.setHours(parseInt(startParts[0]) || 0,
                                 parseInt(startParts[1]) || 0, 0, 0)
                const endDt = new Date(ed)
                endDt.setHours(parseInt(endParts[0]) || 0,
                               parseInt(endParts[1]) || 0, 0, 0)
                fields.start = startDt
                fields.end = endDt
            }
        }

        if (recurrenceCombo.currentIndex !== 0 && _dateRe.test(untilField.text)) {
            fields.recurrenceUntil = _parseLocalDate(untilField.text)
        }
        return fields
    }

    ScrollableList {
        objectName: "eventFormScroll"
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large

        ColumnLayout {
            id: formLayout
            enabled: !root.saving && !root._completed
            Layout.fillWidth: true

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
                    id: titleFieldLabel
                    text: "Title"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                MaterialTextField {
                    id: titleField
                    errorText: root.dirty ? root._fieldErrors.title : ""
                    labelItem: titleFieldLabel
                    Layout.fillWidth: true
                    placeholderText: "Event title"
                    onTextEdited: root.dirty = true
                }
            }

            // All-day toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialText {
                    text: "All-day"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                    Layout.fillWidth: true
                }

                MaterialSwitch {
                    Accessible.name: "All-day event"
                    checked: root.allDayMode
                    onToggled: (state) => {
                        root.allDayMode = state
                        root._timesEdited = true
                        root.dirty = true
                    }
                }
            }

            // Date fields. There was NO date input at all: both start and end
            // were built from `selectedDate` (the day you happened to click)
            // plus the times. Multi-day events and events crossing midnight
            // were therefore inexpressible, and touching the time fields on an
            // existing multi-day event collapsed it to a single day.
            //
            // For all-day events the END shown is the LAST DAY, inclusive —
            // that is how a human reads "15-17 March". RFC 5545 stores the
            // exclusive next day, and _buildFields converts on save.
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        id: startDateFieldLabel
                        text: "Start date"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    MaterialTextField {
                        id: startDateField
                        errorText: root.dirty ? root._fieldErrors.startDate : ""
                        labelItem: startDateFieldLabel
                        Layout.fillWidth: true
                        placeholderText: "yyyy-MM-dd"
                        onTextEdited: root.dirty = true
                        inputItem.onTextEdited: root._timesEdited = true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        id: endDateFieldLabel
                        text: root.allDayMode ? "End date (inclusive)" : "End date"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    MaterialTextField {
                        id: endDateField
                        errorText: root.dirty ? root._fieldErrors.endDate : ""
                        labelItem: endDateFieldLabel
                        Layout.fillWidth: true
                        placeholderText: "yyyy-MM-dd"
                        onTextEdited: root.dirty = true
                        inputItem.onTextEdited: root._timesEdited = true
                    }
                }
            }

            // Time fields
            RowLayout {
                visible: !root.allDayMode
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        id: startTimeFieldLabel
                        text: "Start"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    MaterialTextField {
                        id: startTimeField
                        errorText: root.dirty ? root._fieldErrors.startTime : ""
                        labelItem: startTimeFieldLabel
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        validator: RegularExpressionValidator { regularExpression: root._timeRe }
                        onTextEdited: root.dirty = true
                        inputItem.onTextEdited: root._timesEdited = true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spacing.extraSmall

                    MaterialText {
                        id: endTimeFieldLabel
                        text: "End"
                        textStyle: "labelMedium"
                        colorRole: "onSurfaceVariant"
                    }

                    MaterialTextField {
                        id: endTimeField
                        errorText: root.dirty ? root._fieldErrors.endTime : ""
                        labelItem: endTimeFieldLabel
                        Layout.fillWidth: true
                        placeholderText: "HH:MM"
                        validator: RegularExpressionValidator { regularExpression: root._timeRe }
                        onTextEdited: root.dirty = true
                        inputItem.onTextEdited: root._timesEdited = true
                    }
                }
            }

            // Location
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    id: locationFieldLabel
                    text: "Location"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                MaterialTextField {
                    id: locationField
                    labelItem: locationFieldLabel
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
                    id: descriptionFieldLabel
                    text: "Description"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                MaterialTextArea {
                    id: descriptionField
                    labelItem: descriptionFieldLabel
                    Layout.fillWidth: true
                    placeholderText: "Add description"
                    onTextEdited: root.dirty = true
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                            root._cycleFocus(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier))
                            event.accepted = true
                        }
                    }
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
                    // Backend edits never move files between calendars;
                    // offering the choice on edit would be a silent no-op.
                    enabled: !root.isEditMode
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
                    id: untilFieldLabel
                    text: "Repeat until"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                // No inputMask here: with a mask the "empty" field contains the mask
                // literals, so the optional-until check `length > 0` was always true
                // and recurring events could never be saved without a date.
                MaterialTextField {
                    id: untilField
                    labelItem: untilFieldLabel
                    errorText: root.dirty ? root._fieldErrors.until : ""
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
                    id: categoriesFieldLabel
                    text: "Categories"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                MaterialTextField {
                    id: categoriesField
                    labelItem: categoriesFieldLabel
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
                colorRole: root.dirty ? "error" : "onSurfaceVariant"
                visible: !root._isValid
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: Tokens.spacing.small }

            MaterialText {
                objectName: "eventSaveError"
                Layout.fillWidth: true
                visible: root.saveError !== ""
                text: root.saveError
                textFormat: Text.PlainText
                textStyle: "bodySmall"
                colorRole: "error"
                wrapMode: Text.Wrap
                Accessible.role: Accessible.AlertMessage
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    visible: root.isEditMode
                    variant: "standard"
                    Accessible.name: "Delete event"
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
                    id: saveButton
                    text: root.saving ? "Saving…" : root.saveError ? "Retry" : root.isEditMode ? "Save" : "Add"
                    variant: "filled"
                    enabled: root._isValid && !root.saving && !root._completed
                    onClicked: {
                        root.saveError = ""
                        root.eventSaved(root._buildFields())
                    }
                }
            }
        }
    }

    // Discard-confirmation overlay shown when user tries to dismiss
    // a dialog that has unsaved changes.
    MaterialShape {
        id: discardConfirm
        anchors.fill: parent
        color: Qt.alpha(Theme.scrim, Tokens.state.scrimOpacity)
        visible: false
        z: 10

        MouseArea { anchors.fill: parent }  // swallow clicks

        MaterialShape {
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
