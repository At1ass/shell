pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services

// The player, in two states that are one layout.
//
// Collapsed it is a strip: art, what is playing, where it came from, and the
// transport. Expanded the art grows, a seek bar appears, the transport walks to
// the centre and volume joins it. Nothing is swapped out -- every element that
// exists in both states is the SAME element, moved. That is why the geometry
// below is written as interpolations of one `morph` value rather than as two
// layouts: a control that teleports between states breaks the habit of reaching
// for it, and play/pause is the control this panel is reached for most.
//
// Every button is gated on the capability behind it. MPRIS support is per
// player -- Firefox exposes neither shuffle, nor repeat, nor volume; Spotify
// exposes all three -- so a fixed row of controls would be a row of buttons that
// do nothing on most sources.
//
// Source selection stays what it was: named in the subtitle whether or not it
// can be changed, with the list unfolding INSIDE the row. It used to hide behind
// a click on the album art, with the menu floating over the art it had been
// opened from and its dismisser sitting behind the card's own content. An inline
// list cannot land outside its parent's bounds, which is where overlay menus
// lose their input.
Item {
    id: root

    property bool expanded: false
    property bool sourceListOpen: false

    readonly property var track: MprisController.activeTrack
    readonly property bool hasPlayer: MprisController.activePlayer !== null
    readonly property bool hasChoice: MprisController.availablePlayers.length > 1
    // Firefox drops mpris:length from its metadata on EVERY seek and reports
    // position 0 with it, and does not put them back until its playback status
    // next changes -- measured over D-Bus, both for SetPosition and for a
    // relative Seek. The seek itself works; only the reporting goes blind.
    //
    // Read straight through, that blink deleted the seek bar the instant it was
    // used and left it gone until the user pressed pause. So the last real
    // duration is held for the current track, and the displayed position is
    // frozen rather than snapped to a zero nobody is at.
    property real _lastLength: 0
    readonly property real seekLength: MprisController.length > 0
                                       ? MprisController.length : root._lastLength
    readonly property bool _lengthBlink: root._lastLength > 0 && !MprisController.lengthSupported
    readonly property bool hasSeekBar: root.seekLength > 0

    Connections {
        target: MprisController
        function onLengthChanged() {
            if (MprisController.length > 0)
                root._lastLength = MprisController.length
        }
        function onTrackChanged() {
            root._lastLength = 0
        }
    }

    visible: root.hasPlayer

    // A player that goes away while its list is open must not leave the row
    // showing a list of one.
    onHasChoiceChanged: if (!root.hasChoice) root.sourceListOpen = false
    onExpandedChanged: {
        root.morph = root.expanded ? 1 : 0
        if (!root.expanded)
            root.sourceListOpen = false
    }

    // The single parameter every position below is derived from. Animating this
    // rather than the individual geometries is what keeps them in step.
    property real morph: 0
    Behavior on morph {
        MotionAnimation {
            duration: Tokens.motion.duration.medium4
            curve: "emphasized"
        }
    }

    // A change handler alone leaves the morph at 0 for a row BUILT expanded --
    // which a retained dashboard does every time it is reopened.
    Component.onCompleted: root.morph = root.expanded ? 1 : 0
    function _l(a, b) { return a + (b - a) * root.morph }

    // ---- geometry ----------------------------------------------------------
    readonly property int artSmall: Tokens.iconSize.extraLarge
    readonly property int artLarge: root.artSmall * 3

    // The strip runs to the panel's edges, so it has to supply the panel's
    // gutter itself -- and the SAME one, or the art starts on a different
    // vertical line from every toggle above it. It was `small` against a
    // `large` panel, which is why the player looked pasted on.
    readonly property int gutter: Tokens.spacing.large
    readonly property int padding: Tokens.spacing.medium

    readonly property int rowHeight: Math.max(root.artSmall, labels.implicitHeight,
                                              transport.implicitHeight)
                                     + root.padding * 2
    readonly property int openHeight: root.padding + root.artLarge
                                      + Tokens.spacing.medium + transport.implicitHeight
                                      + root.padding
                                      + (root.sourceListOpen
                                         ? sourceList.implicitHeight + Tokens.spacing.medium : 0)

    // Reported from `expanded`, not from `morph`: the window has to be the final
    // size BEFORE the content walks into it, or the clip below eats whatever is
    // still on its way.
    readonly property int expandedDelta: root.expanded
                                         ? Math.max(0, root.openHeight - root.rowHeight) : 0

    implicitHeight: root.rowHeight + root.expandedDelta
    clip: true

    // The strip reads as its own surface without a frame around it: one step of
    // value, and a hairline where it actually meets the content above.
    Surface {
        anchors.fill: parent
        elevation: 1
        radius: Tokens.shape.small
        color: Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity * 0.7)
    }

    Divider {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // ---- album art ---------------------------------------------------------
    Surface {
        id: art
        x: root.gutter
        y: root._l((root.rowHeight - root.artSmall) / 2, root.padding)
        width: root._l(root.artSmall, root.artLarge)
        height: width
        radius: Tokens.shape.small
        color: Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
        clip: true

        Image {
            anchors.fill: parent
            source: root.track?.artUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.artLarge
            sourceSize.height: root.artLarge
            visible: status === Image.Ready
            // Synchronous on purpose: the shell's icon provider crashed the
            // QQuickPixmapReader thread when loaded asynchronously, and the
            // check.sh async-icon-provider rule exists because of it.
            asynchronous: false
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: (root.track?.artUrl ?? "") === ""
            iconName: "music_note"
            fontSize: Tokens.iconSize.medium
            backgroundColor: "transparent"
            colorRole: "onSurfaceVariant"
        }
    }

    // ---- what is playing, and where from -----------------------------------
    Column {
        id: labels
        x: art.x + art.width + Tokens.spacing.medium
        y: root._l((root.rowHeight - labels.implicitHeight) / 2, root.padding)
        width: root.width - x - transportReserve.width - root.gutter
        spacing: Tokens.spacing.extraSmall

        MaterialText {
            width: parent.width
            text: root.track?.title ?? ""
            textStyle: "titleSmall"
            colorRole: "onSurface"
            elide: Text.ElideRight
        }

        // A layout, not a Row: the artist has to yield space to the source
        // rather than take its natural width and push it off the end. As a
        // plain Row it did exactly that -- the source name was laid out past
        // the column's edge and clipped away, so the player named no source at
        // all until the title happened to be short.
        RowLayout {
            width: parent.width
            spacing: Tokens.spacing.extraSmall

            MaterialText {
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                text: root.track?.artist ?? ""
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
                visible: text !== ""
            }

            MaterialText {
                text: "·"
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                visible: (root.track?.artist ?? "") !== ""
            }

            // The source. Named always; the chevron only when there is somewhere
            // else to go, so the control never invites a click that does nothing.
            // An Item around the Row, because the click target has to fill it.
            // As a direct child of the Row that MouseArea took `anchors.fill`,
            // which Qt refuses inside a positioner -- and it does not refuse
            // just the anchor, it stops positioning the Row at all. The chevron
            // was drawn underneath the source name for exactly that reason.
            Item {
                implicitWidth: sourceRow.implicitWidth
                implicitHeight: sourceRow.implicitHeight

                Row {
                    id: sourceRow
                    anchors.centerIn: parent
                    spacing: 1

                    MaterialText {
                        text: MprisController.identity
                        textStyle: "labelMedium"
                        colorRole: "onSurface"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MaterialIcon {
                        visible: root.hasChoice
                        iconName: root.sourceListOpen ? "expand_less" : "expand_more"
                        fontSize: Tokens.iconSize.small
                        backgroundColor: "transparent"
                        colorRole: "onSurfaceVariant"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Tokens.spacing.extraSmall
                    hoverEnabled: true
                    enabled: root.hasChoice
                    cursorShape: Qt.PointingHandCursor
                    // Picking a source needs the room the list takes, so it
                    // opens the player as well rather than refusing until the
                    // user has expanded it themselves.
                    onClicked: {
                        root.sourceListOpen = !root.sourceListOpen
                        if (root.sourceListOpen)
                            root.expanded = true
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }

    // ---- seek bar: expanded only -------------------------------------------
    Column {
        id: seekBlock
        x: labels.x
        // Bottom-aligned with the art, but never above the labels: the art is
        // still growing at mid-morph, and pinning to it alone drew the seek bar
        // straight through the artist line for the length of the animation.
        y: Math.max(art.y + art.height - implicitHeight,
                    labels.y + labels.implicitHeight + Tokens.spacing.extraSmall)
        width: root.width - x - root.gutter
        spacing: Tokens.spacing.extraSmall
        // Ramps in over the back half of the morph, so it does not appear while
        // there is still no room for it.
        opacity: Math.max(0, (root.morph - 0.4) / 0.6)
        visible: root.hasSeekBar && opacity > 0.01

        // A slider, not a progress bar. It showed where you were and gave no
        // way to go anywhere else -- the one thing an expanded player is opened
        // for. Disabled when the source cannot seek (some streams cannot), so
        // the control never accepts a drag it will not honour.
        MaterialSlider {
            id: seek
            width: parent.width
            enabled: MprisController.canSeek && MprisController.positionSupported
            from: 0
            to: Math.max(1, root.seekLength)
            stepSize: 1
            accentRole: "primary"
            onMoved: MprisController.setPosition(value)

            // Through a Binding, not `value:` directly: dragging writes `value`
            // imperatively, and a plain binding would be severed by the first
            // drag and never track the track again.
            Binding {
                target: seek
                property: "value"
                value: MprisController.position
                // Not while dragging, and not while the source is blind: both
                // would otherwise write a value the user is not at.
                when: !seek.pressed && !root._lengthBlink
                restoreMode: Binding.RestoreNone
            }
        }

        Item {
            width: parent.width
            implicitHeight: elapsed.implicitHeight

            MonoText {
                id: elapsed
                anchors.left: parent.left
                // The slider's value, not the controller's position: while the
                // source is blind those differ, and the number under the bar
                // has to agree with the bar.
                text: root.formatTime(seek.value)
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
            }
            MonoText {
                anchors.right: parent.right
                text: root.formatTime(root.seekLength)
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
            }
        }
    }

    // ---- elapsed readout: collapsed only ------------------------------------
    MonoText {
        id: collapsedTime
        anchors.verticalCenter: undefined
        x: transport.x - width - Tokens.spacing.small
        y: transport.y + (transport.height - height) / 2
        // The same held duration the seek bar uses: this readout vanished on
        // every seek too, for the same blink.
        visible: root.hasSeekBar && opacity > 0.01
        opacity: Math.max(0, 1 - root.morph * 3)
        text: root.formatTime(root._lengthBlink ? seek.value : MprisController.position)
              + " / " + root.formatTime(root.seekLength)
        textStyle: "labelSmall"
        colorRole: "onSurfaceVariant"
    }

    // Width the transport needs on the right while collapsed, so `labels` can
    // stop before it instead of running underneath.
    Item {
        id: transportReserve
        width: transport.implicitWidth + collapsedTime.width + Tokens.spacing.medium
               + chevron.width
        height: 0
    }

    // ---- transport ----------------------------------------------------------
    Row {
        id: transport
        spacing: root._l(Tokens.spacing.extraSmall, Tokens.spacing.medium)
        x: root._l(root.width - implicitWidth - chevron.width - root.gutter,
                   (root.width - implicitWidth) / 2)
        y: root._l((root.rowHeight - implicitHeight) / 2,
                   art.y + art.height + Tokens.spacing.medium)

        IconButton {
            iconName: "shuffle"
            visible: MprisController.shuffleSupported
            iconSize: Tokens.iconSize.small
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: MprisController.shuffle ? "primary" : "onSurfaceVariant"
            onClicked: MprisController.toggleShuffle()
            anchors.verticalCenter: parent.verticalCenter
        }
        IconButton {
            iconName: "skip_previous"
            // Dimmed, not hidden. Prev/next are the core transport and their
            // absence is worth showing -- Firefox reports CanGoPrevious false
            // for a stream, Spotify reports true, and a row that changed width
            // as the source changed would move the play button under the
            // pointer. Shuffle and repeat DO hide: they are secondary, absent
            // on most sources, and nothing else depends on where they sit.
            enabled: MprisController.canGoPrevious
            iconSize: Tokens.iconSize.medium
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: "onSurfaceVariant"
            onClicked: MprisController.previous()
            anchors.verticalCenter: parent.verticalCenter
        }
        // The one solid accent in the panel, and the reason it reads: a single
        // filled shape among outlines and text.
        IconButton {
            variant: "filled"
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            enabled: MprisController.canTogglePlaying
            iconSize: Tokens.iconSize.medium
            containerSize: root._l(Tokens.iconSize.extraLarge, Tokens.touchTarget.minimum)
            touchTargetSize: containerSize
            onClicked: MprisController.togglePlaying()
            anchors.verticalCenter: parent.verticalCenter
        }
        IconButton {
            iconName: "skip_next"
            enabled: MprisController.canGoNext
            iconSize: Tokens.iconSize.medium
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: "onSurfaceVariant"
            onClicked: MprisController.next()
            anchors.verticalCenter: parent.verticalCenter
        }
        IconButton {
            iconName: MprisController.loopingTrack ? "repeat_one" : "repeat"
            visible: MprisController.loopSupported
            iconSize: Tokens.iconSize.small
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: MprisController.loopEnabled ? "primary" : "onSurfaceVariant"
            onClicked: MprisController.toggleLoop()
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ---- volume: expanded only ----------------------------------------------
    Row {
        id: volumeRow
        visible: MprisController.volumeSupported && opacity > 0.01
        opacity: Math.max(0, (root.morph - 0.5) / 0.5)
        spacing: Tokens.spacing.small
        anchors.right: parent.right
        anchors.rightMargin: root.gutter
        y: transport.y + (transport.height - height) / 2

        MaterialIcon {
            iconName: "volume_up"
            fontSize: Tokens.iconSize.small
            backgroundColor: "transparent"
            colorRole: "onSurfaceVariant"
            anchors.verticalCenter: parent.verticalCenter
        }
        MaterialSlider {
            width: root.artLarge - Tokens.spacing.medium
            accentRole: "onSurfaceVariant"
            from: 0
            to: 1
            value: MprisController.volume
            onMoved: MprisController.setVolume(value)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ---- the fold control ----------------------------------------------------
    IconButton {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: root.gutter - Tokens.spacing.small
        y: (root.rowHeight - height) / 2
        iconName: root.expanded ? "expand_more" : "expand_less"
        iconSize: Tokens.iconSize.small
        containerSize: Tokens.iconSize.extraLarge
        touchTargetSize: Tokens.iconSize.extraLarge
        colorRole: "onSurfaceVariant"
        onClicked: root.expanded = !root.expanded
    }

    // ---- source list, unfolded in place --------------------------------------
    Column {
        id: sourceList
        x: labels.x
        y: transport.y + transport.height + Tokens.spacing.medium
        // Not the full row width: a check mark parked at the far edge of a 900px
        // panel reads as unrelated to the two short names beside it.
        width: Math.min(root.width - x - root.gutter, root.artLarge * 3)
        visible: root.sourceListOpen && root.morph > 0.5
        spacing: 0

        Repeater {
            model: MprisController.availablePlayers

            // Two lines per source, not one: which player, and what is in it.
            // A list of bare application names cannot be chosen from without
            // remembering what each one was left playing -- and the check mark
            // it used to carry restated the selection the fill already shows.
            delegate: Surface {
                id: playerRow
                required property var modelData
                required property int index

                readonly property bool current: playerRow.modelData === MprisController.activePlayer

                width: sourceList.width
                height: rowLabels.implicitHeight + Tokens.spacing.small * 2
                radius: Tokens.shape.small
                color: playerRow.current
                       ? Qt.alpha(Theme.onSurface, Tokens.stateLayer.draggedOpacity)
                       : (sourceMouse.containsMouse
                          ? Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
                          : "transparent")

                MaterialIndicator {
                    id: rowDot
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    size: "extraSmall"
                    colorRole: playerRow.current ? "primary" : "outline"
                }

                Column {
                    id: rowLabels
                    anchors.left: rowDot.right
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    MaterialText {
                        width: parent.width
                        text: playerRow.modelData.identity || "Unknown player"
                        textStyle: "labelLarge"
                        colorRole: playerRow.current ? "onSurface" : "onSurfaceVariant"
                        elide: Text.ElideRight
                    }
                    MaterialText {
                        width: parent.width
                        text: playerRow.modelData.trackTitle || ""
                        visible: text !== ""
                        textStyle: "labelSmall"
                        colorRole: "onSurfaceVariant"
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: sourceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        MprisController.switchToPlayer(playerRow.index)
                        root.sourceListOpen = false
                    }
                }
            }
        }
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"
        const hours = Math.floor(seconds / 3600)
        const mins = Math.floor((seconds % 3600) / 60)
        const secs = Math.floor(seconds % 60)
        const pad = (n) => (n < 10 ? "0" : "") + n
        return hours > 0 ? hours + ":" + pad(mins) + ":" + pad(secs) : mins + ":" + pad(secs)
    }
}
