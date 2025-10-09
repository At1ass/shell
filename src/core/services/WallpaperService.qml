pragma Singleton
import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

Singleton {
    id: wallpaperService

    property url currentWallpaper: Qt.resolvedUrl("/home/at1ass/wallpapers/stunning-anime-girl-with-bright-blue-eyes-7r-3440x1440.jpg")

    IpcHandler {
        target: "wallpaper"

        function setWallpaper(path: string): void {
            wallpaperService.currentWallpaper = Qt.resolvedUrl(path)
        }
    }
}
