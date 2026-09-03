pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers

// A recording is running -- say so, permanently and out of the way.
//
// This is its own overlay layer rather than a bar widget because the bar
// auto-hides, and recording is exactly the situation where it is hidden: a
// fullscreen game or video. An indicator that disappears with the bar would be
// missing whenever it matters most.
Scope {
    id: root

    // An overlay layer IS composited into the captured frame -- verified by
    // recording a monitor with a test layer on it and reading the pixels back.
    // So the indicator goes on a monitor that is NOT being captured whenever
    // one exists. When the compositor did not name a captured monitor (a window
    // capture, which does not include layers, or a KMS capture it cannot see)
    // every screen counts as free.
    readonly property var freeScreens: Quickshell.screens.filter(
        s => RecorderService.capturedMonitor === "" || s.name !== RecorderService.capturedMonitor)

    readonly property bool onCapturedScreen: root.freeScreens.length === 0
    readonly property var targetScreen: root.freeScreens.length > 0
        ? root.freeScreens[0]
        : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    // With every monitor captured the choice is between an indicator burned
    // into the recording and no indicator at all. Showing it is the default:
    // a mark in the corner of the video costs less than an unnoticed recording.
    readonly property bool shown: RecorderService.active
        && root.targetScreen !== null
        && (!root.onCapturedScreen || AppConfig.recorderIndicatorOnCaptured)

    readonly property bool atTop: AppConfig.recorderIndicatorPosition.startsWith("top")
    readonly property bool atLeft: AppConfig.recorderIndicatorPosition.endsWith("Left")

    LazyLoader {
        active: root.targetScreen !== null

        PanelWindow {
            id: indicatorWindow

            screen: root.targetScreen
            visible: root.shown || pill.opacity > 0.01
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:recorder"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // PanelWindow's `margins` group is not described in Quickshell's
            // qmltypes, so qmllint reports it unknown; OsdSurface and the
            // notification popups carry the same pair of warnings unsuppressed.
            // qmllint disable unqualified
            // qmllint disable unresolved-type
            anchors {
                top: root.atTop
                bottom: !root.atTop
                left: root.atLeft
                right: !root.atLeft
            }
            margins {
                top: root.atTop ? AppConfig.recorderIndicatorMargin : 0
                bottom: root.atTop ? 0 : AppConfig.recorderIndicatorMargin
                left: root.atLeft ? AppConfig.recorderIndicatorMargin : 0
                right: root.atLeft ? 0 : AppConfig.recorderIndicatorMargin
            }

            // qmllint enable unresolved-type
            // qmllint enable unqualified

            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight

            // Without controls the indicator is pure display, so it takes no
            // pointer input at all -- clicks pass through to whatever is behind
            // it, which over a fullscreen game is the difference between a hint
            // and an obstacle.
            mask: AppConfig.recorderIndicatorControls ? null : emptyRegion

            Region {
                id: emptyRegion
                item: null
            }

            Item {
                id: pill
                anchors.centerIn: parent
                width: card.implicitWidth
                height: card.implicitHeight

                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.9

                Behavior on opacity {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium2
                        curve: "emphasized"
                    }
                }

                Behavior on scale {
                    MotionAnimation {
                        duration: Tokens.motion.duration.medium2
                        curve: "emphasized"
                    }
                }

                MaterialCard {
                    id: card

                    // Floating, so it casts a real shadow and must not clip it.
                    clip: false
                    elevation: 3
                    radius: Tokens.shape.pill
                    color: RecorderService.paused ? Theme.surfaceContainerHigh : Theme.errorContainer

                    implicitWidth: contentRow.implicitWidth + Tokens.spacing.medium * 2
                    implicitHeight: Math.max(contentRow.implicitHeight + Tokens.spacing.small * 2,
                                             Tokens.touchTarget.minimum)

                    RowLayout {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIndicator {
                            id: dot
                            size: "small"
                            colorRole: RecorderService.paused ? "onSurfaceVariant" : "error"
                            Layout.leftMargin: Tokens.spacing.extraSmall

                            // Breathing while recording, steady while paused, so
                            // the state reads without looking at the icons.
                            // Guarded on the duration: reduce-motion and gaming
                            // mode scale it to zero, and a zero-length loop is a
                            // busy spin, not a still dot.
                            SequentialAnimation on opacity {
                                running: RecorderService.active && !RecorderService.paused
                                         && Tokens.motion.duration.extraLong2 > 0
                                loops: Animation.Infinite
                                alwaysRunToEnd: true

                                MotionAnimation {
                                    from: 1.0
                                    to: 0.35
                                    duration: Tokens.motion.duration.extraLong2
                                    curve: "standard"
                                }
                                MotionAnimation {
                                    from: 0.35
                                    to: 1.0
                                    duration: Tokens.motion.duration.extraLong2
                                    curve: "standard"
                                }
                            }

                            // The animation above leaves opacity wherever it
                            // stopped; a paused recording must not be dimmed.
                            onOpacityChanged: if (RecorderService.paused && opacity !== 1.0) opacity = 1.0
                        }

                        // Monospace: proportional digits make the seconds column
                        // twitch on every tick.
                        MonoText {
                            text: RecorderService.elapsedText
                            textStyle: "labelLarge"
                            colorRole: RecorderService.paused ? "onSurfaceVariant" : "onErrorContainer"
                        }

                        IconButton {
                            visible: AppConfig.recorderIndicatorControls
                            iconName: RecorderService.paused ? "play_arrow" : "pause"
                            iconSize: Tokens.iconSize.medium
                            containerSize: Tokens.iconSize.extraLarge
                            touchTargetSize: Tokens.iconSize.extraLarge
                            colorRole: RecorderService.paused ? "onSurfaceVariant" : "onErrorContainer"
                            onClicked: RecorderService.togglePause()
                        }

                        IconButton {
                            visible: AppConfig.recorderIndicatorControls
                            iconName: "stop"
                            iconSize: Tokens.iconSize.medium
                            containerSize: Tokens.iconSize.extraLarge
                            touchTargetSize: Tokens.iconSize.extraLarge
                            colorRole: RecorderService.paused ? "onSurfaceVariant" : "onErrorContainer"
                            onClicked: RecorderService.stop()
                        }
                    }
                }
            }
        }
    }
}
