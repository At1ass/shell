import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

// Modal that asks the user whether an edit/delete operation on a
// recurring event should affect just this occurrence or the whole series.
// Used by CalendarTab when the target event is a recurring master.

Dialog {
    id: root

    dialogWidth: 700
    dialogHeight: 240

    property string intent: "edit"     // "edit" | "delete"
    property var    target: null       // event map (must contain start, uid)
    property var    pendingFields: ({})

    // mode: "this" | "all"
    signal choiceMade(string mode, string intent, var ev, var fields)
    // Cancel is not "never mind, discard everything" — the user has already
    // filled in the edit form by the time this modal appears. It carries the
    // composed fields back so the caller can hand them to the editor again.
    signal cancelled(string intent, var ev, var fields)

    function askEdit(ev, fields) {
        intent = "edit"
        target = ev
        pendingFields = fields
        open()
    }

    function askDelete(ev) {
        intent = "delete"
        target = ev
        pendingFields = ({})
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.medium

        MaterialText {
            text: root.intent === "edit" ? "Edit event" : "Delete event"
            textStyle: "headlineSmall"
            colorRole: "onSurface"
            font.weight: Font.Bold
            Layout.fillWidth: true
        }

        MaterialText {
            text: root.intent === "edit"
                ? "This is a recurring event. Apply the change to this occurrence only, to this one and everything after it, or to the whole series?"
                : "This is a recurring event. Delete this occurrence only, this one and everything after it, or the whole series?"
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialButton {
                text: "Cancel"
                variant: "text"
                onClicked: {
                    root.cancelled(root.intent, root.target, root.pendingFields)
                    root.close()
                }
            }

            Item { Layout.fillWidth: true }

            MaterialButton {
                text: "Only this"
                variant: "tonal"
                onClicked: {
                    root.choiceMade("this", root.intent, root.target, root.pendingFields)
                    root.close()
                }
            }

            MaterialButton {
                text: "This and future"
                variant: "tonal"
                onClicked: {
                    root.choiceMade("future", root.intent, root.target, root.pendingFields)
                    root.close()
                }
            }

            MaterialButton {
                text: "Whole series"
                variant: "filled"
                onClicked: {
                    root.choiceMade("all", root.intent, root.target, root.pendingFields)
                    root.close()
                }
            }
        }
    }
}
