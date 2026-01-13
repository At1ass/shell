import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.weathertab_elements

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.small

        // === Row 1: Current Weather + Details ===
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            spacing: Config.spacing.small

            // Current Weather (compact)
            MaterialCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 380
                color: Qt.alpha(Config.colors.surfaceContainerHigh, 0.80)
                radius: Config.shape.large

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: Config.spacing.medium

                    // Weather icon
                    MaterialIcon {
                        iconName: Weather.icon
                        fontSize: 90
                        iconColor: Config.colors.primary
                        backgroundColor: "transparent"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Item { Layout.fillWidth: true }

                    // Temperature + info
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        RowLayout {
                            spacing: 0

                            MaterialText {
                                text: Math.round(Weather.tempC)
                                textStyle: "displayMedium"
                                colorRole: "onSurface"
                                font.weight: Font.Bold
                            }

                            MaterialText {
                                text: "°C"
                                textStyle: "headlineMedium"
                                colorRole: "onSurfaceVariant"
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 4
                            }
                        }

                        MaterialText {
                            text: Weather.weatherDesc
                            textStyle: "titleMedium"
                            colorRole: "onSurface"
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        MaterialText {
                            text: "Feels like " + Math.round(Weather.feelsLikeC) + "°C"
                            textStyle: "bodyMedium"
                            colorRole: "onSurfaceVariant"
                        }

                        Item { Layout.fillHeight: true }

                        // Location
                        RowLayout {
                            spacing: 4

                            MaterialIcon {
                                iconName: "location_on"
                                fontSize: Config.typography.bodySmall.size
                                iconColor: Config.colors.primary
                                backgroundColor: "transparent"
                            }

                            MaterialText {
                                text: Weather.location || "Penza, Russia"
                                textStyle: "bodySmall"
                                colorRole: "onSurfaceVariant"
                            }
                        }
                    }
                }
            }

            // Details (compact, 2 columns)
            MaterialCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.alpha(Config.colors.surfaceContainerHigh, 0.80)
                radius: Config.shape.large

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    columns: 2
                    rowSpacing: Config.spacing.extraSmall
                    columnSpacing: Config.spacing.medium

                    // Column 1
                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "humidity_percentage"
                        label: "Humidity"
                        value: Weather.humidity + "%"
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "compress"
                        label: "Pressure"
                        value: Math.round(Weather.pressure) + " hPa"
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "air"
                        label: "Wind"
                        value: Math.round(Weather.windSpeed) + " km/h"
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "water_drop"
                        label: "Precipitation"
                        value: Weather.precipitation.toFixed(1) + " mm"
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "wb_twilight"
                        label: "Sunrise"
                        value: {
                            if (Weather.dailySunrise.length > 0) {
                                var dt = new Date(Weather.dailySunrise[0]);
                                return dt.toLocaleTimeString(Qt.locale(), "hh:mm");
                            }
                            return "--:--";
                        }
                    }

                    DetailRow {
                        Layout.fillWidth: true
                        iconName: "wb_twilight"
                        label: "Sunset"
                        value: {
                            if (Weather.dailySunset.length > 0) {
                                var dt = new Date(Weather.dailySunset[0]);
                                return dt.toLocaleTimeString(Qt.locale(), "hh:mm");
                            }
                            return "--:--";
                        }
                    }
                }
            }
        }

        // === Row 2: 7-Day Forecast ===
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.alpha(Config.colors.surfaceContainerHigh, 0.80)
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.medium
                spacing: Config.spacing.small

                MaterialText {
                    text: "7-Day Forecast"
                    textStyle: "titleMedium"
                    colorRole: "onSurface"
                    font.weight: Font.Bold
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Config.spacing.small

                    Repeater {
                        model: Math.min(Weather.dailyTime.length, 7)

                        delegate: ForecastCard {
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 80

                            date: Weather.dailyTime[index] || ""
                            tempMax: Weather.dailyTempMax[index] || 0
                            tempMin: Weather.dailyTempMin[index] || 0
                            weatherCode: Weather.dailyWeatherCode[index] || 0
                            precipSum: Weather.dailyPrecipSum[index] || 0
                            precipProbMax: Weather.dailyPrecipProbMax[index] || 0
                            sunrise: Weather.dailySunrise[index] || ""
                            sunset: Weather.dailySunset[index] || ""
                        }
                    }
                }
            }
        }

        // Error state (overlay)
        MaterialCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: Config.colors.errorContainer
            radius: Config.shape.large
            visible: Weather.errorString !== ""

            RowLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.medium
                spacing: Config.spacing.medium

                MaterialIcon {
                    iconName: "error"
                    fontSize: Config.typography.headlineMedium.size
                    iconColor: Config.colors.onErrorContainer
                    backgroundColor: "transparent"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MaterialText {
                        text: "Weather data unavailable"
                        textStyle: "titleMedium"
                        colorRole: "onErrorContainer"
                        font.weight: Font.Bold
                    }

                    MaterialText {
                        text: Weather.errorString
                        textStyle: "bodySmall"
                        colorRole: "onErrorContainer"
                    }
                }
            }
        }
    }
}
