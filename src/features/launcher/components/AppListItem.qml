import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

Item {
    id: root

    required property var modelData  // Result object from provider (from ScriptModel)
    required property int index  // Index from ListView
    property bool isCurrentItem: false

    signal clicked()

    // The view's transitions animate `scale` and `opacity` ON THIS ITEM, and
    // ScriptModel REUSES delegates keyed by resultId. Interrupt a transition —
    // which fast typing does, since the query changes faster than the 400 ms
    // remove — and the delegate keeps whatever partial scale it had, then comes
    // back bound to a different result still shrunk. Reported as a row stuck
    // ever smaller the faster you type. A row handed new data starts sane
    // regardless of what any half-finished transition left behind.
    onModelDataChanged: {
        scale = 1
        opacity = 1
    }

    implicitHeight: 64
    implicitWidth: parent ? parent.width : 0

    Rectangle {
        anchors.fill: parent
        radius: Tokens.shape.medium
        color: root.isCurrentItem ? Theme.secondaryContainer : "transparent"
        opacity: root.isCurrentItem ? 0.12 : 0

        Behavior on opacity {
            MotionAnimation {
                duration: Tokens.motion.duration.short4
                curve: "standard"
            }
        }
    }

    StateLayer {
        hovered: mouseArea.containsMouse
        pressed: mouseArea.pressed
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // Clipboard image thumbnail
        Image {
            id: clipboardThumb
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            visible: _thumbSource !== ""

            readonly property string _thumbSource: {
                if (root.modelData?.data?.isImage !== true) return ""
                // Depend on version to re-evaluate when new thumbnails arrive
                let v = ClipboardService._thumbnailVersion
                void(v)
                return ClipboardService.thumbnailFor(root.modelData.data.entry) || ""
            }

            source: _thumbSource ? "file://" + _thumbSource : ""
            sourceSize.width: 40
            sourceSize.height: 40
            fillMode: Image.PreserveAspectCrop
            smooth: true
            cache: false
            asynchronous: true

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Tokens.shape.small
                border.width: 1
                border.color: Qt.alpha(Theme.outline, 0.2)
            }
        }

        // App Icon (hidden when thumbnail is shown)
        Image {
            id: appIcon
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            visible: !clipboardThumb.visible

            // The ?fallback= query is resolved by Quickshell's icon image
            // provider itself — stripping it (as this code once did) threw
            // the fallback away and rendered a blank gap for unknown icons.
            source: Quickshell.iconPath(root.modelData?.icon || "application-x-executable", "image-missing")

            sourceSize.width: 40
            sourceSize.height: 40
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
            asynchronous: true
        }

        // App Info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            // Result Name
            MaterialText {
                Layout.fillWidth: true
                text: root.modelData?.text || ""
                textStyle: "titleMedium"
                colorRole: "onSurface"
                elide: Text.ElideRight
            }

            // Result Description
            MaterialText {
                Layout.fillWidth: true
                text: root.modelData?.description || ""
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
