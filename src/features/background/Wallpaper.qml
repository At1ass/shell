import QtQuick
import Quickshell
import qs.src.core.services

Item {
	id: root

	// ═══════════════════════════════════════════════════════════════
	// PROPERTIES
	// ═══════════════════════════════════════════════════════════════

	required property ShellScreen screen

	// Async loading for better performance
	property alias asynchronous: image.asynchronous

	// Cache for faster reloading
	property bool cache: true

	// Smooth scaling for better quality
	property bool smooth: true

	// ═══════════════════════════════════════════════════════════════
	// IMAGE
	// ═══════════════════════════════════════════════════════════════

	Image {
		id: image
		anchors.fill: parent

		// Get wallpaper specific to this monitor
		source: WallpaperService.getWallpaper(screen.name)

		// Fill mode specific to this monitor
		// 0 = Stretch
		// 1 = PreserveAspectFit (fit with black bars)
		// 2 = PreserveAspectCrop (fill, crop edges)
		// 3 = Tile
		// 4 = TileVertically
		// 5 = TileHorizontally
		// 6 = Pad
		fillMode: WallpaperService.getFillMode(screen.name)

		// Async loading to prevent UI blocking
		asynchronous: root.asynchronous

		// Cache for better performance
		cache: root.cache

		// Smooth scaling for better quality
		smooth: root.smooth

		// Status monitoring
		onStatusChanged: {
			if (status === Image.Error) {
				console.error(`Failed to load wallpaper for ${screen.name}: ${source}`)
			} else if (status === Image.Ready) {
				console.log(`Wallpaper loaded for ${screen.name}: ${source}`)
			}
		}
        // Behavior on source {
        //     SequentialAnimation {
        //         NumberAnimation {
        //             target: image
        //             property: "opacity"
        //             to: 0
        //             duration: 200
        //         }
        //         PropertyAction { property: "source" }
        //         NumberAnimation {
        //             target: image
        //             property: "opacity"
        //             to: 1
        //             duration: 200
        //         }
        //     }
        // }
	}

	// ═══════════════════════════════════════════════════════════════
	// CONNECTIONS
	// ═══════════════════════════════════════════════════════════════

	Connections {
		target: WallpaperService

		// React to wallpaper changes
		function onMonitorWallpapersChanged() {
			image.source = WallpaperService.getWallpaper(screen.name)
		}

		// React to fill mode changes
		function onMonitorFillModesChanged() {
			image.fillMode = WallpaperService.getFillMode(screen.name)
		}
	}
}
