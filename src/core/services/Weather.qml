pragma Singleton
import QtQuick
import Quickshell
import qs.src.core.config
import qs.src.core.services

Singleton {
    id: store

    // --- Конфиг ---
    property string location: Config.weather.location
    property int refreshMinutes: 15
    property int minIntervalSeconds: 60
    property string userAgent: "quickshell-weather/1.2 (+Qt/QML)"

    // --- Состояние ---
    property var data: null
    property string errorString: ""
    property date lastSuccessAt: new Date(0)
    property date lastAttemptAt: new Date(0)
    property string _etag: ""
    property int _retryMs: 0

    // Удобные «плоские» свойства
    readonly property string tempC: data?.current_condition?.[0].temp_C || ""
    readonly property string feelsLikeC: data?.current_condition?.[0]?.FeelsLikeC || ""
    readonly property string weatherDesc: data?.current_condition?.[0]?.weatherDesc[0]?.value || ""
    readonly property string iconUrl: data?.current_condition?.[0]?.weatherIconUrl[0]?.value || ""
    readonly property string icon: WeatherIcons.codeToName[data?.current_condition?.[0]?.weatherCode] || "cloud"
    readonly property bool isFresh: (Date.now() - lastSuccessAt.getTime()) < (refreshMinutes * 60 * 1000)

    signal updated()
    signal failed(string message)

    function _url() {
        var base = "https://wttr.in";
        return base + (location ? ("/" + encodeURIComponent(location)) : "") + "?format=j1";
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
        try {
            xhr.setRequestHeader("User-Agent", userAgent);
        } catch (e) {}
        if (_etag) {
            try {
                xhr.setRequestHeader("If-None-Match", _etag);
            } catch (e) {}
        }

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status === 304) {
                // не изменилось
                _retryMs = 0;
                updated();
                return;
            }

            if (xhr.status === 200) {
                try {
                    data = JSON.parse(xhr.responseText);
                    lastSuccessAt = new Date();
                    _retryMs = 0;
                    try {
                        store._etag = xhr.getResponseHeader("ETag") || store._etag;
                    } catch (e) {}
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
