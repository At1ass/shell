pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Single selection with equal columns; narrow hosts wrap whole segments.
FocusScope {
    id: root
    property var model: []
    property int currentIndex: 0
    property bool controlled: false
    signal selected(int index)
    opacity: enabled ? 1 : Tokens.state.disabledContentOpacity
    Accessible.role: Accessible.Grouping

    function _label(item) { return typeof item === "object" && item !== null ? (item.label ?? "") : item }
    function _icon(item) { return typeof item === "object" && item !== null ? (item.icon ?? "") : "" }
    FontMetrics {
        id: metrics
        font.family: Tokens.typography.fontFamily
        font.pixelSize: Tokens.typography.labelLarge.size
        font.weight: Tokens.typography.labelLarge.weight
        font.letterSpacing: Tokens.typography.labelLarge.letterSpacing
    }
    readonly property real segmentWidth: {
        let result = Tokens.size.buttonMinimumWidth
        for (const item of root.model)
            result = Math.max(result, metrics.advanceWidth(String(root._label(item)))
                              + Tokens.spacing.medium * 2 + Tokens.iconSize.small + Tokens.spacing.small)
        return Math.ceil(result)
    }
    implicitWidth: root.segmentWidth * model.length + Tokens.size.outline * Math.max(0, model.length - 1)
    implicitHeight: layout.implicitHeight

    function _focusSelection() {
        const button = buttons.itemAt(root.currentIndex)
        if (button) button.forceActiveFocus(Qt.TabFocusReason)
    }
    function _select(index) {
        if (!root.enabled || !root.visible || index < 0 || index >= root.model.length) return
        if (!root.controlled) root.currentIndex = index
        root.selected(index)
    }
    onCurrentIndexChanged: if (activeFocus) Qt.callLater(root._focusSelection)
    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier) || !root.model.length) return
        let index = root.currentIndex
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) index = (index + root.model.length - 1) % root.model.length
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) index = (index + 1) % root.model.length
        else if (event.key === Qt.Key_Home) index = 0
        else if (event.key === Qt.Key_End) index = root.model.length - 1
        else return
        root._select(index)
        root._focusSelection()
        event.accepted = true
    }

    GridLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        columns: Math.max(1, Math.min(root.model.length, Math.floor((root.width + columnSpacing) / (root.segmentWidth + columnSpacing))))
        columnSpacing: Tokens.size.outline
        rowSpacing: Tokens.size.outline
        uniformCellWidths: true
        Repeater {
            id: buttons
            model: root.model
            delegate: AbstractButton {
                id: segment
                required property int index
                required property var modelData
                readonly property bool selected: root.currentIndex === index
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: String(root._label(modelData))
                focusPolicy: selected || activeFocus ? Qt.StrongFocus : Qt.ClickFocus
                hoverEnabled: true
                leftPadding: Tokens.spacing.medium
                rightPadding: Tokens.spacing.medium
                topPadding: Tokens.spacing.extraSmall
                bottomPadding: Tokens.spacing.extraSmall
                implicitWidth: root.segmentWidth
                implicitHeight: Math.max(Tokens.touchTarget.minimum, contentItem.implicitHeight + topPadding + bottomPadding)
                Accessible.role: Accessible.RadioButton
                Accessible.name: text
                Accessible.checked: selected
                Accessible.onPressAction: if (segment.enabled && segment.visible) segment.click()
                onClicked: root._select(index)
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) segment.click(); event.accepted = true }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat) segment.click(); event.accepted = true }
                contentItem: RowLayout {
                    spacing: Tokens.spacing.small
                    MaterialIcon {
                        iconName: segment.selected ? "check" : root._icon(segment.modelData)
                        // Reserve the marker so selection never changes geometry.
                        opacity: segment.selected || root._icon(segment.modelData) !== "" ? 1 : 0
                        fontSize: Tokens.iconSize.small
                        iconColor: segment.selected ? Theme.onSecondaryContainer : Theme.onSurface
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: segment.text
                        textFormat: Text.PlainText
                        textStyle: "labelLarge"
                        wrapMode: Text.Wrap
                        colorRole: segment.selected ? "onSecondaryContainer" : "onSurface"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                background: Rectangle {
                    radius: Tokens.shape.small
                    color: segment.selected ? Theme.secondaryContainer : "transparent"
                    border.width: Tokens.size.outline
                    border.color: Theme.outline
                    StateLayer {
                        hovered: segment.hovered
                        pressed: segment.down
                        focused: segment.visualFocus
                        layerColor: segment.selected ? Theme.onSecondaryContainer : Theme.onSurface
                    }
                }
            }
        }
    }
}
