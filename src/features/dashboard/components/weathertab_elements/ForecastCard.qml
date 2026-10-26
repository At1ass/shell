import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    id: card

    required property string date

    // "yyyy-MM-dd" -> local Date at midnight, or null.
    function _localDate(text) {
        if (!text) return null
        const parts = text.split("-")
        if (parts.length !== 3) return null
        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
        return isNaN(d.getTime()) ? null : d
    }
    required property real tempMax
    required property real tempMin
    required property int weatherCode
    required property int precipProbMax

    color: Theme.surfaceContainerLow
    radius: Tokens.shape.medium

    // Stated, because a Pane does not learn it from an anchored child. The
    // column below fills this card by anchors, so the card reported no height
    // of its own -- invisible while the tab was sized by a constant with slack
    // in it, and immediately visible once the tab was sized to its content: the
    // bottom row of every forecast card sat flush against its own edge.
    implicitWidth: Math.ceil(forecastColumn.implicitWidth + Tokens.spacing.small * 2)
    implicitHeight: forecastColumn.implicitHeight + Tokens.spacing.small * 2

    ColumnLayout {
        id: forecastColumn
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        spacing: Tokens.spacing.extraSmall

        // Day name (bold, primary color)
        MaterialText {
            text: {
                // Parse "yyyy-MM-dd" as LOCAL (new Date(string) reads UTC —
                // one day early west of Greenwich). DateTime.clock makes
                // Today/Tmrw roll over at midnight while the tab is open.
                const d = card._localDate(card.date)
                if (!d) return "N/A";

                const today = new Date(DateTime.clock.date.getFullYear(),
                                       DateTime.clock.date.getMonth(),
                                       DateTime.clock.date.getDate());

                if (d.getTime() === today.getTime()) return "Today";

                const tomorrow = new Date(today);
                tomorrow.setDate(tomorrow.getDate() + 1);
                if (d.getTime() === tomorrow.getTime()) return "Tmrw";

                return Qt.formatDate(d, "ddd");
            }
            textStyle: "titleMedium"
            colorRole: "primary"
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }

        // Date (small, under day name)
        MaterialText {
            text: {
                const d = card._localDate(card.date);
                return d ? d.toLocaleDateString(Qt.locale(), "MMM d") : "";
            }
            textStyle: "bodySmall"
            colorRole: "onSurfaceVariant"
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Tokens.spacing.extraSmall
        }

        // Weather icon (secondary color like caelestia)
        MaterialIcon {
            iconName: WeatherIcons.codeToName[card.weatherCode] || "cloud"
            fontSize: Tokens.typography.titleLarge.size
            iconColor: Theme.onSurfaceVariant
            backgroundColor: "transparent"
            Layout.alignment: Qt.AlignHCenter
        }

        // High and low share one narrow column so seven readable days fit.
        MaterialText {
            text: Math.round(card.tempMax) + "°"
            textStyle: "titleMedium"
            colorRole: "onSurface"
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }
        MaterialText {
            text: Math.round(card.tempMin) + "°"
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Tokens.spacing.extraSmall
        }

        // Keep the precipitation slot aligned on dry and rainy days alike.
        RowLayout {
            Layout.preferredHeight: Math.max(Tokens.iconSize.small, Tokens.typography.labelSmall.lineHeight)
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                iconName: "water_drop"
                visible: card.precipProbMax > 0
                fontSize: Tokens.iconSize.small
                iconColor: Theme.primary
                backgroundColor: "transparent"
            }

            MaterialText {
                text: card.precipProbMax + "%"
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
                visible: card.precipProbMax > 0
            }
        }
    }
}
