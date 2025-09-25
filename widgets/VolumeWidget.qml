import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.components.base
import qs.components.tooltip
import qs.config

BarElement {
    id: root
    minWidth: 96
    clickable: true
    hoverable: true

    property var tooltipManager: null
    property bool mixerOpen: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var pipewireNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var sinkNodes: pipewireNodes ? pipewireNodes.filter(function(node) { return node && node.audio && node.isSink && !node.isStream }) : []
    readonly property var sourceNodes: pipewireNodes ? pipewireNodes.filter(function(node) { return node && node.audio && !node.isSink && !node.isStream }) : []
    readonly property var streamNodes: pipewireNodes ? pipewireNodes.filter(function(node) { return node && node.audio && node.isStream }) : []

    function formatVolume(value) {
        const numeric = Number(value)
        if (!isFinite(numeric) || numeric < 0) return "--%"
        const safe = Math.min(1, numeric)
        return Math.round(safe * 100) + "%"
    }

    nonVisualChildren: [
        PwObjectTracker {
            objects: root.sink ? [root.sink] : []
        },

        TooltipItem {
            id: mixerTooltip
            tooltip: root.tooltipManager
            owner: root
            isMenu: true
            animateSize: false
            show: root.mixerOpen
            preloadBackground: true

            backgroundComponent: Component {
                Rectangle {
                    radius: Config.shape.extraLarge
                    color: Config.colors.surfaceContainerHigh
                    border.color: Config.colors.outlineVariant
                }
            }

            onClose: root.mixerOpen = false

            ColumnLayout {
                implicitWidth: 200
                // width: 360
                spacing: Config.spacing.medium

                MaterialText {
                    text: qsTr("Аудио")
                    textStyle: "titleLarge"
                    colorRole: "surfaceText"
                }

                MaterialText {
                    text: qsTr("Управляйте громкостью системы, устройств и приложений")
                    textStyle: "bodyMedium"
                    colorRole: "surfaceVariantText"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(cardsColumn.implicitHeight, 460)
                    clip: true

                    Column {
                        id: cardsColumn
                        width: parent.width
                        spacing: Config.spacing.medium

                        MaterialCard {
                            width: parent.width

                            ColumnLayout {
                                spacing: Config.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    MaterialText {
                                        text: qsTr("Громкость системы")
                                        textStyle: "titleMedium"
                                        colorRole: "surfaceText"
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialButton {
                                        text: (root.sink && root.sink.audio && root.sink.audio.muted)
                                              ? qsTr("Включить звук")
                                              : qsTr("Выключить звук")
                                        variant: "tonal"
                                        enabled: root.sink && root.sink.audio
                                        onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    enabled: root.sink && root.sink.audio
                                    from: 0; to: 1; stepSize: 0.01
                                    value: (root.sink && root.sink.audio && isFinite(root.sink.audio.volume)) ? root.sink.audio.volume : 0
                                    onMoved: if (root.sink && root.sink.audio) root.sink.audio.volume = value
                                }

                                MaterialText {
                                    text: formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                }
                            }
                        }

                        MaterialCard {
                            width: parent.width

                            ColumnLayout {
                                spacing: Config.spacing.small
                                // Layout.fillWidth: true

                                MaterialText {
                                    text: qsTr("Выходы")
                                    textStyle: "titleMedium"
                                    colorRole: "surfaceText"
                                }

                                MaterialText {
                                    text: qsTr("Громкость и выключение устройств воспроизведения")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: root.sinkNodes
                                    delegate: ColumnLayout {
                                        required property var modelData
                                        property var node: modelData
                                        spacing: Config.spacing.extraSmall

                                        data: [
                                            PwObjectTracker {
                                                objects: node ? [node] : []
                                            }
                                        ]

                                        MaterialText {
                                            Layout.fillWidth: true
                                            text: node.description || node.name || qsTr("Выход")
                                            textStyle: "bodyMedium"
                                            colorRole: "surfaceText"
                                            wrapMode: Text.WordWrap
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Config.spacing.small

                                            MaterialCheckBox {
                                                text: qsTr("Mute")
                                                checked: !!(node.audio && node.audio.muted)
                                                enabled: !!node.audio
                                                onToggled: if (node.audio) node.audio.muted = checked
                                            }

                                            Item { Layout.fillWidth: true }

                                            MaterialText {
                                                text: formatVolume(node.audio ? node.audio.volume : null)
                                                textStyle: "bodySmall"
                                                colorRole: "surfaceVariantText"
                                            }
                                        }

                                        Slider {
                                            Layout.fillWidth: true
                                            enabled: !!node.audio
                                            from: 0; to: 1; stepSize: 0.01
                                            value: (node.audio && isFinite(node.audio.volume)) ? node.audio.volume : 0
                                            onMoved: if (node.audio) node.audio.volume = value
                                        }
                                    }
                                }

                                MaterialText {
                                    visible: root.sinkNodes.length === 0
                                    text: qsTr("Нет выходных устройств")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                }
                            }
                        }

                        MaterialCard {
                            width: parent.width

                            ColumnLayout {
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: qsTr("Входы")
                                    textStyle: "titleMedium"
                                    colorRole: "surfaceText"
                                }

                                MaterialText {
                                    text: qsTr("Настройка микрофонов и других источников")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: root.sourceNodes
                                    delegate: ColumnLayout {
                                        required property var modelData
                                        property var node: modelData
                                        spacing: Config.spacing.extraSmall

                                        data: [
                                            PwObjectTracker {
                                                objects: node ? [node] : []
                                            }
                                        ]

                                        MaterialText {
                                            Layout.fillWidth: true
                                            text: node.description || node.name || qsTr("Вход")
                                            textStyle: "bodyMedium"
                                            colorRole: "surfaceText"
                                            wrapMode: Text.WordWrap
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Config.spacing.small

                                            MaterialCheckBox {
                                                text: qsTr("Mute")
                                                checked: !!(node.audio && node.audio.muted)
                                                enabled: !!node.audio
                                                onToggled: if (node.audio) node.audio.muted = checked
                                            }

                                            Item { Layout.fillWidth: true }

                                            MaterialText {
                                                text: formatVolume(node.audio ? node.audio.volume : null)
                                                textStyle: "bodySmall"
                                                colorRole: "surfaceVariantText"
                                            }
                                        }

                                        Slider {
                                            Layout.fillWidth: true
                                            enabled: !!node.audio
                                            from: 0; to: 1; stepSize: 0.01
                                            value: (node.audio && isFinite(node.audio.volume)) ? node.audio.volume : 0
                                            onMoved: if (node.audio) node.audio.volume = value
                                        }
                                    }
                                }

                                MaterialText {
                                    visible: root.sourceNodes.length === 0
                                    text: qsTr("Нет входных устройств")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                }
                            }
                        }

                        MaterialCard {
                            width: parent.width

                            ColumnLayout {
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: qsTr("Приложения")
                                    textStyle: "titleMedium"
                                    colorRole: "surfaceText"
                                }

                                MaterialText {
                                    text: qsTr("Контролируйте активные аудиопотоки и их громкость")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: root.streamNodes
                                    delegate: ColumnLayout {
                                        required property var modelData
                                        property var stream: modelData
                                        spacing: Config.spacing.extraSmall
                                        visible: !!stream

                                        data: [
                                            PwObjectTracker {
                                                objects: stream ? [stream] : []
                                            }
                                        ]

                                        MaterialText {
                                            Layout.fillWidth: true
                                            text: stream && stream.properties && stream.properties["application.name"]
                                                  ? stream.properties["application.name"]
                                                  : (stream.appName || stream.name || stream.clientName || qsTr("Приложение"))
                                            textStyle: "bodyMedium"
                                            colorRole: "surfaceText"
                                            wrapMode: Text.WordWrap
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Config.spacing.small

                                            MaterialCheckBox {
                                                text: qsTr("Mute")
                                                checked: !!(stream.audio && stream.audio.muted)
                                                enabled: !!(stream.audio)
                                                onToggled: if (stream.audio) stream.audio.muted = checked
                                            }

                                            Item { Layout.fillWidth: true }

                                            MaterialText {
                                                text: formatVolume(stream.audio ? stream.audio.volume : null)
                                                textStyle: "bodySmall"
                                                colorRole: "surfaceVariantText"
                                            }
                                        }

                                        Slider {
                                            Layout.fillWidth: true
                                            enabled: !!(stream.audio)
                                            from: 0; to: 1; stepSize: 0.01
                                            value: (stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                            onMoved: if (stream.audio) stream.audio.volume = value
                                        }
                                    }
                                }

                                MaterialText {
                                    visible: root.streamNodes.length === 0
                                    text: qsTr("Нет активных аудиопотоков")
                                    textStyle: "bodySmall"
                                    colorRole: "surfaceVariantText"
                                }
                            }
                        }
                    }
                }
            }
        }
    ]

    wheelHandler: function(event) {
        if (!root.sink || !root.sink.audio) {
            event.accepted = false
            return
        }

        event.accepted = true
        const step = (event.angleDelta.y / 120) * 0.04
        const current = (root.sink.audio.volume !== undefined) ? root.sink.audio.volume : 0
        root.sink.audio.volume = Math.max(0, Math.min(1, current + step))
    }

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
            if (!root.sink || !root.sink.audio) {
                mouse.accepted = false
                return
            }

            mouse.accepted = true
            root.sink.audio.muted = !root.sink.audio.muted
            root.mixerOpen = false
            return
        }

        if (mouse.button === Qt.RightButton) {
            root.mixerOpen = !root.mixerOpen
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    Row {
        // anchors.centerIn: parent
        spacing: Config.spacing.small

        Image {
            source: {
                if (!root.sink || !root.sink.audio) return "image://icon/audio-volume-muted-symbolic"
                if (root.sink.audio.muted || root.sink.audio.volume <= 0.001) return "image://icon/audio-volume-muted-symbolic"
                const v = root.sink.audio.volume
                return "image://icon/" + (v < 0.34 ? "audio-volume-low-symbolic"
                    : v < 0.67 ? "audio-volume-medium-symbolic"
                    : "audio-volume-high-symbolic")
            }
            sourceSize.width: 18
            sourceSize.height: 18
        }

        MaterialText {
            text: formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
            textStyle: "bodyMedium"
            colorRole: "surfaceText"
        }
    }
}
