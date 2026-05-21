import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers

// Material Design 3 Menu (presentational). `model` is an array of strings or objects
// { label, icon, enabled, separator }. Caller positions it inside a popup/PopupWindow.
Surface {
    id: root

    property var model: []
    property int itemWidth: 220

    signal triggered(int index)

    elevation: 3
    radius: Tokens.shape.extraSmall
    color: Theme.surfaceContainer

    implicitWidth: itemWidth
    implicitHeight: col.implicitHeight + Tokens.spacing.small * 2

    Column {
        id: col
        y: Tokens.spacing.small
        width: parent.width

        Repeater {
            model: root.model

            delegate: Item {
                id: item
                required property int index
                required property var modelData

                readonly property bool isObject: (typeof modelData === "object" && modelData !== null)
                readonly property bool isSeparator: isObject && modelData.separator === true
                readonly property bool itemEnabled: !(isObject && modelData.enabled === false)
                readonly property string itemLabel: isObject ? (modelData.label ?? "") : modelData
                readonly property string itemIcon: isObject ? (modelData.icon ?? "") : ""

                width: col.width
                height: isSeparator ? (Tokens.spacing.small * 2 + 1) : 48
                opacity: itemEnabled ? 1.0 : Tokens.state.disabledContentOpacity

                Divider {
                    visible: item.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                }

                StateLayer {
                    visible: !item.isSeparator && item.itemEnabled
                    target: item
                    layerColor: Theme.onSurface
                    hovered: itemMouse.containsMouse
                    pressed: itemMouse.pressed
                    showFocusRing: false
                }

                RowLayout {
                    visible: !item.isSeparator
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.rightMargin: Tokens.spacing.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        visible: item.itemIcon !== ""
                        iconName: item.itemIcon
                        fontSize: Tokens.iconSize.large
                        iconColor: Theme.onSurfaceVariant
                        backgroundColor: "transparent"
                    }

                    MaterialText {
                        text: item.itemLabel
                        textStyle: "labelLarge"
                        color: Theme.onSurface
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: itemMouse
                    visible: !item.isSeparator
                    anchors.fill: parent
                    enabled: !item.isSeparator && item.itemEnabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggered(item.index)
                }
            }
        }
    }
}
