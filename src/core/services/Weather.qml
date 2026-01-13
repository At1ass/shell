pragma Singleton
import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services

Singleton {
    id: store

    // --- Конфиг ---
    property string location: Config.weather.location
    property real latitude: 53.2  // Пенза по умолчанию
    property real longitude: 45.0
    property int refreshMinutes: 15
    property int minIntervalSeconds: 60

    // --- Состояние ---
    property var data: null
    property string errorString: ""
    property date lastSuccessAt: new Date(0)
    property date lastAttemptAt: new Date(0)
    property int _retryMs: 0

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
    readonly property bool isFresh: (Date.now() - lastSuccessAt.getTime()) < (refreshMinutes * 60 * 1000)

    // === Hourly Forecast (next 24 hours) ===
    readonly property var hourlyTime: data?.hourly?.time || []
    readonly property var hourlyTemp: data?.hourly?.temperature_2m || []
    readonly property var hourlyPrecipProb: data?.hourly?.precipitation_probability || []
    readonly property var hourlyPrecip: data?.hourly?.precipitation || []
    readonly property var hourlyWeatherCode: data?.hourly?.weather_code || []
    readonly property var hourlyWindSpeed: data?.hourly?.wind_speed_10m || []

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

    // Периодический опрос (стартует сразу)
    Timer {
        id: periodic
        interval: store.refreshMinutes * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: store.fetchIfStale()
    }

    // Таймер экспоненциального бэкоффа
    Timer {
        id: retryTimer
        interval: store._retryMs
        repeat: false
        onTriggered: store._doFetch()
    }

    // Публичные методы
    function fetchIfStale() {
        if ((Date.now() - lastSuccessAt.getTime()) >= (refreshMinutes * 60 * 1000))
            _doFetch();
    }

    function fetchNow() {
        if ((Date.now() - lastAttemptAt.getTime()) < (minIntervalSeconds * 1000))
            return;
        _doFetch();
    }

    function _doFetch() {
        lastAttemptAt = new Date();
        errorString = "";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", _url());

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                    lastSuccessAt = new Date();
                    _retryMs = 0;
                    updated();
                } catch (e) {
                    _scheduleRetry("JSON parse error: " + e);
                }
            } else {
                _scheduleRetry("HTTP " + xhr.status + " — " + xhr.statusText);
            }
        };

        xhr.onerror = function () {
            _scheduleRetry("Network error");
        };
        xhr.send();
    }

    function _scheduleRetry(msg) {
        errorString = msg;
        failed(msg);
        // 5s → 10s → 20s → … до 5 минут
        _retryMs = Math.min(_retryMs > 0 ? _retryMs * 2 : 5000, 5 * 60 * 1000);
        if (!retryTimer.running)
            retryTimer.start();
    }
    // }
}
