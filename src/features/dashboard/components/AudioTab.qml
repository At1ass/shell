import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Pipewire
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.ui.feedback
import qs.src.core.config

Item {
    id: root

    readonly property var pipewireNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var sinkNodes: pipewireNodes.filter(node => node && node.audio && node.isSink && !node.isStream)
    readonly property var sourceNodes: pipewireNodes.filter(node => node && node.audio && !node.isSink && !node.isStream)
    readonly property var streamNodes: pipewireNodes.filter(node => node && node.audio && node.isStream)

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    function formatVolume(value) {
        const numeric = Number(value)
        if (!isFinite(numeric) || numeric < 0) return "--"
        return Math.round(Math.min(1, numeric) * 100)
    }

    function getAppIcon(stream) {
        if (!stream || !stream.properties) return ""

        // Try different property keys for application name
        const appName = stream.properties["application.name"] ||
                       stream.properties["application.process.binary"] ||
                       stream.properties["pipewire.access.portal.app_id"]

        if (!appName) return ""

        // Try to find desktop entry
        const entry = DesktopEntries.heuristicLookup(appName)
        if (entry && entry.icon) {
            return Quickshell.iconPath(entry.icon)
        }

        return ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.large
        spacing: Config.spacing.large

        // Выбор устройств (MD3)
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.medium

            // Устройство вывода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sinkMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.surfaceContainerHigh
                radius: Config.shape.large

                Behavior on color {
                    ColorAnimation { duration: Config.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: Config.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sinkMouseArea.containsMouse ? Config.colors.onSecondaryContainer : Config.colors.primaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "volume_up"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: sinkMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: "Output Device"
                            textStyle: "labelLarge"
                            colorRole: "onSurfaceVariant"
                            font.weight: Font.Medium
                        }

                        MaterialText {
                            text: root.defaultSink ? (root.defaultSink.description || root.defaultSink.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Config.typography.headlineSmall.size
                        iconColor: Config.colors.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sinkMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sinkDialog.open(root.sinkNodes, root.defaultSink, "Select Output Device", "output")
                    }
                }
            }

            // Устройство ввода
            MaterialCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: sourceMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.surfaceContainerHigh
                radius: Config.shape.large

                Behavior on color {
                    ColorAnimation { duration: Config.motion.duration.short4 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium
                    spacing: Config.spacing.medium

                    // Icon container
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: sourceMouseArea.containsMouse ? Config.colors.onSecondaryContainer : Config.colors.tertiaryContainer

                        Behavior on color {
                            ColorAnimation { duration: Config.motion.duration.short4 }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            iconName: "mic"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: sourceMouseArea.containsMouse ? Config.colors.secondaryContainer : Config.colors.onTertiaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialText {
                            text: "Input Device"
                            textStyle: "labelLarge"
                            colorRole: "onSurfaceVariant"
                            font.weight: Font.Medium
                        }

                        MaterialText {
                            text: root.defaultSource ? (root.defaultSource.description || root.defaultSource.name || "Unknown") : "No device"
                            textStyle: "bodyMedium"
                            colorRole: "onSurface"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MaterialIcon {
                        iconName: "chevron_right"
                        fontSize: Config.typography.headlineSmall.size
                        iconColor: Config.colors.onSurfaceVariant
                        backgroundColor: "transparent"
                    }
                }

                MouseArea {
                    id: sourceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sourceDialog.open(root.sourceNodes, root.defaultSource, "Select Input Device", "input")
                    }
                }
            }
        }

        // Микшер приложений
        MaterialCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.large

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.large
                spacing: Config.spacing.medium

                // Header (MD3)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.small

                    MaterialIcon {
                        iconName: "graphic_eq"
                        fontSize: Config.typography.titleLarge.size
                        iconColor: Config.colors.primary
                        backgroundColor: "transparent"
                    }

                    MaterialText {
                        text: "Application Volume Mixer"
                        textStyle: "titleLarge"
                        colorRole: "onSurface"
                        font.weight: Font.Medium
                    }

                    Item { Layout.fillWidth: true }

                    // Stream count badge
                    Rectangle {
                        visible: root.streamNodes.length > 0
                        width: badgeText.width + 16
                        height: 24
                        radius: 12
                        color: Config.colors.primaryContainer

                        MaterialText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: root.streamNodes.length.toString()
                            textStyle: "labelMedium"
                            colorRole: "onPrimaryContainer"
                            font.weight: Font.Bold
                        }
                    }
                }

                // ScrollView для списка приложений
                ScrollView {
                    id: scrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: scrollView.availableWidth
                        spacing: Config.spacing.medium

                        Repeater {
                            model: root.streamNodes

                            delegate: MaterialCard {
                                required property var modelData
                                property var stream: modelData
                                property string appIcon: root.getAppIcon(stream)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 110
                                color: Config.colors.surfaceContainer
                                radius: Config.shape.medium

                                data: [
                                    PwObjectTracker {
                                        objects: stream ? [stream] : []
                                    }
                                ]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Config.spacing.medium
                                    spacing: Config.spacing.medium

                                    // App icon (real or fallback)
                                    Item {
                                        width: 48
                                        height: 48

                                        // Real icon
                                        Image {
                                            id: appIconImage
                                            anchors.fill: parent
                                            source: appIcon
                                            sourceSize.width: 48
                                            sourceSize.height: 48
                                            fillMode: Image.PreserveAspectFit
                                            visible: appIcon !== ""
                                            smooth: true
                                            cache: true

                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: 48
                                                    height: 48
                                                    radius: 24
                                                }
                                            }
                                        }

                                        // Fallback with initials
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 24
                                            visible: appIcon === ""
                                            color: Config.colors.primaryContainer

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: stream && stream.properties && stream.properties["application.name"] ?
                                                      stream.properties["application.name"].substring(0, 2).toUpperCase() :
                                                      "AP"
                                                textStyle: "titleMedium"
                                                colorRole: "onPrimaryContainer"
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    // Name and slider
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.spacing.small

                                        MaterialText {
                                            text: stream && stream.properties && stream.properties["application.name"] ?
                                                  stream.properties["application.name"] :
                                                  (stream.appName || stream.name || stream.clientName || "Application")
                                            textStyle: "titleSmall"
                                            colorRole: "onSurface"
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        MaterialSlider {
                                            Layout.fillWidth: true
                                            enabled: !!(stream && stream.audio)
                                            from: 0
                                            to: 1
                                            stepSize: 0.01
                                            value: (stream && stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                            onMoved: if (stream && stream.audio)
                                                stream.audio.volume = value
                                        }
                                    }

                                    // Volume percentage
                                    MaterialText {
                                        text: root.formatVolume(stream && stream.audio ? stream.audio.volume : null) + "%"
                                        textStyle: "labelLarge"
                                        colorRole: "onSurfaceVariant"
                                        font.weight: Font.Medium
                                        Layout.preferredWidth: 48
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // Mute button (MD3 IconButton style)
                                    Rectangle {
                                        width: 48
                                        height: 48
                                        radius: 24
                                        color: (stream && stream.audio && stream.audio.muted) ?
                                               Config.colors.errorContainer :
                                               (muteMouseArea.containsMouse ? Config.colors.surfaceContainerHighest : "transparent")

                                        Behavior on color {
                                            ColorAnimation { duration: Config.motion.duration.short4 }
                                        }

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            iconName: (stream && stream.audio && stream.audio.muted) ? "volume_off" : "volume_up"
                                            fontSize: Config.typography.titleLarge.size
                                            iconColor: (stream && stream.audio && stream.audio.muted) ?
                                                      Config.colors.onErrorContainer :
                                                      Config.colors.onSurfaceVariant
                                            backgroundColor: "transparent"

                                            Behavior on iconColor {
                                                ColorAnimation { duration: Config.motion.duration.short4 }
                                            }
                                        }

                                        MouseArea {
                                            id: muteMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !!(stream && stream.audio)
                                            onClicked: if (stream && stream.audio)
                                                stream.audio.muted = !stream.audio.muted
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state (MD3)
                        Item {
                            visible: root.streamNodes.length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Config.spacing.medium

                                // Icon container
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: Config.colors.surfaceContainerHighest
                                    Layout.alignment: Qt.AlignHCenter

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        iconName: "music_off"
                                        fontSize: Config.typography.displaySmall.size
                                        iconColor: Config.colors.onSurfaceVariant
                                        backgroundColor: "transparent"
                                        opacity: 0.6
                                    }
                                }

                                ColumnLayout {
                                    spacing: Config.spacing.extraSmall
                                    Layout.alignment: Qt.AlignHCenter

                                    MaterialText {
                                        text: "No active audio streams"
                                        textStyle: "titleMedium"
                                        colorRole: "onSurface"
                                        font.weight: Font.Medium
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    MaterialText {
                                        text: "Play something to see it here"
                                        textStyle: "bodyMedium"
                                        colorRole: "onSurfaceVariant"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Кнопка pavucontrol (MD3 Filled Button)
                MaterialCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Config.shape.full
                    color: pavuMouseArea.pressed ? Config.colors.primary :
                           pavuMouseArea.containsMouse ? Qt.lighter(Config.colors.primaryContainer, 1.1) :
                           Config.colors.primaryContainer

                    // Elevation
                    layer.enabled: pavuMouseArea.containsMouse
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 2
                        radius: 4
                        samples: 9
                        color: Qt.rgba(0, 0, 0, 0.15)
                    }

                    Behavior on color {
                        ColorAnimation { duration: Config.motion.duration.short4 }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Config.spacing.small

                        MaterialIcon {
                            iconName: "tune"
                            fontSize: Config.typography.titleLarge.size
                            iconColor: pavuMouseArea.pressed ? Config.colors.onPrimary : Config.colors.onPrimaryContainer
                            backgroundColor: "transparent"

                            Behavior on iconColor {
                                ColorAnimation { duration: Config.motion.duration.short4 }
                            }
                        }

                        MaterialText {
                            text: "Advanced Audio Settings"
                            textStyle: "labelLarge"
                            colorRole: pavuMouseArea.pressed ? "onPrimary" : "onPrimaryContainer"
                            font.weight: Font.Medium
                        }
                    }

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        // radius: parent.radius
                        radius: Config.shape.full
                        color: Config.colors.onPrimaryContainer
                        opacity: pavuMouseArea.pressed ? 0.12 : (pavuMouseArea.containsMouse ? 0.08 : 0)

                        Behavior on opacity {
                            NumberAnimation { duration: Config.motion.duration.short4 }
                        }
                    }

                    MouseArea {
                        id: pavuMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Launch pavucontrol
                            Qt.openUrlExternally("pavucontrol")
                        }
                    }
                }
            }
        }
    }

    // Device Selection Dialogs
    DeviceSelectionDialog {
        id: sinkDialog
        anchors.fill: parent

        onDeviceSelected: (device) => {
            Pipewire.preferredDefaultAudioSink = device
        }
    }

    DeviceSelectionDialog {
        id: sourceDialog
        anchors.fill: parent

        onDeviceSelected: (device) => {
            Pipewire.preferredDefaultAudioSource = device
        }
    }
}
