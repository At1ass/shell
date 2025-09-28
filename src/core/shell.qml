import QtQuick
import Quickshell
import qs.src.core.services
import qs.src.features.statusbar
import qs.src.features.mediaControls
import qs.src.features.controlPanel

ShellRoot {
    Variants {
        model: Quickshell.screens

        StatusBar {}
    }

    // Медиа контроллер (загружается только при необходимости)
    LazyLoader {
        active: true  // Всегда активен для быстрого отклика
        component: MediaControls {}
    }

    // Системная панель управления (загружается только при необходимости)
    LazyLoader {
        active: true  // Всегда активен для быстрого отклика
        component: ControlPanel {}
    }

    // Инициализация GlobalStates через Timer для отложенного запуска
    Timer {
        interval: 100
        running: true
        onTriggered: {
            console.log("GlobalStates initialized:", GlobalStates)
        }
    }
}
