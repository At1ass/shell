import QtQuick
import Quickshell
import qs.src.core.config

Item {
    id: root
    required property var tooltip
    required property Item owner
    property bool isMenu: false
    property list<QtObject> grabWindows
    property bool hoverable: isMenu
    property bool animateSize: true
    property bool show: false
    property bool preloadBackground: root.visible

    property real targetRelativeY: owner.height / 2
    property real hangTime: isMenu ? 0 : 300

    signal close()

    readonly property alias contentItem: contentItem
    default property alias data: contentItem.data

    property Component backgroundComponent: null

    onShowChanged: {
        if (tooltip) {
            if (show) tooltip.setItem(this)
            else tooltip.removeItem(this)
        }
    }

    property bool targetVisible: false
    property real targetOpacity: 0
    opacity: root.targetOpacity * (tooltip && tooltip.scaleMul == 0 ? 0 : (tooltip ? (1.0 / tooltip.scaleMul) : 1.0))

    Behavior on targetOpacity {
        id: opacityAnimation
        SmoothedAnimation {
            velocity: 6
            duration: 250
        }
    }

    function snapOpacity(opacity: real) {
        opacityAnimation.enabled = false
        targetOpacity = opacity
        opacityAnimation.enabled = true
    }

    onTargetVisibleChanged: {
        if (targetVisible) {
            visible = true
            targetOpacity = 1
        } else {
            close()
            targetOpacity = 0
        }
    }

    onTargetOpacityChanged: {
        if (!targetVisible && targetOpacity == 0) {
            visible = false
            this.parent = null
            if (tooltip) tooltip.onHidden(this)
        }
    }

    anchors.fill: parent
    visible: false
    implicitWidth: contentItem.implicitWidth + contentItem.anchors.leftMargin + contentItem.anchors.rightMargin
    implicitHeight: contentItem.implicitHeight + contentItem.anchors.topMargin + contentItem.anchors.bottomMargin

    readonly property Item item: contentItem

    Loader {
        anchors.fill: parent
        active: root.backgroundComponent && (root.visible || root.preloadBackground)
        asynchronous: !root.visible && root.preloadBackground
        sourceComponent: backgroundComponent
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: Config.spacing.medium

        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
    }
}
