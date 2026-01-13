pragma Singleton

import Quickshell

Singleton {
    // WMO Weather interpretation codes (Open-Meteo)
    // https://open-meteo.com/en/docs
    readonly property var codeToName: ({
            0: "clear_day",           // Clear sky
            1: "clear_day",           // Mainly clear
            2: "partly_cloudy_day",   // Partly cloudy
            3: "cloud",               // Overcast
            45: "foggy",              // Fog
            48: "foggy",              // Depositing rime fog
            51: "rainy",              // Drizzle: Light
            53: "rainy",              // Drizzle: Moderate
            55: "rainy",              // Drizzle: Dense
            56: "rainy",              // Freezing Drizzle: Light
            57: "rainy",              // Freezing Drizzle: Dense
            61: "rainy",              // Rain: Slight
            63: "rainy",              // Rain: Moderate
            65: "rainy",              // Rain: Heavy
            66: "weather_hail",       // Freezing Rain: Light
            67: "weather_hail",       // Freezing Rain: Heavy
            71: "cloudy_snowing",     // Snow fall: Slight
            73: "snowing",            // Snow fall: Moderate
            75: "snowing_heavy",      // Snow fall: Heavy
            77: "snowing",            // Snow grains
            80: "rainy",              // Rain showers: Slight
            81: "rainy",              // Rain showers: Moderate
            82: "rainy",              // Rain showers: Violent
            85: "cloudy_snowing",     // Snow showers: Slight
            86: "snowing_heavy",      // Snow showers: Heavy
            95: "thunderstorm",       // Thunderstorm
            96: "thunderstorm",       // Thunderstorm with slight hail
            99: "thunderstorm"        // Thunderstorm with heavy hail
        })
}

