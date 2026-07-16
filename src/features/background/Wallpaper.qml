import QtQuick
import Quickshell
import qs.src.core.services

Item {
    id: root

    required property ShellScreen screen

    Image {
        id: image
        anchors.fill: parent

        // Pure bindings: getWallpaper/getFillMode read the monitorWallpapers/
        // monitorBindings maps, which WallpaperManager reassigns wholesale on
        // every change — the bindings re-evaluate on their own. No imperative
        // Connections here: a single `image.source = ...` write would sever
        // the binding permanently.
        source: WallpaperManager.getWallpaper(root.screen.name)
        fillMode: WallpaperManager.getFillMode(root.screen.name)

        // Decode off the UI thread and never above screen resolution — a 4K+
        // source otherwise freezes the shell for the full decode on every
        // wallpaper change (and caches at native size per screen).
        asynchronous: true
        sourceSize.width: root.screen.width
        sourceSize.height: root.screen.height

        cache: true
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                console.warn(`Failed to load wallpaper for ${root.screen.name}: ${source}`)
            }
        }
    }
}
