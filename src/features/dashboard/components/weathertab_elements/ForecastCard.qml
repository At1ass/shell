import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    id: card

    required property string date
    required property real tempMax
    required property real tempMin
    required property int weatherCode
    required property real precipSum
    required property int precipProbMax
    required property string sunrise
    required property string sunset

    color: Qt.alpha(Config.colors.surfaceContainerHigh, 0.80)
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.extraSmall

        // Day name (bold, primary color)
        MaterialText {
            text: {
                if (!date || date === "") return "N/A";

                var d = new Date(date);
                if (isNaN(d.getTime())) return "N/A";

                var today = new Date();
                today.setHours(0, 0, 0, 0);
                d.setHours(0, 0, 0, 0);

                if (d.getTime() === today.getTime()) return "Today";

                var tomorrow = new Date(today);
                tomorrow.setDate(tomorrow.getDate() + 1);
                if (d.getTime() === tomorrow.getTime()) return "Tmrw";

                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                return days[d.getDay()];
            }
            textStyle: "titleMedium"
            colorRole: "primary"
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }

        // Date (small, under day name)
        MaterialText {
            text: {
                if (!date || date === "") return "";
                var d = new Date(date);
                if (isNaN(d.getTime())) return "";
                return d.toLocaleDateString(Qt.locale(), "MMM d");
            }
            textStyle: "bodySmall"
            colorRole: "onSurfaceVariant"
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Config.spacing.extraSmall
        }

        // Weather icon (secondary color like caelesia)
        MaterialIcon {
            iconName: WeatherIcons.codeToName[weatherCode] || "cloud"
            fontSize: 48
            iconColor: Config.colors.secondary
            backgroundColor: "transparent"
            Layout.alignment: Qt.AlignHCenter
        }

        // Temperature range (tertiary color for emphasis)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            MaterialText {
                text: Math.round(tempMax) + "°"
                textStyle: "titleMedium"
                colorRole: "tertiary"
                font.weight: Font.Bold
            }

            MaterialText {
                text: "/"
                textStyle: "titleMedium"
                colorRole: "onSurfaceVariant"
                opacity: 0.5
            }

            MaterialText {
                text: Math.round(tempMin) + "°"
                textStyle: "titleMedium"
                colorRole: "tertiary"
                font.weight: Font.Bold
            }
        }

        // Precipitation
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            // visible: precipProbMax > 0

            MaterialIcon {
                iconName: "water_drop"
                visible: precipProbMax > 0
                fontSize: 12
                iconColor: Config.colors.primary
                backgroundColor: "transparent"
            }

            MaterialText {
                text: precipProbMax + "%"
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
                visible: precipProbMax > 0
            }
        }
    }
}
