pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.maintab_elements

// A column of full-width sections, ordered by how often each is touched.
//
// This was a `GridLayout { columns: 4; rows: 4 }` in which no child was sized to
// the grid -- Weather pinned 240px, the sliders 70, the player 400x250, the
// monitor strip 100 tall -- so five fixed boxes divided the leftover space
// instead of columns of equal width. That is why nothing lined up, why the
// bottom edge came out ragged, and why the sparklines were clipped by the panel.
//
// It also spent its largest areas on things nobody clicks: measured on the old
// panel, the profile card, metrics and weather together took five times the area
// of the toggles, in a panel that exists for the toggles. Weather has its own
// tab and the profile card was not an action, so both are gone from here.
Item {
    id: root

    // Height this tab needs BEYOND the window's base size, published for
    // DashboardContent to forward. The window is sized per tab, so without this
    // an expanded section would simply be clipped -- there is nowhere for it to
    // grow into.
    // Every expandable section, not just one: forgetting the media row here cost
    // the metrics tiles their bottom 30 px the first time both were open.
    readonly property int extraHeight: mediaRow.expandedDelta + metrics.expandedDelta

    // Both level rows share one label column so their sliders start at the same
    // x. Measured, not pinned: a fixed 78px was fine in Roboto and immediately
    // overlapped the slider once the minimal pack switched the shell to
    // monospace, where the same word is wider.
    readonly property int _levelLabelWidth: Math.max(volumeLabel.implicitWidth,
                                                     brightnessLabel.implicitWidth)

    // What this tab actually needs, published so the window can be sized to it
    // rather than to a constant. The constant version broke the moment the pack
    // changed density -- exactly the drift a measured value cannot have.
    // The gutter is counted twice because it exists twice, and it has to be the
    // SAME token the column is laid out with -- these drifted apart the moment
    // the gutter changed, and the panel came up 16px short with the media strip
    // sliced off at the bottom edge.
    readonly property int contentHeight: column.implicitHeight + Tokens.panelPadding * 2

    ColumnLayout {
        id: column
        anchors.fill: parent
        // The panel's gutter. It was `small` -- 4px against a 900px panel, so
        // every row started on the edge and the whole thing read as cropped.
        anchors.margins: Tokens.panelPadding
        spacing: Tokens.spacing.medium

        // ===== toggles: the reason the panel is opened, so they lead =====
        // Equal columns. `fillWidth` alone divides the SLACK, not the width, so
        // each tile kept its own implicit width and "Do not disturb" came out
        // wider than "VPN" -- eight controls of the same kind in eight
        // different sizes. The pair below is the shape used for the metric
        // columns: an equal share each, and a minimum of zero so a long label
        // elides instead of pushing its column wider.
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: NetworkService.icon
                label: "Wi-Fi"
                active: NetworkService.wifiEnabled
                onClicked: NetworkService.toggleWifi()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: BluetoothService.icon
                label: "Bluetooth"
                active: BluetoothService.enabled
                onClicked: BluetoothService.toggle()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: VPNService.icon
                label: "VPN"
                active: VPNService.connected
                onClicked: VPNService.toggle()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "coffee"
                label: "Caffeine"
                active: IdleInhibitorService.inhibit
                onClicked: IdleInhibitorService.toggleInhibit()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "do_not_disturb_on"
                label: "Do not disturb"
                active: NotificationService.doNotDisturb
                onClicked: NotificationService.toggleDoNotDisturb()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "nightlight"
                label: "Night light"
                active: NightLightService.enabled
                onClicked: NightLightService.toggle()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "sports_esports"
                label: "Gaming"
                active: GamingModeService.gamingModeActive
                onClicked: GamingModeService.toggleGamingMode()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "screenshot_region"
                label: "Screenshot"
                active: false
                onClicked: ScreenshotService.takeScreenshotSwappy()
            }
        }

        // ===== sliders: horizontal, named, and showing their value =====
        // Vertical before, in 70px columns with no label and no readout: more
        // pointer travel for less information.
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                iconName: AudioService.masterMuted ? "volume_off" : "volume_up"
                iconSize: Tokens.iconSize.medium
                containerSize: Tokens.iconSize.extraLarge
                touchTargetSize: Tokens.iconSize.extraLarge
                colorRole: "onSurfaceVariant"
                onClicked: AudioService.toggleMasterMute()
            }
            MaterialText {
                id: volumeLabel
                Layout.rightMargin: Tokens.spacing.small
                Layout.preferredWidth: root._levelLabelWidth
                text: "Volume"
                textStyle: "labelMedium"
                colorRole: "onSurfaceVariant"
            }
            MaterialSlider {
                Layout.fillWidth: true
                // A level is a QUANTITY. Filled with the accent it became the
                // largest coloured area in the panel -- a full-width bar of it,
                // twice -- which is most of what made the accent stop meaning
                // anything anywhere else.
                accentRole: "onSurfaceVariant"
                enabled: AudioService.defaultSink !== null
                from: 0
                to: 1
                value: AudioService.masterVolume
                onMoved: AudioService.setMasterVolume(value)
            }
            MonoText {
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                text: Math.round(AudioService.masterVolume * 100) + "%"
                textStyle: "labelMedium"
                colorRole: "onSurface"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: BrightnessService.available

            // Wrapped so it occupies the same width as the volume row's icon
            // BUTTON above and the two labels stay on one vertical line.
            Item {
                Layout.preferredWidth: Tokens.iconSize.extraLarge
                Layout.preferredHeight: Tokens.iconSize.extraLarge
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "brightness_6"
                    fontSize: Tokens.iconSize.medium
                    backgroundColor: "transparent"
                    colorRole: "onSurfaceVariant"
                }
            }
            MaterialText {
                id: brightnessLabel
                Layout.rightMargin: Tokens.spacing.small
                Layout.preferredWidth: root._levelLabelWidth
                text: "Brightness"
                textStyle: "labelMedium"
                colorRole: "onSurfaceVariant"
            }
            MaterialSlider {
                Layout.fillWidth: true
                accentRole: "onSurfaceVariant"
                enabled: BrightnessService.available
                from: 0
                to: 1
                value: BrightnessService.brightness
                onMoved: BrightnessService.setBrightness(value)
            }
            MonoText {
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                text: Math.round(BrightnessService.brightness * 100) + "%"
                textStyle: "labelMedium"
                colorRole: "onSurface"
            }
        }

        // ===== metrics: read-only, so one line until asked otherwise =====
        ExpandableCard {
            id: metrics
            Layout.fillWidth: true
            // The gauge and the history it belongs to need a gap between them,
            // or the chart reads as part of the bar above it.
            spacing: Tokens.spacing.medium

            RowLayout {
                width: parent.width
                spacing: Tokens.spacing.medium

                Repeater {
                    model: [
                        { label: "CPU" },
                        { label: "GPU" },
                        { label: "RAM" },
                        { label: "SSD" }
                    ]

                    // Three tiers, not one line. It used to be
                    // `icon CPU 1% 56°` at a single size, four of those in a
                    // row: nothing to fix on, so reading it meant reading all
                    // of it. Now the name is small and quiet, the number it is
                    // named for is large, the secondary reading sits beside it
                    // at label size, and the bar answers "how full" before any
                    // of them are read at all.
                    delegate: ColumnLayout {
                        id: metricEntry
                        required property var modelData

                        readonly property real fraction: {
                            switch (metricEntry.modelData.label) {
                            case "CPU": return SystemMonitorService.cpuUsage / 100
                            case "GPU": return SystemMonitorService.gpuUsage / 100
                            case "RAM": return SystemMonitorService.ramUsage / 100
                            default:    return SystemMonitorService.diskUsage / 100
                            }
                        }
                        readonly property string value: Math.round(metricEntry.fraction * 100) + "%"
                        readonly property string detail: {
                            switch (metricEntry.modelData.label) {
                            // ramUsed/ramTotal come back as bare numbers -- the
                            // unit belongs to the caller, as SystemMonitoringElement
                            // has always done. cpuTemp is absent on machines
                            // without the sensor.
                            case "CPU": return SystemMonitorService.hasCpuTemp
                                               ? SystemMonitorService.cpuTemp + "\u00B0" : ""
                            case "GPU": return SystemMonitorService.gpuTemp + "\u00B0"
                            case "RAM": return SystemMonitorService.ramUsed + "G"
                            default:    return SystemMonitorService.diskUsed
                            }
                        }

                        visible: metricEntry.modelData.label !== "GPU" || SystemMonitorService.hasGpuStats
                        // Equal columns. With an internal spacer as well, each
                        // entry stretched by a different amount and the four
                        // readouts drifted out of any rhythm.
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: Tokens.spacing.extraSmall

                        MaterialText {
                            text: metricEntry.modelData.label
                            textStyle: "labelSmall"
                            colorRole: "onSurfaceVariant"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MonoText {
                                text: metricEntry.value
                                textStyle: "titleMedium"
                                colorRole: "onSurface"
                            }
                            MonoText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignBaseline
                                text: metricEntry.detail
                                textStyle: "labelSmall"
                                colorRole: "onSurfaceVariant"
                                elide: Text.ElideRight
                            }
                        }

                        LevelBar {
                            Layout.fillWidth: true
                            Layout.rightMargin: Tokens.spacing.medium
                            value: metricEntry.fraction
                        }
                    }
                }
            }

            // The detailed tiles are not deleted, only folded away: they carry
            // the history sparklines, which a single line cannot.
            expandedContent: SystemMonitoringElement {}
        }

        // ===== media: last, and flush with the bottom edge =====
        // It sits below everything because it is the one section that is read
        // rather than operated -- and because it is the only one that grows, so
        // growing downwards costs nothing above it.
        QuickMediaRow {
            id: mediaRow
            Layout.fillWidth: true
            // Negative by exactly the gutter: the strip is the one thing that
            // reaches the panel edge, and it has to keep doing that when the
            // gutter changes.
            Layout.bottomMargin: -Tokens.panelPadding
            Layout.leftMargin: -Tokens.panelPadding
            Layout.rightMargin: -Tokens.panelPadding
            Layout.topMargin: Tokens.spacing.large
        }
    }
}
