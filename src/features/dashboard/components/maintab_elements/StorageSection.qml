pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

ColumnLayout {
    id: root
    property bool expanded: false
    readonly property var summary: SystemMonitorService.storageSummary
    readonly property var volumes: SystemMonitorService.storageVolumes
    readonly property var drives: SystemMonitorService.storageDrives
    spacing: Tokens.spacing.small

    ListItem {
        Layout.fillWidth: true
        supportingTextFormat: Text.PlainText
        headline: "Storage"
        supportingText: SystemMonitorService.storageAlertText || (root.summary.available
            ? `${root.summary.name ?? "System"} · ${SystemMonitorService.storageFreeText}` : "Storage information unavailable")
        headlineColor: SystemMonitorService.storageSeverity === 2 ? Theme.error : Theme.onSurface
        leadingIcon: SystemMonitorService.storageSeverity > 0 ? "warning" : "storage"
        leadingIconColor: SystemMonitorService.storageSeverity === 2 ? Theme.error
            : SystemMonitorService.storageSeverity === 1 ? Theme.tertiary : Theme.onSurfaceVariant
        trailingIcon: root.expanded ? "expand_less" : "expand_more"
        onClicked: root.expanded = !root.expanded
    }
    MaterialText {
        Layout.fillWidth: true
        visible: root.summary.hasIo ?? false
        text: `Read ${root.summary.readFormatted ?? "—"} · Write ${root.summary.writeFormatted ?? "—"}`
        textStyle: "bodySmall"
        colorRole: "onSurfaceVariant"
        wrapMode: Text.Wrap
    }
    Loader {
        Layout.fillWidth: true
        active: root.expanded
        visible: active
        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small
            Repeater {
                model: ScriptModel { values: Array.from(root.volumes); objectProp: "id" }
                ColumnLayout {
                    id: volumeRow
                    required property var modelData
                    property bool detailsOpen: false
                    readonly property int severity: modelData.severity ?? 0
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    ListItem {
                        Layout.fillWidth: true
                        supportingTextFormat: Text.PlainText
                        headline: volumeRow.modelData.name ?? "Storage"
                        headlineTextFormat: Text.PlainText
                        supportingText: volumeRow.modelData.available
                            ? `${volumeRow.modelData.availableFormatted} free / ${volumeRow.modelData.totalFormatted}${volumeRow.modelData.readOnly ? " · Read only" : ""}`
                            : "Space information unavailable"
                        leadingIcon: volumeRow.severity > 0 ? "warning" : "hard_drive"
                        leadingIconColor: volumeRow.severity === 2 ? Theme.error : volumeRow.severity === 1 ? Theme.tertiary : Theme.onSurfaceVariant
                        trailingIcon: volumeRow.detailsOpen ? "expand_less" : "expand_more"
                        trailingSupportingText: volumeRow.modelData.available ? `${Math.floor((volumeRow.modelData.usedFraction ?? 0) * 1000) / 10}%` : ""
                        onClicked: volumeRow.detailsOpen = !volumeRow.detailsOpen
                    }
                    ProgressIndicator {
                        Layout.fillWidth: true
                        Layout.leftMargin: Tokens.spacing.medium
                        Layout.rightMargin: Tokens.spacing.medium
                        visible: volumeRow.modelData.available ?? false
                        value: volumeRow.modelData.usedFraction ?? 0
                        animateValue: false
                        activeColor: volumeRow.severity === 2 ? Theme.error : volumeRow.severity === 1 ? Theme.tertiary : Theme.onSurfaceVariant
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        Layout.margins: Tokens.spacing.medium
                        visible: volumeRow.detailsOpen
                        text: `${(volumeRow.modelData.mountPoints ?? []).join(", ")}\n${volumeRow.modelData.fileSystem ?? ""} · ${volumeRow.modelData.device ?? ""}`
                        textFormat: Text.PlainText
                        textStyle: "bodySmall"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }
                }
            }
            MaterialText {
                Layout.fillWidth: true
                Layout.margins: Tokens.spacing.medium
                visible: !SystemMonitorService.storageAvailable || root.volumes.length === 0
                text: "Additional storage information unavailable"
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
            }
            MaterialText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                visible: root.drives.length > 0
                text: "Devices"
                textStyle: "labelLarge"
                colorRole: "onSurfaceVariant"
            }
            Repeater {
                model: ScriptModel { values: Array.from(root.drives); objectProp: "id" }
                ListItem {
                    required property var modelData
                    Layout.fillWidth: true
                    clickable: false
                    supportingTextFormat: Text.PlainText
                    headline: modelData.name ?? "Drive"
                    headlineTextFormat: Text.PlainText
                    supportingText: `${modelData.device ?? ""}${modelData.removable ? " · Removable" : ""}${modelData.hasTemperature ? ` · ${modelData.temperature} °C` : ""}`
                    trailingSupportingText: modelData.hasIo ? `R ${modelData.readFormatted}\nW ${modelData.writeFormatted}` : "I/O unavailable"
                    leadingIcon: "hard_drive"
                }
            }
        }
    }
}
