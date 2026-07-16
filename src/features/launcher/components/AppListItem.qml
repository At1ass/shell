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

    implicitHeight: 64
    implicitWidth: parent ? parent.width : 0

    Rectangle {
        anchors.fill: parent
        radius: Tokens.shape.medium
        color: isCurrentItem ? Theme.secondaryContainer : "transparent"
        opacity: isCurrentItem ? 0.12 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.duration.short4
                easing.type: Tokens.motion.easing.standard
                easing.bezierCurve: Tokens.motion.easing.standardPoints
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
                if (modelData?.data?.isImage !== true) return ""
                // Depend on version to re-evaluate when new thumbnails arrive
                let v = ClipboardService._thumbnailVersion
                void(v)
                return ClipboardService.thumbnailFor(modelData.data.entry) || ""
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

            source: {
                let iconName = modelData?.icon || "application-x-executable"
                let path = Quickshell.iconPath(iconName, "image-missing")
                if (!path) return ""

                // Strip the fallback part (if any)
                let mainPath = path.split("?")[0]

                // Verify it is a valid source (path or URI)
                if (mainPath.startsWith("/") || mainPath.startsWith("image://")) {
                    return mainPath
                }

                // Icon not found - try the fallback
                if (path.includes("?fallback=")) {
                    let fallbackName = path.split("?fallback=")[1]
                    let fallbackPath = Quickshell.iconPath(fallbackName, "")
                    fallbackPath = fallbackPath.split("?")[0]

                    if (fallbackPath && (fallbackPath.startsWith("/") || fallbackPath.startsWith("image://"))) {
                        return fallbackPath
                    }
                }

                return ""
            }

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
                text: modelData?.text || ""
                textStyle: "titleMedium"
                colorRole: "onSurface"
                elide: Text.ElideRight
            }

            // Result Description
            MaterialText {
                Layout.fillWidth: true
                text: modelData?.description || ""
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
