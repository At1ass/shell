import QtQuick
import Quickshell
import qs.src.features.controlPanel
import qs.src.features.dashboard
import qs.src.features.mediaControls
import qs.src.features.statusbar as Bar

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar.StatusBar {}
    }

    // Медиа контроллер (загружается только при необходимости)
    LazyLoader {
        active: true // Всегда активен для быстрого отклика

        component: MediaControls {}
    }

    // Системная панель управления (загружается только при необходимости)
    LazyLoader {
        active: true // Всегда активен для быстрого отклика

        component: ControlPanel {}
    }

    LazyLoader {
        active: true // Всегда активен для быстрого отклика

        component: Dashboard {}
    }
}
