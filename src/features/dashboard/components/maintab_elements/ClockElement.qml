import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config


MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        MaterialText {
            text: Qt.formatTime(clock.date, "hh")
            textStyle: "headlineLarge"
            colorRole: "onSurface"
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }
        MaterialText {
            text: ". . ."
            textStyle: "labelLarge"
            colorRole: "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
        }
        MaterialText {
            text: Qt.formatTime(clock.date, "mm")
            textStyle: "headlineLarge"
            colorRole: "onSurface"
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }

        MaterialText {
            text: Qt.formatDate(clock.date, "ddd")
            textStyle: "labelLarge"
            colorRole: "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
        }

        MaterialText {
            text: Qt.formatDate(clock.date, "dd MMM")
            textStyle: "labelMedium"
            colorRole: "onSurfaceVariant"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
