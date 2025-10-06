import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.core.config
import qs.src.core.services

MaterialCard {
    color: Config.colors.surfaceContainerHigh
    radius: Config.shape.large

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.small
        spacing: 2

        RowLayout {
            spacing: Config.spacing.extraSmall
            Layout.alignment: Qt.AlignHCenter

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                MaterialIcon {
                    iconName: Weather.icon
                    fontSize: Config.typography.displayMedium.size
                    iconColor: Config.colors.primary
                    backgroundColor: "transparent"
                    Layout.alignment: Qt.AlignHCenter
                }
                MaterialText {
                    text: Weather.tempC + "°C"
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
                }
            }
            // ColumnLayout {
            //     spacing: 4
            //     Layout.alignment: Qt.AlignHCenter
            //
            //     Repeater {
            //         model: [
            //             {
            //                 temp: "15°",
            //                 icon: "partly_cloudy_day"
            //             },
            //             {
            //                 temp: "17°",
            //                 icon: "wb_sunny"
            //             },
            //             {
            //                 temp: "16°",
            //                 icon: "cloud"
            //             }
            //         ]
            //
            //         delegate: RowLayout {
            //             spacing: 4
            //
            //             MaterialIcon {
            //                 iconName: modelData.icon
            //                 fontSize: Config.typography.titleLarge.size
            //                 iconColor: Config.colors.primary
            //                 backgroundColor: "transparent"
            //             }
            //
            //             MaterialText {
            //                 text: modelData.temp
            //                 textStyle: "labelLarge"
            //                 colorRole: "onSurface"
            //             }
            //         }
            //     }
            // }
        }
    }
}
