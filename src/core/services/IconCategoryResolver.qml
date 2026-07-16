import QtQuick
import Quickshell

pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Resolves Material Design Icons by application category
 * Adapted from Caelestia: utils/Icons.qml
 */
Singleton {
    id: root

    /**
     * Mapping of .desktop file categories to Material Icons
     * Adapted from ../caelestia/utils/Icons.qml
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
     * Get Material Icon for a window class by category
     * @param windowClass - window class from Hyprland (e.g. "Firefox", "code")
     * @param fallback - default icon
     * @return string - Material Icon name (e.g. "web", "code", "terminal")
     */
    function getAppCategoryIcon(windowClass, fallback) {
        if (!windowClass || windowClass.length === 0) {
            return fallback || "terminal"
        }

        // Try to find via Desktop Entry
        const entry = DesktopEntries.heuristicLookup(windowClass)

        if (entry && entry.categories) {
            // Iterate over all categories
            for (const [key, value] of Object.entries(categoryIcons)) {
                if (entry.categories.includes(key)) {
                    return value
                }
            }
        }

        // Fallback - return the default icon
        return fallback || "terminal"
    }

    /**
     * Get Material Icon for an array of categories
     * @param categories - category array from a .desktop file
     * @param fallback - default icon
     * @return string - Material Icon name
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
