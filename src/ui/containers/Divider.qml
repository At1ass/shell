import QtQuick
import QtQuick.Layouts
import qs.src.core.config

// Material Design 3 Divider
Rectangle {
    id: root

    property int insetStart: 0
    property int insetEnd: 0
    property bool vertical: false

    // ONLY implicit sizes. Binding `width`/`height` directly fought every
    // layout this is used in — and it is used with `Layout.fillWidth: true` in
    // the notification centre and the dashboard, where the layout assigns the
    // width and the component's own binding tried to take it back.
    //
    // Insets are expressed as margins so they survive being laid out; a plain
    // (non-layout) parent still gets the old behaviour through anchors.
    implicitWidth: vertical ? 1 : (parent ? parent.width - insetStart - insetEnd : 0)
    implicitHeight: vertical ? (parent ? parent.height : 0) : 1

    Layout.leftMargin: vertical ? 0 : insetStart
    Layout.rightMargin: vertical ? 0 : insetEnd

    // MD3 spec: outlineVariant color, no additional opacity
    color: Theme.outlineVariant
}
