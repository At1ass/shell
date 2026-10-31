pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services
import qs.src.features.dashboard.components.weathertab_elements

ScrollableList {
    id: root
    contentPadding: Tokens.panelPadding
    property bool detailsExpanded: false
    readonly property bool hasConditions: Weather.data?.current !== undefined && Weather.data?.current !== null
    readonly property int contentHeight: column.implicitHeight + Tokens.panelPadding * 2
    readonly property bool forecastOverflow: forecastViewport.contentWidth > forecastViewport.width + 1
    function scrollForecast(direction) {
        const card = forecastDays.itemAt(0)
        const step = (card?.width ?? Tokens.size.fieldWidth) + forecastRow.spacing
        forecastViewport.contentX = Math.max(0, Math.min(forecastViewport.contentWidth - forecastViewport.width,
            forecastViewport.contentX + direction * step))
    }
    function sunTime(values) {
        if (!values.length) return "—"
        const date = new Date(values[0])
        return isNaN(date.getTime()) ? "—" : Qt.formatTime(date, "HH:mm")
    }

    ColumnLayout {
        id: column
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialText {
            Layout.fillWidth: true
            text: Weather.location || "Weather"
            textFormat: Text.PlainText
            textStyle: "titleLarge"
            colorRole: "onSurface"
            elide: Text.ElideRight
        }
        MaterialText {
            Layout.fillWidth: true
            visible: root.hasConditions
            text: Weather.errorString !== "" || !Weather.isFresh
                ? "Last update · " + Qt.formatDateTime(Weather.lastSuccessAt, "ddd HH:mm")
                : "Updated " + Qt.formatTime(Weather.lastSuccessAt, "HH:mm")
            textStyle: "bodySmall"
            colorRole: "onSurfaceVariant"
            wrapMode: Text.Wrap
        }
        ListItem {
            Layout.fillWidth: true
            visible: !root.hasConditions || Weather.errorString !== ""
            clickable: false
            leadingIcon: Weather.busy ? "cloud_sync" : Weather.errorString !== "" ? "cloud_off" : "cloud_sync"
            headline: !AppConfig.weatherEnabled ? "Weather disabled" : !Weather.updatesAllowed ? "Weather updates paused"
                : Weather.busy ? "Updating weather…" : Weather.errorString !== ""
                ? (root.hasConditions ? "Showing last available weather" : "Weather unavailable")
                : "Waiting for weather data"
            supportingText: !AppConfig.weatherEnabled ? "Enable weather in config.json."
                : !Weather.updatesAllowed ? "Updates will resume when gaming mode ends." : Weather.errorString
            supportingTextFormat: Text.PlainText
        }
        MaterialButton {
            objectName: "weatherRetry"
            Layout.maximumWidth: column.width
            Layout.minimumWidth: 0
            visible: AppConfig.weatherEnabled && Weather.errorString !== ""
            text: Weather.busy ? "Retrying…" : "Retry"
            Accessible.name: "Retry weather update"
            enabled: Weather.canRetry
            onClicked: Weather.retry()
        }
        MaterialCard {
            Layout.fillWidth: true
            visible: root.hasConditions
            implicitHeight: conditionsRow.implicitHeight + Tokens.spacing.medium * 2
            color: Theme.surfaceContainerHigh
            radius: Tokens.shape.large
            RowLayout {
                id: conditionsRow
                anchors.fill: parent
                anchors.margins: Tokens.spacing.medium
                spacing: Tokens.spacing.medium
                MaterialIcon {
                    iconName: Weather.icon
                    fontSize: Tokens.typography.displaySmall.size
                    iconColor: Theme.onSurfaceVariant
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    MaterialText {
                        Layout.fillWidth: true
                        text: Math.round(Weather.tempC) + Weather.tempUnit
                        textStyle: "headlineLarge"
                        colorRole: "onSurface"
                        elide: Text.ElideRight
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        text: Weather.weatherDesc
                        textStyle: "bodyLarge"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }
                    MaterialText {
                        Layout.fillWidth: true
                        text: "Feels like " + Math.round(Weather.feelsLikeC) + Weather.tempUnit
                        textStyle: "bodySmall"
                        colorRole: "onSurfaceVariant"
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: Weather.dailyTime.length > 0
            spacing: Tokens.spacing.extraSmall
            MaterialText {
                Layout.fillWidth: true
                text: "7-day forecast"
                textStyle: "titleMedium"
                wrapMode: Text.Wrap
            }
            IconButton {
                visible: root.forecastOverflow
                enabled: forecastViewport.contentX > 1
                iconName: "chevron_left"
                Accessible.name: "Earlier forecast days"
                onClicked: root.scrollForecast(-1)
            }
            IconButton {
                visible: root.forecastOverflow
                enabled: forecastViewport.contentX < forecastViewport.contentWidth - forecastViewport.width - 1
                iconName: "chevron_right"
                Accessible.name: "Later forecast days"
                onClicked: root.scrollForecast(1)
            }
        }
        Flickable {
            id: forecastViewport
            Layout.fillWidth: true
            visible: forecastDays.count > 0
            implicitHeight: forecastRow.implicitHeight
            contentWidth: Math.max(width, forecastRow.implicitWidth)
            contentHeight: height
            clip: true
            interactive: root.forecastOverflow
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            function clampPosition() {
                contentX = Math.max(0, Math.min(contentX, contentWidth - width))
            }
            onWidthChanged: clampPosition()
            onContentWidthChanged: clampPosition()
            RowLayout {
                id: forecastRow
                width: forecastViewport.contentWidth
                height: implicitHeight
                spacing: Tokens.spacing.small
                uniformCellSizes: true
                Repeater {
                    id: forecastDays
                    model: Math.min(Weather.dailyTime.length, 7)
                    ForecastCard {
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: implicitWidth
                        date: Weather.dailyTime[index] ?? ""
                        tempMax: Weather.dailyTempMax[index] ?? 0
                        tempMin: Weather.dailyTempMin[index] ?? 0
                        weatherCode: Weather.dailyWeatherCode[index] ?? 0
                        precipProbMax: Weather.dailyPrecipProbMax[index] ?? 0
                    }
                }
            }
        }
        ListItem {
            Layout.fillWidth: true
            visible: root.hasConditions
            headline: "Weather details"
            supportingText: "Wind, humidity, pressure and daylight"
            trailingIcon: root.detailsExpanded ? "expand_less" : "expand_more"
            Accessible.expanded: root.detailsExpanded
            onClicked: root.detailsExpanded = !root.detailsExpanded
        }
        CollapsibleContent {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: column.spacing
            expanded: root.hasConditions && root.detailsExpanded
            animated: GlobalStates.dashboardOpen
            sourceComponent: GridLayout {
                columns: width < Tokens.size.fieldWidth * 2 ? 1 : 2
                columnSpacing: Tokens.spacing.small
                rowSpacing: Tokens.spacing.small
                DetailCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    iconName: "air"
                    label: "Wind"
                    value: Math.round(Weather.windSpeed) + " " + Weather.windUnit
                    iconColor: Theme.onSurfaceVariant
                }
                DetailCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    iconName: "water_drop"
                    label: "Humidity"
                    value: Weather.humidity + "%"
                    iconColor: Theme.onSurfaceVariant
                }
                DetailCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    iconName: "compress"
                    label: "Pressure"
                    value: Math.round(Weather.pressure) + " hPa"
                    iconColor: Theme.onSurfaceVariant
                }
                DetailCard {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    iconName: "wb_twilight"
                    label: "Sunrise / sunset"
                    value: root.sunTime(Weather.dailySunrise) + " / " + root.sunTime(Weather.dailySunset)
                    iconColor: Theme.onSurfaceVariant
                }
            }
        }
    }
}
