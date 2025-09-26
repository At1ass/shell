import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.components.base
import qs.config

Rectangle {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large
    border.width: 1
    border.color: Config.colors.outlineVariant
    anchors {
        fill: parent
    }

    ColumnLayout {
        id: root
        anchors {
            fill: parent
            margins: Config.spacing.large
        }
        spacing: Config.spacing.large

        // PwObjectTracker для аудио
        PwObjectTracker {
            objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
        }

        // Заголовок панели
        MaterialText {
            text: "Системная панель"
            textStyle: "headlineMedium"
            colorRole: "surfaceText"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            horizontalAlignment: Text.AlignHCenter
        }

        // Аудио секция
        AudioSection {
            Layout.fillWidth: true
            Layout.fillHeight: false
        }

        // Placeholder для будущих секций
        MaterialText {
            text: "Другие секции будут здесь..."
            textStyle: "bodyMedium"
            colorRole: "surfaceVariantText"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
        }

        // Spacer
        Item {
            Layout.fillHeight: true
        }
    }
}
