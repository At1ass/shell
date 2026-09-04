pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

// Compact transport row that names its source.
//
// The player it replaces hid source selection behind a click on the album art:
// no icon, no chevron, and the active player named nowhere in the card. With no
// art the trigger moved to the track title -- the old code called that a
// fallback for when "the art click target does not exist" -- and it did nothing
// at all with one player, since it was enabled only above one. The menu then
// opened on top of the art that had been clicked, and its click-outside
// dismisser sat at `z: -1`, behind the card's own content.
//
// So the source is named in the subtitle, always, and the list unfolds INSIDE
// the row rather than floating over it. An inline list cannot land outside its
// parent's bounds, which is where overlay menus lose their input.
ExpandableCard {
    id: root

    readonly property var track: MprisController.activeTrack
    readonly property bool hasPlayer: MprisController.activePlayer !== null
    readonly property bool hasChoice: MprisController.availablePlayers.length > 1

    visible: root.hasPlayer
    expandable: root.hasChoice
    showToggle: false

    // A player that goes away while its list is open must not leave the row
    // unfolded onto nothing.
    onHasChoiceChanged: if (!root.hasChoice) root.collapse()

    RowLayout {
        width: parent.width
        spacing: Tokens.spacing.small

        // Art, framed so it still reads as art when the track has none.
        Surface {
            implicitWidth: 52
            implicitHeight: 52
            radius: Tokens.shape.small
            color: Qt.alpha(Theme.onSurface, Tokens.stateLayer.hoverOpacity)
            outlined: true
            clip: true

            Image {
                anchors.fill: parent
                source: root.track?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 52
                sourceSize.height: 52
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            MaterialText {
                Layout.fillWidth: true
                text: root.track?.title ?? ""
                textStyle: "titleSmall"
                colorRole: "onSurface"
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialText {
                    text: root.track?.artist ?? ""
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 200
                    visible: text !== ""
                }

                MaterialText {
                    text: "·"
                    textStyle: "bodySmall"
                    colorRole: "onSurfaceVariant"
                    visible: (root.track?.artist ?? "") !== ""
                }

                // The source. Named whether or not it can be changed; the
                // chevron appears only when there is something to change to, so
                // the control never invites a click that does nothing.
                Surface {
                    implicitWidth: sourceRow.implicitWidth + Tokens.spacing.small
                    implicitHeight: sourceRow.implicitHeight + Tokens.spacing.extraSmall
                    radius: Tokens.shape.small
                    color: "transparent"
                    outlined: root.hasChoice

                    RowLayout {
                        id: sourceRow
                        anchors.centerIn: parent
                        spacing: 1

                        MaterialText {
                            text: MprisController.identity
                            textStyle: "labelMedium"
                            colorRole: "onSurface"
                        }
                        MaterialIcon {
                            visible: root.hasChoice
                            iconName: root.expanded ? "expand_less" : "expand_more"
                            fontSize: Tokens.iconSize.small
                            backgroundColor: "transparent"
                            colorRole: "onSurfaceVariant"
                        }
                    }

                    StateLayer {
                        target: parent
                        hovered: sourceMouse.containsMouse
                        pressed: sourceMouse.pressed
                        visible: root.hasChoice
                    }

                    MouseArea {
                        id: sourceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.hasChoice
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle()
                    }
                }

                Item { Layout.fillWidth: true }

                MonoText {
                    visible: MprisController.lengthSupported
                    text: root.formatTime(MprisController.position) + " / " + root.formatTime(MprisController.length)
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                }
            }

            ProgressIndicator {
                Layout.fillWidth: true
                Layout.topMargin: 3
                type: "linear"
                thickness: 2
                animateValue: false
                visible: MprisController.lengthSupported && MprisController.length > 0
                value: MprisController.length > 0 ? MprisController.position / MprisController.length : 0
            }
        }

        IconButton {
            iconName: "skip_previous"
            iconSize: Tokens.iconSize.medium
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: "onSurfaceVariant"
            onClicked: MprisController.previous()
        }
        IconButton {
            iconName: MprisController.isPlaying ? "pause" : "play_arrow"
            iconSize: Tokens.iconSize.large
            containerSize: Tokens.touchTarget.minimum * 0.8
            touchTargetSize: Tokens.touchTarget.minimum * 0.8
            colorRole: "onSurface"
            onClicked: MprisController.togglePlaying()
        }
        IconButton {
            iconName: "skip_next"
            iconSize: Tokens.iconSize.medium
            containerSize: Tokens.iconSize.extraLarge
            touchTargetSize: Tokens.iconSize.extraLarge
            colorRole: "onSurfaceVariant"
            onClicked: MprisController.next()
        }
    }

    // The source list, unfolded in place.
    expandedContent: ColumnLayout {
        // Not the full row width: a check mark parked at the far edge of a
        // 900px panel reads as unrelated to the two short names beside it.
        width: Math.min(root.width, 300)
        spacing: 0

        Repeater {
            model: MprisController.availablePlayers

            delegate: ListItem {
                id: playerRow
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: Tokens.touchTarget.minimum * 0.75
                radius: Tokens.shape.small
                headline: playerRow.modelData.identity || "Unknown player"
                leadingIcon: playerRow.modelData.isPlaying ? "play_circle" : "music_note"
                leadingIconColor: playerRow.modelData === MprisController.activePlayer
                                  ? Theme.primary : Theme.onSurfaceVariant
                trailingIcon: playerRow.modelData === MprisController.activePlayer ? "check" : ""
                trailingIconColor: Theme.primary
                margin: Tokens.spacing.small

                onClicked: {
                    MprisController.switchToPlayer(playerRow.index)
                    root.collapse()
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
