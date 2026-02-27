import QtQuick
import Quickshell

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property var popoutsInstance: null
    property bool open: false
    property string name: ""
    property string screenName: ""
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0
    property int epoch: 0

    function openPopout(popoutName, targetScreenName) {
        open = true
        name = popoutName || ""
        screenName = targetScreenName || ""
        epoch++
    }

    function closePopout() {
        if (!open && name === "" && screenName === "")
            return
        open = false
        name = ""
        screenName = ""
        popoutX = 0
        popoutY = 0
        popoutWidth = 0
        popoutHeight = 0
        epoch++
    }

    function setPopoutRect(x, y, w, h, targetScreenName) {
        popoutX = x || 0
        popoutY = y || 0
        popoutWidth = w || 0
        popoutHeight = h || 0
        screenName = targetScreenName || ""
    }
}
