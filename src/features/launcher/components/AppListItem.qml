import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

Item {
    id: root

    required property var modelData  // Result object from provider (from ScriptModel)
    required property int index  // Index from ListView
    property bool isCurrentItem: false

    signal clicked()

    implicitHeight: 64
    implicitWidth: parent ? parent.width : 0

    // Для анимаций add/remove
    scale: 1
    opacity: 1

    Rectangle {
        anchors.fill: parent
        radius: Config.shape.medium
        color: isCurrentItem ? Config.colors.secondaryContainer : "transparent"
        opacity: isCurrentItem ? 0.12 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
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
        anchors.leftMargin: Config.spacing.medium
        anchors.rightMargin: Config.spacing.medium
        spacing: Config.spacing.medium

        // App Icon
        Image {
            id: appIcon
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40

            source: {
                let iconName = modelData?.icon || "application-x-executable"
                let path = Quickshell.iconPath(iconName, "image-missing")
                if (!path) return ""

                // Убираем fallback часть (если есть)
                let mainPath = path.split("?")[0]

                // Проверяем что это валидный source (путь или URI)
                if (mainPath.startsWith("/") || mainPath.startsWith("image://")) {
                    return mainPath
                }

                // Иконка не найдена - пробуем fallback
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
