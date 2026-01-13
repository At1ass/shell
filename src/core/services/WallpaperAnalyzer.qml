// pragma Singleton

import QtQuick
import Quickshell
import qs.src.core.services

Singleton {
    id: root

    property url source: WallpaperService.currentWallpaper
    property real luminance: 0.5
    property real fallbackLuminance: 0.5
    property int sampleSize: 32

    Image {
        id: sampleImage

        asynchronous: true
        cache: false
        source: root.source
        visible: false

        onStatusChanged: {
            if (status === Image.Ready) {
                sampleCanvas.requestPaint()
            } else if (status === Image.Error) {
                root.luminance = root.fallbackLuminance
            }
        }
    }

    Canvas {
        id: sampleCanvas

        width: root.sampleSize
        height: root.sampleSize
        visible: false

        onPaint: {
            if (sampleImage.status !== Image.Ready) {
                return
            }

            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(sampleImage, 0, 0, width, height)

            const data = ctx.getImageData(0, 0, width, height).data
            let sum = 0.0
            let count = 0

            for (let i = 0; i < data.length; i += 4) {
                const a = data[i + 3] / 255.0
                if (a === 0) {
                    continue
                }

                const r = data[i] / 255.0
                const g = data[i + 1] / 255.0
                const b = data[i + 2] / 255.0
                const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                sum += lum
                count += 1
            }

            root.luminance = count > 0 ? (sum / count) : root.fallbackLuminance
        }
    }

    onSourceChanged: {
        if (!root.source) {
            root.luminance = root.fallbackLuminance
        }
    }
}
