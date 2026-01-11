import QtQuick
import Quickshell

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property bool open: false
    property string name: ""
    property string screenName: ""
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
        epoch++
    }
}
