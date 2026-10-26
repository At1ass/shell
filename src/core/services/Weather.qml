pragma Singleton
import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services

Singleton {
    id: store

    // --- Config ---
    property string location: AppConfig.weatherLocation
    property real latitude: AppConfig.weatherLatitude
    property real longitude: AppConfig.weatherLongitude
    property int refreshMinutes: AppConfig.weatherRefreshMinutes
    property int minIntervalSeconds: 60

    // --- State ---
    property var data: null
    property string errorString: ""
    property date lastSuccessAt: new Date(0)
    property date lastAttemptAt: new Date(0)
    property int _retryMs: 0

    // === Units ===
    readonly property bool isImperial: AppConfig.weatherUnits === "imperial"
    readonly property string tempUnit: isImperial ? "°F" : "°C"
    readonly property string windUnit: isImperial ? "mph" : "km/h"

    // Bypass the fetchNow rate limit: after a unit switch the displayed
    // numbers are in the WRONG unit until refetched.
    onIsImperialChanged: Qt.callLater(store._doFetch)
    onLatitudeChanged: Qt.callLater(store._doFetch)
    onLongitudeChanged: Qt.callLater(store._doFetch)

    readonly property bool _fetchAllowed: AppConfig.ready && AppConfig.weatherEnabled
        && !(GamingModeService.gamingModeActive && AppConfig.gmDisableWeather)
    on_FetchAllowedChanged: {
        if (!_fetchAllowed) {
            request.cancel()
            retryTimer.stop()
        } else {
            store.fetchIfStale()
        }
    }

    // === Current Weather ===
    readonly property real tempC: data?.current?.temperature_2m ?? 0
    readonly property real feelsLikeC: data?.current?.apparent_temperature ?? 0
    readonly property int humidity: data?.current?.relative_humidity_2m ?? 0
    readonly property real pressure: data?.current?.pressure_msl ?? 0
    readonly property real surfacePressure: data?.current?.surface_pressure ?? 0
    readonly property real windSpeed: data?.current?.wind_speed_10m ?? 0
    readonly property int windDirection: data?.current?.wind_direction_10m ?? 0
    readonly property real precipitation: data?.current?.precipitation ?? 0
    readonly property int cloudCover: data?.current?.cloud_cover ?? 0
    readonly property int weatherCode: data?.current?.weather_code ?? 0
    readonly property string weatherDesc: _weatherCodeToDesc(weatherCode)
    readonly property string icon: WeatherIcons.codeToName[weatherCode] || "cloud"
    // DateTime.clock is the reactive time source — a bare Date.now() would
    // freeze this at whatever it was on the last fetch attempt.
    readonly property bool isFresh: (DateTime.clock.date.getTime() - lastSuccessAt.getTime()) < (refreshMinutes * 60 * 1000)

    // === Daily Forecast (7 days) ===
    readonly property var dailyTime: data?.daily?.time || []
    readonly property var dailyTempMax: data?.daily?.temperature_2m_max || []
    readonly property var dailyTempMin: data?.daily?.temperature_2m_min || []
    readonly property var dailyWeatherCode: data?.daily?.weather_code || []
    readonly property var dailySunrise: data?.daily?.sunrise || []
    readonly property var dailySunset: data?.daily?.sunset || []
    readonly property var dailyPrecipSum: data?.daily?.precipitation_sum || []
    readonly property var dailyPrecipProbMax: data?.daily?.precipitation_probability_max || []
    readonly property var dailyWindSpeedMax: data?.daily?.wind_speed_10m_max || []

    signal updated()
    signal failed(string message)

    function _url() {
        var base = "https://api.open-meteo.com/v1/forecast";
        var params = [
            "latitude=" + latitude,
            "longitude=" + longitude,
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m",
            "hourly=temperature_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max",
            "timezone=auto",
            "forecast_days=7"
        ];
        if (isImperial) {
            params.push("temperature_unit=fahrenheit");
            params.push("wind_speed_unit=mph");
        }
        return base + "?" + params.join("&");
    }

    function _weatherCodeToDesc(code) {
        var descriptions = {
            0: "Clear sky",
            1: "Mainly clear",
            2: "Partly cloudy",
            3: "Overcast",
            45: "Foggy",
            48: "Depositing rime fog",
            51: "Light drizzle",
            53: "Moderate drizzle",
            55: "Dense drizzle",
            56: "Light freezing drizzle",
            57: "Dense freezing drizzle",
            61: "Slight rain",
            63: "Moderate rain",
            65: "Heavy rain",
            66: "Light freezing rain",
            67: "Heavy freezing rain",
            71: "Slight snow",
            73: "Moderate snow",
            75: "Heavy snow",
            77: "Snow grains",
            80: "Slight rain showers",
            81: "Moderate rain showers",
            82: "Violent rain showers",
            85: "Slight snow showers",
            86: "Heavy snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm with slight hail",
            99: "Thunderstorm with heavy hail"
        };
        return descriptions[code] || "Unknown";
    }

    // Periodic polling (fires immediately on start)
    Timer {
        id: periodic
        interval: store.refreshMinutes * 60 * 1000
        repeat: true
        running: store._fetchAllowed
        triggeredOnStart: true
        onTriggered: store.fetchIfStale()
    }

    // Exponential backoff timer
    Timer {
        id: retryTimer
        interval: store._retryMs
        repeat: false
        onTriggered: store._doFetch()
    }

    // Public methods
    function fetchIfStale() {
        if ((Date.now() - lastSuccessAt.getTime()) >= (refreshMinutes * 60 * 1000))
            _doFetch();
    }

    function fetchNow() {
        if ((Date.now() - lastAttemptAt.getTime()) < (minIntervalSeconds * 1000))
            return;
        _doFetch();
    }

    HttpRequest {
        id: request
        onSucceeded: body => {
            try {
                store.data = JSON.parse(body)
                store.lastSuccessAt = new Date()
                store._retryMs = 0
                retryTimer.stop()
                store.updated()
            } catch (e) {
                store._scheduleRetry("JSON parse error: " + e.message)
            }
        }
        onFailed: (message, status) => {
            if (status === 401 || status === 403) {
                store.errorString = message
                store.failed(message)
            } else {
                store._scheduleRetry(message)
            }
        }
    }

    function _doFetch() {
        if (!store._fetchAllowed) return
        retryTimer.stop()
        lastAttemptAt = new Date()
        errorString = ""
        request.get(_url())
    }

    function _scheduleRetry(msg) {
        errorString = msg;
        failed(msg);
        if (_retryMs === 0) ToastService.warning("Weather unavailable: " + msg)
        // 5s → 10s → 20s → … up to 5 minutes
        _retryMs = Math.min(_retryMs > 0 ? _retryMs * 2 : 5000, 5 * 60 * 1000);
        // No retry churn during gaming mode (the periodic poll is already
        // gated on it).
        if (store._fetchAllowed)
            retryTimer.start();
    }
}
