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
        source: root.screen ? WallpaperManager.getWallpaper(root.screen.name) : ""
        fillMode: root.screen ? WallpaperManager.getFillMode(root.screen.name) : Image.PreserveAspectCrop

        // Decode off the UI thread and never above screen resolution — a 4K+
        // source otherwise freezes the shell for the full decode on every
        // wallpaper change (and caches at native size per screen).
        asynchronous: true
        // Keep the current texture until its asynchronously decoded replacement
        // is ready, instead of exposing the window's clear color between them.
        retainWhileLoading: true
        sourceSize.width: Math.max(1, root.screen?.width ?? 1)
        sourceSize.height: Math.max(1, root.screen?.height ?? 1)

        cache: true
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                console.warn(`Failed to load wallpaper for ${root.screen?.name ?? "disconnected"}: ${source}`)
            }
        }
    }
}
