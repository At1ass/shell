pragma ComponentBehavior: Bound

import QtQuick
import qs.src.core.config
import qs.src.ui.base

MaterialIcon {
    // Mouse interaction
    id: root
    color: !enabled ? disabledColor : backgroundColor

    signal clicked(MouseEvent mouse)
    signal pressed()
    signal released()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: function(mouse) {
            root.clicked(mouse)
        }

        onPressed: {
            root.pressed()
        }

        onReleased: {
            root.released()
        }
    }
}
