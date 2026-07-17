import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Theme.surfaceContainerHigh
    radius: Tokens.shape.large

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall
            Layout.alignment: Qt.AlignHCenter

                MaterialIcon {
                    iconName: Weather.icon
                    fontSize: Tokens.typography.displayMedium.size
                    iconColor: Theme.primary
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                }
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                MaterialText {
                    text: Weather.data ? Math.round(Weather.tempC) + Weather.tempUnit : "--"
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
