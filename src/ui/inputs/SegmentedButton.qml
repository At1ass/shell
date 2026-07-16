import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.feedback

// Material Design 3 Segmented Button (single-select).
// `model` is an array of strings or objects { label, icon }.
Item {
    id: root

    property var model: []
    property int currentIndex: 0

    signal selected(int index)

    implicitHeight: 40
    implicitWidth: row.implicitWidth

    function _label(it) { return (typeof it === "object" && it !== null) ? (it.label ?? "") : it }
    function _icon(it)  { return (typeof it === "object" && it !== null) ? (it.icon ?? "") : "" }

    Rectangle {
        anchors.fill: parent
        radius: root.height / 2
        color: "transparent"
        border.width: 1
        border.color: Theme.outline

        Row {
            id: row
            anchors.fill: parent

            Repeater {
                model: root.model

                delegate: Item {
                    id: seg
                    required property int index
                    required property var modelData

                    height: row.height
                    width: Math.max(72, segContent.implicitWidth + Tokens.spacing.large * 2)

                    readonly property bool isSelected: root.currentIndex === index
                    readonly property bool isFirst: index === 0
                    readonly property bool isLast: index === (root.model.length - 1)
                    readonly property color contentColor: isSelected ? Theme.onSecondaryContainer : Theme.onSurface

                    // Selected fill (pill-matched corners on the ends)
                    Rectangle {
                        anchors.fill: parent
                        color: seg.isSelected ? Theme.secondaryContainer : "transparent"
                        topLeftRadius: seg.isFirst ? root.height / 2 : 0
                        bottomLeftRadius: seg.isFirst ? root.height / 2 : 0
                        topRightRadius: seg.isLast ? root.height / 2 : 0
                        bottomRightRadius: seg.isLast ? root.height / 2 : 0

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.motion.duration.short3
                                easing.type: Tokens.motion.easing.standard
                                easing.bezierCurve: Tokens.motion.easing.standardPoints
                            }
                        }
                    }

                    // Left divider (hidden next to a selected segment)
                    Rectangle {
                        visible: seg.index > 0 && !seg.isSelected && root.currentIndex !== seg.index - 1
                        width: 1
                        height: parent.height
                        color: Theme.outline
                    }

                    StateLayer {
                        target: seg
                        layerColor: seg.contentColor
                        hovered: segMouse.containsMouse
                        pressed: segMouse.pressed
                        showFocusRing: false
                    }

                    RowLayout {
                        id: segContent
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            visible: seg.isSelected || root._icon(seg.modelData) !== ""
                            iconName: seg.isSelected ? "check" : root._icon(seg.modelData)
                            fontSize: Tokens.iconSize.small
                            iconColor: seg.contentColor
                            backgroundColor: "transparent"
                        }

                        MaterialText {
                            text: root._label(seg.modelData)
                            textStyle: "labelLarge"
                            color: seg.contentColor
                        }
                    }

                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = seg.index
                            root.selected(seg.index)
                        }
                    }
                }
            }
        }
    }
}
