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
        anchors.margins: Tokens.spacing.medium
        spacing: Tokens.spacing.small

        // === Header: Location + Date + Sunrise/Sunset ===
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            // Left: Location + Date
            ColumnLayout {
                spacing: 2

                MaterialText {
                    text: Weather.location || "Unknown location"
                    textStyle: "headlineSmall"
                    colorRole: "onSurface"
                    font.weight: Font.Bold
                }

                MaterialText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    textStyle: "bodyMedium"
                    colorRole: "onSurfaceVariant"
                }
            }

            Item { Layout.fillWidth: true }

            // Right: Sunrise/Sunset
            RowLayout {
                spacing: Tokens.spacing.large

                // Sunrise
                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        iconName: "wb_twilight"
                        fontSize: Tokens.typography.titleLarge.size
                        iconColor: Theme.tertiary
                        backgroundColor: "transparent"
                    }

                    ColumnLayout {
                        spacing: 0

                        MaterialText {
                            text: "Sunrise"
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
                        }

                        MaterialText {
                            text: {
                                if (Weather.dailySunrise.length > 0) {
                                    var dt = new Date(Weather.dailySunrise[0]);
                                    return dt.toLocaleTimeString(Qt.locale(), "hh:mm");
                                }
                                return "--:--";
                            }
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            font.weight: Font.Bold
                        }
                    }
                }

                // Sunset
                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        iconName: "bedtime"
                        fontSize: Tokens.typography.titleLarge.size
                        iconColor: Theme.tertiary
                        backgroundColor: "transparent"
                    }

                    ColumnLayout {
                        spacing: 0

                        MaterialText {
                            text: "Sunset"
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
                        }

                        MaterialText {
                            text: {
                                if (Weather.dailySunset.length > 0) {
                                    var dt = new Date(Weather.dailySunset[0]);
                                    return dt.toLocaleTimeString(Qt.locale(), "hh:mm");
                                }
                                return "--:--";
                            }
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        // === Hero Card: Current Weather (Big) ===
        MaterialCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.80)
            radius: Tokens.shape.large

            RowLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                // Weather icon (big)
                MaterialIcon {
                    iconName: Weather.icon
                    fontSize: 100
                    iconColor: Theme.secondary
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignVCenter
                }

                // Temperature + description
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -4

                    // Temperature
                    RowLayout {
                        spacing: 0

                        MaterialText {
                            text: Math.round(Weather.tempC)
                            textStyle: "displayLarge"
                            colorRole: "primary"
                            font.weight: Font.Medium
                        }

                        MaterialText {
                            text: Weather.tempUnit
                            textStyle: "displaySmall"
                            colorRole: "onSurfaceVariant"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 8
                        }
                    }

                    // Description
                    MaterialText {
                        text: Weather.weatherDesc
                        textStyle: "titleLarge"
                        colorRole: "onSurfaceVariant"
                        Layout.leftMargin: Tokens.spacing.extraSmall
                    }
                }
            }
        }

        // === Details Cards Row ===
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            // Humidity
            DetailCard {
                Layout.fillWidth: true
                iconName: "water_drop"
                label: "Humidity"
                value: Weather.humidity + "%"
                iconColor: Theme.secondary
            }

            // Feels Like
            DetailCard {
                Layout.fillWidth: true
                iconName: "thermostat"
                label: "Feels Like"
                value: Math.round(Weather.feelsLikeC) + Weather.tempUnit
                iconColor: Theme.primary
            }

            // Wind
            DetailCard {
                Layout.fillWidth: true
                iconName: "air"
                label: "Wind"
                value: Math.round(Weather.windSpeed) + " " + Weather.windUnit
                iconColor: Theme.tertiary
            }

            // Pressure
            DetailCard {
                Layout.fillWidth: true
                iconName: "compress"
                label: "Pressure"
                value: Math.round(Weather.pressure) + " hPa"
                iconColor: Theme.secondary
            }
        }

        // === 7-Day Forecast Section ===
        // Header
        MaterialText {
            text: "7-Day Forecast"
            textStyle: "titleMedium"
            colorRole: "onSurface"
            font.weight: Font.Bold
            Layout.topMargin: Tokens.spacing.small
            Layout.leftMargin: Tokens.spacing.extraSmall
            visible: Weather.dailyTime.length > 0
        }

        // Forecast cards
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Repeater {
                model: Math.min(Weather.dailyTime.length, 7)

                delegate: ForecastCard {
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 90

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

        // Error state (overlay)
        MaterialCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: Theme.errorContainer
            radius: Tokens.shape.large
            visible: Weather.errorString !== ""

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    iconName: "error"
                    fontSize: Tokens.typography.headlineMedium.size
                    iconColor: Theme.onErrorContainer
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
