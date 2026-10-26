import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

BarElement {
    // No fabricated "0°C" before the first fetch / with weather disabled.
    property bool shown: Weather.data !== null

    id: root
    clickable: true
    hoverable: true
    minWidth: Tokens.size.control
    preferredWidth: Math.max(minWidth, (showIcon ? weatherGlyph.implicitWidth : 0)
        + (showTemp ? temperatureLabel.implicitWidth : 0)
        + (showLocation ? Math.min(locationLabel.implicitWidth, Tokens.size.fieldWidth) : 0)
        + Math.max(0, Number(showIcon) + Number(showTemp) + Number(showLocation) - 1) * Tokens.spacing.extraSmall
        + Tokens.spacing.medium)
    minimumWidth: preferredWidth
    compactWidth: Math.max(minWidth, (showIcon ? weatherGlyph.implicitWidth : temperatureLabel.implicitWidth) + Tokens.spacing.medium)

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})
    property bool showLocation: widgetSettings.showLocation ?? true
    property bool showIcon: widgetSettings.showIcon ?? true
    property bool showTemp: widgetSettings.showTemp ?? true


    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
            GlobalStates.handleClickAction(root.widgetConfig?.clickAction ?? "dashboard-weather")
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    RowLayout {
        width: Math.max(0, root.width - Tokens.spacing.medium)
        spacing: Tokens.spacing.extraSmall

        MaterialText {
            id: locationLabel
            Layout.fillWidth: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
            visible: root.showLocation && !root.compactPresentation
            text: Weather.location
            textStyle: "bodyMedium"
            colorRole: "onSurface"
        }

        MaterialIcon {
            id: weatherGlyph
            visible: root.showIcon
            iconName: Weather.icon
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurface
        }

        MaterialText {
            id: temperatureLabel
            visible: root.showTemp && (!root.compactPresentation || !root.showIcon)
            text: Math.round(Weather.tempC) + Weather.tempUnit
            textStyle: "bodyMedium"
            colorRole: "onSurface"
        }
    }
}
