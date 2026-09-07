import QtQuick
import QtQuick.Controls
import qs.src.core.config
import qs.src.ui.base

// Material Design 3 Slider (2024 spec)
Slider {
    id: control

    stepSize: 0.01
    from: 0.0
    to: 1.0

    // Reachable by Tab. QtQuick.Controls already implements arrow-key stepping
    // and tracks `visualFocus`; the policy to let focus arrive was missing, so
    // neither could ever engage.
    focusPolicy: Qt.StrongFocus

    // The cross-axis size is a HIT TARGET, and MD3's 48 is sized for a
    // fingertip. The compact pack already decided a pointer needs 36 (see
    // Tokens.touchTarget), and 48 around a 4px bar left a seek control
    // reserving a third of the space an expanded player has.
    readonly property int _crossSize: _quiet ? Tokens.touchTarget.minimum : 48
    implicitWidth: orientation === Qt.Horizontal ? 200 : _crossSize
    implicitHeight: orientation === Qt.Horizontal ? _crossSize : 200

    // Colour. Role form preferred, raw colour as the escape hatch -- the shape
    // MaterialIcon and IconButton already use.
    //
    // These exist because the three accent surfaces below were hardcoded to
    // Theme.primary, which made a slider the loudest object in any panel it sat
    // in and left a caller no way to quiet it down.
    property string accentRole: "primary"
    property color accentColor: accentRole !== "" ? (Theme[accentRole] ?? Theme.primary) : Theme.primary
    property string trackRole: "surfaceContainerHighest"
    property color trackColor: trackRole !== "" ? (Theme[trackRole] ?? Theme.surfaceContainerHighest) : Theme.surfaceContainerHighest

    // The compact form is a bar and a marker: a thin track, a fill, and a
    // straight handle that says where you are. MD3's shape -- a thick bare bar
    // with a pill handle -- reads as a progress indicator once the pack has
    // flattened the corners off everything around it.
    //
    // It used to be neither: a 10px track with its own outline, a gap on both
    // sides of the handle, and a dot parked at the far end. Three devices
    // saying the same thing, and the outline made a level control look like an
    // input field.
    // Asked directly rather than inferred from whether surfaces are outlined:
    // see Tokens.compactControls for what inferring it cost.
    readonly property bool _quiet: Tokens.compactControls

    property real trackHeight: _quiet ? 4 : 24
    property real thumbWidth: _quiet ? 2 : 4
    property real thumbHeight: _quiet ? 14 : 48
    property real thumbTrackGap: _quiet ? 3 : 6
    property real trackCornerSize: _quiet ? trackHeight / 2 : 8
    property real trackInsideCornerSize: _quiet ? trackHeight / 2 : 2
    // An empty track is legible on its own at this height; the outline it used
    // to carry only made it look like a field to type in.
    property bool outlinedTrack: false
    // The dot at the end of the track is MD3's, and it restates the track's own
    // end. On a 4px bar it reads as dirt.
    property bool showStopIndicator: !_quiet
    property real stopIndicatorSize: 6

    background: Item {
        x: control.orientation === Qt.Horizontal
           ? control.leftPadding
           : control.leftPadding + control.availableWidth / 2 - control.trackHeight / 2
        y: control.orientation === Qt.Horizontal
           ? control.topPadding + control.availableHeight / 2 - control.trackHeight / 2
           : control.topPadding
        width: control.orientation === Qt.Horizontal ? control.availableWidth : control.trackHeight
        height: control.orientation === Qt.Horizontal ? control.trackHeight : control.availableHeight

        // Inactive track (right/top of handle with gap)
        Rectangle {
            x: control.orientation === Qt.Horizontal
               ? Math.min(control.visualPosition * parent.width + control.thumbWidth / 2 + control.thumbTrackGap, parent.width)
               : 0
            y: 0
            width: control.orientation === Qt.Horizontal
                   ? Math.max(0, parent.width - x)
                   : parent.width
            height: control.orientation === Qt.Horizontal
                    ? parent.height
                    : Math.max(0, control.visualPosition * parent.height - control.thumbWidth / 2 - control.thumbTrackGap)
            radius: control.trackInsideCornerSize
            color: control.trackColor
            border.width: control.outlinedTrack ? Math.max(1, Tokens.border.width) : 0
            border.color: control.outlinedTrack
                          ? Qt.alpha(Theme.onSurface, Tokens.border.restAlpha) : "transparent"


            // Stop indicator (dot at the end of the track)
            Rectangle {
                anchors {
                    right: control.orientation === Qt.Horizontal ? parent.right : undefined
                    horizontalCenter: control.orientation === Qt.Horizontal ? undefined : parent.horizontalCenter
                    verticalCenter: control.orientation === Qt.Horizontal ? parent.verticalCenter : undefined
                    top: control.orientation === Qt.Horizontal ? undefined : parent.top
                    topMargin: control.orientation === Qt.Horizontal ? 0 : control.stopIndicatorSize / 2
                    rightMargin: control.orientation === Qt.Horizontal ? control.stopIndicatorSize / 2 : 0
                }
                width: control.stopIndicatorSize
                height: control.stopIndicatorSize
                radius: control.stopIndicatorSize / 2
                color: Theme.onSurfaceVariant
                visible: control.showStopIndicator
                         && (control.orientation === Qt.Horizontal
                             ? control.visualPosition < 0.99
                             : 1.0 - control.visualPosition < 0.99)

            }
        }

        // Active track (left/bottom of handle with gap)
        Rectangle {
            x: 0
            y: control.orientation === Qt.Horizontal
               ? 0
               : Math.min(control.visualPosition * parent.height + control.thumbWidth / 2 + control.thumbTrackGap, parent.height)
            width: control.orientation === Qt.Horizontal
                   ? Math.max(0, control.visualPosition * parent.width - control.thumbWidth / 2 - control.thumbTrackGap)
                   : parent.width
            height: control.orientation === Qt.Horizontal
                    ? parent.height
                    : Math.max(0, parent.height - y)
            radius: control.trackInsideCornerSize
            color: control.enabled ? control.accentColor : Theme.onSurface
            opacity: control.enabled ? 1.0 : Tokens.state.disabledContentOpacity

            Behavior on color {
                ColorAnimation { duration: Tokens.motion.duration.short4 }
            }
        }
    }

    handle: Item {
        x: control.orientation === Qt.Horizontal
           ? control.leftPadding + control.visualPosition * (control.availableWidth - width)
           : control.leftPadding + control.availableWidth / 2 - width / 2
        y: control.orientation === Qt.Horizontal
           ? control.topPadding + control.availableHeight / 2 - height / 2
           : control.topPadding + control.visualPosition * (control.availableHeight - height)
        implicitWidth: control.orientation === Qt.Horizontal ? control.thumbWidth : control.thumbHeight
        implicitHeight: control.orientation === Qt.Horizontal ? control.thumbHeight : control.thumbWidth

        // State layer (hover/pressed/keyboard focus)
        Rectangle {
            anchors.centerIn: parent
            width: (control.pressed || control.hovered || control.visualFocus) ? 44 : 0
            height: width
            radius: width / 2
            color: control.accentColor
            opacity: control.pressed ? Tokens.stateLayer.pressedOpacity
                     : (control.hovered || control.visualFocus) ? Tokens.stateLayer.hoverOpacity : 0
            visible: control.enabled

            Behavior on width {
                MotionAnimation {
                    duration: Tokens.motion.duration.short4
                    curve: "emphasized"
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }

        // Handle (thumb)
        Rectangle {
            anchors.centerIn: parent
            width: control.orientation === Qt.Horizontal ? control.thumbWidth : control.thumbHeight
            height: control.orientation === Qt.Horizontal ? control.thumbHeight : control.thumbWidth
            radius: control.orientation === Qt.Horizontal ? control.thumbWidth / 2 : control.thumbHeight / 2
            color: control.enabled ? control.accentColor : Theme.onSurface
            opacity: control.enabled ? 1.0 : 0.38

            // M3 elevation via subtle border
            border.width: 0.5
            border.color: Qt.alpha(Theme.shadow, 0.1)

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.duration.short4
                }
            }
        }
    }
}
