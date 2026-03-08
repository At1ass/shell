import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback

ColumnLayout {
    spacing: Tokens.spacing.medium

    // Connection info
    Repeater {
        model: [
            { label: "Interface", value: EthernetService.interfaceName },
            { label: "IP Address", value: EthernetService.ipAddress },
            { label: "Gateway", value: EthernetService.gateway },
            { label: "Speed", value: EthernetService.speed }
        ]

        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.spacing.small
            Layout.rightMargin: Tokens.spacing.small

            MaterialText {
                text: modelData.label
                textStyle: "labelMedium"
                colorRole: "onSurfaceVariant"
            }
            Item { Layout.fillWidth: true }
            MaterialText {
                text: modelData.value || "\u2014"
                textStyle: "bodyMedium"
                colorRole: "onSurface"
            }
        }
    }

    // Network throughput
    MaterialCard {
        Layout.fillWidth: true
        Layout.preferredHeight: netColumn.implicitHeight + Tokens.spacing.medium * 2
        visible: SystemMonitorService.hasNet
        color: Theme.surfaceContainerHigh
        radius: Tokens.shape.medium

        ColumnLayout {
            id: netColumn
            anchors.fill: parent
            anchors.margins: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    iconName: "speed"
                    fontSize: Tokens.iconSize.small
                    iconColor: Theme.onSurfaceVariant
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: "Throughput"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                Item { Layout.fillWidth: true }

                MaterialText {
                    text: "\u2193 " + SystemMonitorService.netRxFormatted
                    textStyle: "labelSmall"
                    color: Theme.primary
                }
                MaterialText {
                    text: "\u2191 " + SystemMonitorService.netTxFormatted
                    textStyle: "labelSmall"
                    color: Theme.tertiary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 2

                Sparkline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    values: SystemMonitorService.netRxHistory
                    lineColor: Theme.primary
                    fillColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    values: SystemMonitorService.netTxHistory
                    lineColor: Theme.tertiary
                    fillColor: Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.1)
                }
            }
        }
    }

    EmptyState {
        visible: !EthernetService.connected
        Layout.fillWidth: true
        Layout.fillHeight: true
        iconName: "lan_disconnect"
        title: "No wired connection"
        subtitle: "Connect an Ethernet cable"
        iconContainerSize: 56
        iconSize: 32
    }
}
