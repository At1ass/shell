pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs.src.core.config
import qs.src.ui.base

MaterialIcon {
    // Mouse interaction
    id: root
    color: !enabled ? disabledColor :
    mouseArea.pressed ? pressColor :
    mouseArea.containsMouse ? hoverColor :
    backgroundColor

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
            // Trigger ripple effect
            if (root.enableRipple) {
                ripple.width = Math.max(root.width, root.height) * 2
                ripple.height = ripple.width
                rippleAnimation.start()
            }

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
