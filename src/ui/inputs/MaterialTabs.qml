pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Controlled tabs: the caller owns selection. Only the selected tab is a Tab
// stop; arrows/Home/End move within the strip, Tab proceeds to the panel.
FocusScope {
    id: root
    property list<string> labels: []
    property int currentIndex: 0
    property string accessibleName: "Tabs"
    signal activated(int index)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Accessible.role: Accessible.PageTabList
    Accessible.name: root.accessibleName

    onCurrentIndexChanged: Qt.callLater(root._selectionChanged)
    onWidthChanged: Qt.callLater(root._revealSelection)
    onLabelsChanged: Qt.callLater(root._revealSelection)

    function _selectionChanged() {
        if (root.activeFocus) root._focusSelection()
        else root._revealSelection()
    }

    function _focusSelection() {
        const button = buttons.itemAt(root.currentIndex)
        if (!button) return
        button.forceActiveFocus(Qt.TabFocusReason)
        root._revealSelection()
    }

    function _revealSelection() {
        const button = buttons.itemAt(root.currentIndex)
        if (!button) return
        if (button.x < viewport.contentX) viewport.contentX = button.x
        else if (button.x + button.width > viewport.contentX + viewport.width)
            viewport.contentX = Math.max(0, button.x + button.width - viewport.width)
    }

    function _select(index) {
        if (root.labels.length === 0) return
        const next = Math.max(0, Math.min(root.labels.length - 1, index))
        const previous = buttons.itemAt(root.currentIndex)
        if (previous) previous.focus = false
        root.activated(next)
        root._focusSelection()
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (event.key === Qt.Key_Left) root._select((currentIndex + labels.length - 1) % labels.length)
        else if (event.key === Qt.Key_Right) root._select((currentIndex + 1) % labels.length)
        else if (event.key === Qt.Key_Home) root._select(0)
        else if (event.key === Qt.Key_End) root._select(labels.length - 1)
        else return
        event.accepted = true
    }

    Flickable {
        id: viewport
        anchors.fill: parent
        contentWidth: row.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: row
            spacing: Tokens.spacing.small
            Repeater {
                id: buttons
                model: root.labels
                delegate: AbstractButton {
                    id: tab
                    required property int index
                    required property string modelData
                    readonly property bool selected: root.currentIndex === tab.index
                    text: modelData
                    focusPolicy: selected || activeFocus ? Qt.StrongFocus : Qt.ClickFocus
                    hoverEnabled: true
                    leftPadding: Tokens.spacing.small
                    rightPadding: Tokens.spacing.small
                    topPadding: Tokens.spacing.extraSmall
                    bottomPadding: Tokens.spacing.extraSmall + Tokens.size.tabIndicator
                    implicitWidth: labelText.implicitWidth + leftPadding + rightPadding
                    implicitHeight: Math.max(Tokens.touchTarget.minimum,
                                             labelText.implicitHeight + topPadding + bottomPadding)
                    Accessible.role: Accessible.PageTab
                    Accessible.name: tab.text
                    Accessible.selected: tab.selected
                    onClicked: root.activated(tab.index)

                    contentItem: MaterialText {
                        id: labelText
                        text: tab.text
                        textStyle: "labelLarge"
                        colorRole: tab.selected ? "onSurface" : "onSurfaceVariant"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: Tokens.shape.small
                        color: "transparent"
                        StateLayer {
                            hovered: tab.hovered
                            pressed: tab.down
                            focused: tab.visualFocus
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: labelText.implicitWidth
                            height: Tokens.size.tabIndicator
                            color: Theme.primary
                            opacity: tab.selected ? 1 : 0
                            Behavior on opacity {
                                MotionAnimation { duration: Tokens.motion.duration.short3 }
                            }
                        }
                    }
                }
            }
        }
    }
}
