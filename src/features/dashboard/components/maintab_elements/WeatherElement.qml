import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    // ColumnLayout {
    // ColumnLayout {
    //     anchors.fill: parent
    //     anchors.margins: Config.spacing.small
    //     spacing: 2
    //
        RowLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.small
            // spacing: 2
            spacing: Config.spacing.extraSmall
            Layout.alignment: Qt.AlignHCenter

                MaterialIcon {
                    iconName: Weather.icon
                    fontSize: Config.typography.displayMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                }
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                MaterialText {
                    text: Math.round(Weather.tempC) + "°C"
                    textStyle: "headlineMedium"
                    colorRole: "onSurface"
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignHCenter
                }

                MaterialText {
                    text: Weather.weatherDesc
                    textStyle: "labelSmall"
                    colorRole: "onSurfaceVariant"
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
    }
}
