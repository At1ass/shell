import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Pipewire
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

BarElement {
    id: root
    minWidth: 96
    clickable: true
    hoverable: true

    property var tooltipManager: null
    property bool mixerOpen: false

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

    nonVisualChildren: [
        PwObjectTracker {
            objects: root.sink ? [root.sink] : []
        },
        TooltipItem {
            id: mixerTooltip
            tooltip: root.tooltipManager
            owner: root
            isMenu: true
            hoverable: true
            show: root.mixerOpen

            backgroundComponent: Component {
                Rectangle {
                    radius: Config.shape.extraLarge
                    color: Config.colors.surfaceContainerHigh
                    border.color: Config.colors.outlineVariant
                }
            }

            onClose: root.mixerOpen = false


            Loader {
                active: root.mixerOpen || mixerTooltip.visible

                sourceComponent: ColumnLayout {
                    id: contentColumn
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: qsTr("Аудио")
                        textStyle: "titleLarge"
                        colorRole: "onSurface"
                    }

                    MaterialText {
                        text: qsTr("Управляйте громкостью системы, устройств и приложений")
                        textStyle: "bodyMedium"
                        colorRole: "onSurfaceVariant"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(cardsColumn.implicitHeight, 460)
                        clip: true

                        Column {
                            id: cardsColumn
                            // x: Config.spacing.medium
                            // width: Math.max(parent.width - Config.spacing.medium * 2, 0)
                            width: parent.width
                            spacing: Config.spacing.medium

                            MaterialCard {
                                width: parent.width

                                ColumnLayout {
                                    spacing: Config.spacing.small
                                    width: parent.width

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.spacing.small

                                        MaterialText {
                                            text: qsTr("Громкость системы")
                                            textStyle: "titleMedium"
                                            colorRole: "onSurface"
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

                            MaterialCard {
                                width: parent.width

                                ColumnLayout {
                                    width: parent.width
                                    spacing: Config.spacing.small
                                    // Layout.fillWidth: true

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

                            MaterialCard {
                                width: parent.width

                                ColumnLayout {
                                    spacing: Config.spacing.small
                                    width: parent.width

                                    MaterialText {
                                        text: qsTr("Входы")
                                        textStyle: "titleMedium"
                                        colorRole: "onSurface"
                                    }

                                    MaterialText {
                                        text: qsTr("Настройка микрофонов и других источников")
                                        textStyle: "bodySmall"
                                        colorRole: "onSurfaceVariant"
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
                                                    text: node.id === Pipewire.defaultAudioSource?.id ? qsTr("Активный") : qsTr("Сделать активным")
                                                    variant: node.id === Pipewire.defaultAudioSource?.id ? "filled" : "tonal"
                                                    enabled: node.id !== Pipewire.defaultAudioSource?.id
                                                    onClicked: {
                                                        Pipewire.preferredDefaultAudioSource = node
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
                                        visible: root.sourceNodes.length === 0
                                        text: qsTr("Нет входных устройств")
                                        textStyle: "bodySmall"
                                        colorRole: "onSurfaceVariant"
                                    }
                                }
                            }

                            MaterialCard {
                                width: parent.width

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
        }
    ]

    wheelHandler: function (event) {
        if (!root.sink || !root.sink.audio) {
            event.accepted = false;
            return;
        }

        event.accepted = true;
        const step = (event.angleDelta.y / 120) * 0.04;
        const current = (root.sink.audio.volume !== undefined) ? root.sink.audio.volume : 0;
        root.sink.audio.volume = Math.max(0, Math.min(1, current + step));
    }

    clickHandler: function (mouse) {
        if (mouse.button === Qt.LeftButton) {
            if (!root.sink || !root.sink.audio) {
                mouse.accepted = false;
                return;
            }

            mouse.accepted = true;
            root.sink.audio.muted = !root.sink.audio.muted;
            root.mixerOpen = false;
            return;
        }

        if (mouse.button === Qt.RightButton) {
            root.mixerOpen = !root.mixerOpen;
            mouse.accepted = true;
            return;
        }

        mouse.accepted = false;
    }

    Row {
        spacing: Config.spacing.small

        MaterialIcon {
            iconName: {
                if (!root.sink || !root.sink.audio)
                    return "volume_up";
                if (root.sink.audio.muted || root.sink.audio.volume <= 0.001)
                    return "no_sound";
                const v = root.sink.audio.volume;
                return (v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up");
            }
            fontSize: Config.typography.titleLarge.size
            enabled: (typeof MprisController !== 'undefined') && MprisController.canGoPrevious
            iconColor: Config.colors.onSurface
            color: "transparent"
            enableRipple: false
        }


        MaterialText {
            anchors.verticalCenter: parent.verticalCenter
            text: formatVolume(root.sink && root.sink.audio ? root.sink.audio.volume : null)
            textStyle: "titleMedium"
            colorRole: "onSurface"
        }
    }
}
