pragma ComponentBehavior: Bound

import QtQuick

// Optional native details keep status usable until the plugin package is
// upgraded. No address-family assumptions or copied connection state here.
QtObject {
    id: root
    property string interfaceName: ""
    function value(name, fallback) { return infoLoader.item ? (infoLoader.item[name] ?? fallback) : fallback }
    readonly property bool ready: value("ready", false)
    readonly property list<string> ipv4Addresses: value("ipv4Addresses", [])
    readonly property list<string> ipv6Addresses: value("ipv6Addresses", [])
    readonly property string ipv4Gateway: value("ipv4Gateway", "")
    readonly property string ipv6Gateway: value("ipv6Gateway", "")
    function invoke(name) { if (infoLoader.item && typeof infoLoader.item[name] === "function") infoLoader.item[name]() }
    function refresh() { invoke("refresh") }
    property Loader _loader: Loader {
        id: infoLoader
        active: root.interfaceName !== ""
        source: active ? "connectivity/NativeNetworkInfo.qml" : ""
    }
    property Binding _interface: Binding {
        target: infoLoader.item
        property: "interfaceName"
        value: root.interfaceName
        when: infoLoader.item !== null
    }
}
