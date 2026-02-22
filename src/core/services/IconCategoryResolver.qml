import QtQuick
import Quickshell

pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Определение Material Design Icons по категориям приложений
 * Взято из Caelestia: utils/Icons.qml
 */
Singleton {
    id: root

    /**
     * Маппинг категорий .desktop файлов на Material Icons
     * Взято из ../caelestia/utils/Icons.qml
     */
    readonly property var categoryIcons: ({
        WebBrowser: "web",
        Printing: "print",
        Security: "security",
        Network: "chat",
        Archiving: "archive",
        Compression: "archive",
        Development: "code",
        IDE: "code",
        TextEditor: "edit_note",
        Audio: "music_note",
        Music: "music_note",
        Player: "music_note",
        Recorder: "mic",
        Game: "sports_esports",
        FileTools: "folder",
        FileManager: "folder",
        Filesystem: "folder",
        FileTransfer: "folder",
        Settings: "settings",
        DesktopSettings: "settings",
        HardwareSettings: "settings",
        TerminalEmulator: "terminal",
        ConsoleOnly: "terminal",
        Utility: "build",
        Monitor: "monitor_heart",
        Midi: "graphic_eq",
        Mixer: "graphic_eq",
        AudioVideoEditing: "video_settings",
        AudioVideo: "music_video",
        Video: "videocam",
        Building: "construction",
        Graphics: "photo_library",
        "2DGraphics": "photo_library",
        RasterGraphics: "photo_library",
        TV: "tv",
        System: "dns",
        Office: "description",
        Email: "mail",
        Calendar: "event",
        ContactManagement: "contacts"
    })

    /**
     * Получить Material Icon для класса окна по категории
     * @param windowClass - класс окна из Hyprland (например "Firefox", "code")
     * @param fallback - иконка по умолчанию
     * @return string - название Material Icon (например "web", "code", "terminal")
     */
    function getAppCategoryIcon(windowClass, fallback) {
        if (!windowClass || windowClass.length === 0) {
            return fallback || "terminal"
        }

        // Попытка найти через Desktop Entry
        const entry = DesktopEntries.heuristicLookup(windowClass)

        if (entry && entry.categories) {
            // Проходим по всем категориям
            for (const [key, value] of Object.entries(categoryIcons)) {
                if (entry.categories.includes(key)) {
                    return value
                }
            }
        }

        // Fallback - возвращаем иконку по умолчанию
        return fallback || "terminal"
    }

    /**
     * Получить Material Icon для массива категорий
     * @param categories - массив категорий из .desktop файла
     * @param fallback - иконка по умолчанию
     * @return string - название Material Icon
     */
    function getCategoryIcon(categories, fallback) {
        if (!categories || categories.length === 0) {
            return fallback || "terminal"
        }

        for (const [key, value] of Object.entries(categoryIcons)) {
            if (categories.includes(key)) {
                return value
            }
        }

        return fallback || "terminal"
    }
}
