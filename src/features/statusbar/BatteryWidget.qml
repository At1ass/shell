import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    id: root
    clickable: true
    hoverable: true
    minWidth: 56

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showPercentage: widgetSettings.showPercentage ?? true
    property bool showIcon: widgetSettings.showIcon ?? true

    readonly property var device: UPower.displayDevice
    readonly property bool deviceReady: device && (device.ready === undefined || device.ready)
    readonly property int percentage: device && device.percentage !== undefined ? Math.round(device.percentage) : 0
    readonly property bool charging: device && (device.state === UPowerDeviceState.Charging ||
                                               device.state === UPowerDeviceState.PendingCharge)

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton && widgetConfig?.clickAction) {
            GlobalStates.handleClickAction(widgetConfig.clickAction)
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        spacing: Config.spacing.extraSmall

        MaterialIcon {
            visible: root.showIcon
            iconName: root.batteryIcon(root.percentage, root.charging, root.deviceReady)
            fontSize: Config.typography.titleLarge.size
            iconColor: Config.colors.onSurface
            color: "transparent"
        }

        MaterialText {
            visible: root.showPercentage
            text: root.deviceReady ? `${root.percentage}%` : "--%"
            textStyle: "bodyMedium"
            colorRole: "onSurface"
        }
    }

    function batteryIcon(percent, isCharging, ready) {
        if (!ready)
            return "battery_unknown"

        if (isCharging) {
            if (percent >= 90) return "battery_charging_full"
            if (percent >= 70) return "battery_charging_80"
            if (percent >= 50) return "battery_charging_60"
            if (percent >= 30) return "battery_charging_30"
            return "battery_charging_20"
        }

        if (percent >= 90) return "battery_full"
        if (percent >= 75) return "battery_6_bar"
        if (percent >= 60) return "battery_5_bar"
        if (percent >= 45) return "battery_4_bar"
        if (percent >= 30) return "battery_3_bar"
        if (percent >= 15) return "battery_2_bar"
        if (percent > 5) return "battery_1_bar"
        return "battery_alert"
    }
}
