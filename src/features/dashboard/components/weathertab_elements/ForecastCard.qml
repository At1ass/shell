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

    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.medium

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: Config.spacing.extraSmall

        // Day name
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
            textStyle: "labelMedium"
            colorRole: "onSurface"
            font.weight: Font.Medium
            Layout.alignment: Qt.AlignHCenter
        }

        // Weather icon
        MaterialIcon {
            iconName: WeatherIcons.codeToName[weatherCode] || "cloud"
            fontSize: 40
            iconColor: Config.colors.primary
            backgroundColor: "transparent"
            Layout.alignment: Qt.AlignHCenter
        }

        // Temperature range
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            MaterialText {
                text: Math.round(tempMax) + "°"
                textStyle: "titleMedium"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }

            MaterialText {
                text: "/"
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
            }

            MaterialText {
                text: Math.round(tempMin) + "°"
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
            }
        }

        // Precipitation
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            visible: precipProbMax > 0

            MaterialIcon {
                iconName: "water_drop"
                fontSize: 12
                iconColor: Config.colors.primary
                backgroundColor: "transparent"
            }

            MaterialText {
                text: precipProbMax + "%"
                textStyle: "labelSmall"
                colorRole: "onSurfaceVariant"
            }
        }
    }
}
