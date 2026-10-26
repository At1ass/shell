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
ScrollableList {
    id: root
    contentPadding: Tokens.panelPadding

    // Height this tab needs BEYOND the window's base size, published for
    // DashboardContent to forward. The window is sized per tab, so without this
    // an expanded section would simply be clipped -- there is nowhere for it to
    // grow into.
    // Every expandable section, not just one: forgetting the media row here cost
    // the metrics tiles their bottom 30 px the first time both were open.
    property bool metricsExpanded: false
    readonly property int extraHeight: mediaRow.expandedDelta
        + (root.metricsExpanded ? metricsLoader.implicitHeight + Tokens.spacing.medium : 0)

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
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        // Modes are controlled toggles; destinations below use action tiles.
        GridLayout {
            Layout.fillWidth: true
            columns: width < notificationsTile.implicitWidth * 2 + columnSpacing ? 1
                : width < notificationsTile.implicitWidth * 4 + columnSpacing * 3 ? 2 : 4
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "coffee"
                label: "Caffeine"
                supportingText: IdleInhibitorService.statusText
                active: IdleInhibitorService.inhibit
                onClicked: IdleInhibitorService.toggleInhibit()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                id: notificationsTile
                iconName: "do_not_disturb_on"
                label: "Do not disturb"
                supportingText: NotificationDND.statusText
                active: NotificationService.doNotDisturb
                onClicked: NotificationService.toggleDoNotDisturb()
            }
            ToggleTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "nightlight"
                visible: NightLightService.available
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

        }

        // Destinations and one-shot commands are separate from mode toggles.
        GridLayout {
            Layout.fillWidth: true
            columns: width < notificationsTile.implicitWidth * 2 + columnSpacing ? 1
                : width < notificationsTile.implicitWidth * 4 + columnSpacing * 3 ? 2 : 4
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small
            ActionTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: NetworkService.icon
                visible: NetworkService.wifiAvailable
                label: "Wi-Fi"
                onClicked: GlobalStates.openConnections("wifi", null)
            }
            ActionTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: BluetoothService.icon
                visible: BluetoothService.adapter !== null
                label: "Bluetooth"
                onClicked: GlobalStates.openConnections("bluetooth", null)
            }
            ActionTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "volume_up"
                label: "Audio"
                visible: AppConfig.moduleEnabled("audio")
                onClicked: GlobalStates.openAudio(null)
            }
            ActionTile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                iconName: "screenshot_region"
                visible: AppConfig.moduleEnabled("screenshot")
                trailingIcon: ""
                label: "Screenshot"
                onClicked: ScreenshotService.takeScreenshotSwappy()
            }
        }

        // Brightness remains local; all audio controls live in the Audio panel.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            visible: BrightnessService.available
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                MaterialIcon { iconName: "brightness_6"; fontSize: Tokens.iconSize.medium; colorRole: "onSurfaceVariant" }
                MaterialText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Brightness"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                    elide: Text.ElideRight
                }
                MonoText { text: Math.round(BrightnessService.brightness*100)+"%"; textStyle: "labelMedium" }
            }
            MaterialSlider {
                Layout.fillWidth: true
                Accessible.name: "Brightness"
                accentRole: "onSurfaceVariant"
                from: 0; to: 1
                value: BrightnessService.brightness
                onMoved: BrightnessService.setBrightness(value)
            }
        }

        ListItem {
            Layout.fillWidth: true
            supportingTextFormat: Text.PlainText
            headline: "System statistics"
            supportingText: SystemMonitorService.storageAlertText
            headlineColor: SystemMonitorService.storageSeverity === 2 ? Theme.error : Theme.onSurface
            leadingIcon: SystemMonitorService.storageSeverity > 0 ? "warning" : "monitoring"
            leadingIconColor: SystemMonitorService.storageSeverity === 2 ? Theme.error
                : SystemMonitorService.storageSeverity === 1 ? Theme.tertiary : Theme.onSurfaceVariant
            trailingIcon: root.metricsExpanded ? "expand_less" : "expand_more"
            margin: Tokens.spacing.small
            onClicked: root.metricsExpanded = !root.metricsExpanded
        }
        Loader {
            id: metricsLoader
            Layout.fillWidth: true
            visible: active
            active: root.metricsExpanded
            sourceComponent: SystemMonitoringElement {}
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
