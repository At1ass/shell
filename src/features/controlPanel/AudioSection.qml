import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.src.ui.base
import qs.src.core.config

MaterialCard {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var pipewireNodes: (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : []
    readonly property var sinkNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && node.isSink && !node.isStream;
    }) : []
    readonly property var sourceNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && !node.isSink && !node.isStream;
    }) : []
    readonly property var streamNodes: pipewireNodes ? pipewireNodes.filter(function (node) {
        return node && node.audio && node.isStream;
    }) : []

    function formatVolume(value) {
        const numeric = Number(value);
        if (!isFinite(numeric) || numeric < 0)
            return "--%";
        const safe = Math.min(1, numeric);
        return Math.round(safe * 100) + "%";
    }

    contentWidth: rootLayout.implicitWidth
    contentHeight: 600

    ColumnLayout {
        id: rootLayout
        spacing: Config.spacing.medium
        anchors.fill: parent

        // Заголовок секции
        MaterialText {
            text: qsTr("Аудио")
            textStyle: "titleLarge"
            colorRole: "onSurface"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }

        MaterialText {
            text: qsTr("Управляйте громкостью системы, устройств и приложений")
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }

        ScrollView {
            id: sc
            Layout.fillWidth: true
            // anchors.fill: parent

            Layout.fillHeight: true
            clip: true

            contentWidth: sc.availableWidth

            ColumnLayout {
                id: audioColumn
                Layout.fillWidth: true
                spacing: Config.spacing.medium

                // Громкость системы
                MaterialCard {
                    // Layout.fillWidth: true
                    contentWidth: sc.width - 2 * Config.spacing.medium
                    Layout.alignment: Qt.AlignHCenter

                    ColumnLayout {
                        id: systemVolumeColumn
                        width: parent.width
                        spacing: Config.spacing.small

                        RowLayout {
                            spacing: Config.spacing.small
                            Layout.fillWidth: true

                            MaterialText {
                                text: qsTr("Громкость системы")
                                textStyle: "titleMedium"
                                colorRole: "onSurface"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            MaterialButton {
                                text: (root.sink && root.sink.audio && root.sink.audio.muted) ? qsTr("Включить звук") : qsTr("Выключить звук")
                                variant: (root.sink && root.sink.audio && root.sink.audio.muted) ? "filled" : "tonal"
                                enabled: root.sink && root.sink.audio
                                onClicked: if (root.sink && root.sink.audio)
                                    root.sink.audio.muted = !root.sink.audio.muted
                            }
                        }

                        MaterialSlider {
                            Layout.fillWidth: true
                            enabled: root.sink && root.sink.audio
                            from: 0
                            to: 1
                            stepSize: 0.01
                            value: (root.sink && root.sink.audio && isFinite(root.sink.audio.volume)) ? root.sink.audio.volume : 0
                            onMoved: if (root.sink && root.sink.audio)
                                root.sink.audio.volume = value
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }

                            MaterialText {
                                text: formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
                                textStyle: "bodySmall"
                                colorRole: "onSurfaceVariant"
                            }
                        }
                    }
                }

                // Выходы
                MaterialCard {
                    contentWidth: sc.width - 2 * Config.spacing.medium
                    Layout.alignment: Qt.AlignHCenter

                    ColumnLayout {
                        width: parent.width
                        spacing: Config.spacing.small

                        MaterialText {
                            text: qsTr("Выходы")
                            textStyle: "titleMedium"
                            colorRole: "onSurface"
                        }

                        MaterialText {
                            text: qsTr("Громкость и выключение устройств воспроизведения")
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
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
                                    colorRole: "onSurface"
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    MaterialButton {
                                        text: (node.audio && node.audio.muted) ? qsTr("Включить") : qsTr("Выключить")
                                        variant: (node.audio && node.audio.muted) ? "filled" : "outlined"
                                        enabled: !!node.audio
                                        onClicked: if (node.audio)
                                            node.audio.muted = !node.audio.muted
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MaterialButton {
                                        text: node.id === root.sink?.id ? qsTr("Активный") : qsTr("Сделать активным")
                                        variant: node.id === root.sink?.id ? "filled" : "tonal"
                                        enabled: node.id !== root.sink?.id
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSink = node
                                        }
                                    }
                                }

                                MaterialSlider {
                                    Layout.fillWidth: true
                                    enabled: !!node.audio
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: (node.audio && isFinite(node.audio.volume)) ? node.audio.volume : 0
                                    onMoved: if (node.audio)
                                        node.audio.volume = value
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MaterialText {
                                        text: formatVolume(node.audio ? node.audio.volume : null)
                                        textStyle: "bodySmall"
                                        colorRole: "onSurfaceVariant"
                                    }
                                }
                            }
                        }

                        MaterialText {
                            visible: root.sinkNodes.length === 0
                            text: qsTr("Нет выходных устройств")
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
                        }
                    }
                }

                // Приложения (стримы)
                MaterialCard {
                    contentWidth: sc.width - 2 * Config.spacing.medium
                    Layout.alignment: Qt.AlignHCenter

                    ColumnLayout {
                        spacing: Config.spacing.small
                        width: parent.width

                        MaterialText {
                            text: qsTr("Приложения")
                            textStyle: "titleMedium"
                            colorRole: "onSurface"
                        }

                        MaterialText {
                            text: qsTr("Контролируйте активные аудиопотоки и их громкость")
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
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
                                    text: stream && stream.properties && stream.properties["application.name"] ? stream.properties["application.name"] : (stream.appName || stream.name || stream.clientName || qsTr("Приложение"))
                                    textStyle: "bodyMedium"
                                    colorRole: "onSurface"
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    MaterialButton {
                                        text: (stream.audio && stream.audio.muted) ? qsTr("Включить") : qsTr("Выключить")
                                        variant: (stream.audio && stream.audio.muted) ? "filled" : "outlined"
                                        enabled: !!(stream.audio)
                                        onClicked: if (stream.audio)
                                            stream.audio.muted = !stream.audio.muted
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                MaterialSlider {
                                    Layout.fillWidth: true
                                    enabled: !!(stream.audio)
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: (stream.audio && isFinite(stream.audio.volume)) ? stream.audio.volume : 0
                                    onMoved: if (stream.audio)
                                        stream.audio.volume = value
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MaterialText {
                                        text: formatVolume(stream.audio ? stream.audio.volume : null)
                                        textStyle: "bodySmall"
                                        colorRole: "onSurfaceVariant"
                                    }
                                }
                            }
                        }

                        MaterialText {
                            visible: root.streamNodes.length === 0
                            text: qsTr("Нет активных аудиопотоков")
                            textStyle: "bodySmall"
                            colorRole: "onSurfaceVariant"
                        }
                    }
                }
            }
        }
    }
}
