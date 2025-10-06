import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.core.config

Item {
    // Фон - обложка альбома с затемнением
    Rectangle {
        anchors.fill: parent
        color: Config.colors.surfaceContainerLow

        // Имитация размытой обложки как фона
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#6a4c93" }
                GradientStop { position: 1.0; color: "#1a1423" }
            }
            opacity: 0.3
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.extraLarge
        spacing: Config.spacing.large

        // Верхняя строка: источник слева, устройство справа
        RowLayout {
            Layout.fillWidth: true

            // Источник (кликабельно для dropdown)
            RowLayout {
                spacing: Config.spacing.small

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    color: Config.colors.primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: "music_note"
                        fontSize: Config.typography.titleMedium.size
                        iconColor: Config.colors.onPrimaryContainer
                        backgroundColor: "transparent"
                    }
                }

                MaterialText {
                    text: "Spotify"
                    textStyle: "labelLarge"
                    colorRole: "onSurface"
                }

                MaterialIcon {
                    iconName: "expand_more"
                    fontSize: Config.typography.titleSmall.size
                    iconColor: Config.colors.onSurfaceVariant
                    backgroundColor: "transparent"
                }
            }

            Item { Layout.fillWidth: true }

            // Устройство
            RowLayout {
                spacing: Config.spacing.small

                MaterialIcon {
                    iconName: "computer"
                    fontSize: Config.typography.titleMedium.size
                    iconColor: Config.colors.onSurfaceVariant
                    backgroundColor: "transparent"
                }

                MaterialText {
                    text: "Desktop"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Центр: метаданные трека
        ColumnLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: Config.spacing.small

            MaterialText {
                text: "Bad Apple!! feat. nomico"
                textStyle: "headlineLarge"
                colorRole: "onSurface"
                font.weight: Font.Bold
            }

            MaterialText {
                text: "Alstroemeria Records"
                textStyle: "titleMedium"
                colorRole: "onSurfaceVariant"
            }

            MaterialText {
                text: "THE GAME"
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
                opacity: 0.8
            }
        }

        Item { Layout.fillHeight: true }

        // Прогресс-бар с временем
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Config.spacing.small

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: Config.colors.surfaceContainerHighest
                opacity: 0.5

                Rectangle {
                    width: parent.width * 0.25
                    height: parent.height
                    radius: parent.radius
                    color: Config.colors.onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true

                MaterialText {
                    text: "1:23"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }

                Item { Layout.fillWidth: true }

                MaterialText {
                    text: "5:17"
                    textStyle: "labelMedium"
                    colorRole: "onSurfaceVariant"
                }
            }
        }

        // Кнопки управления
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Config.spacing.medium
            spacing: Config.spacing.large

            MaterialIcon {
                iconName: "shuffle"
                fontSize: Config.typography.headlineMedium.size
                iconColor: Config.colors.onSurfaceVariant
                backgroundColor: "transparent"
            }

            Item { Layout.fillWidth: true }

            MaterialIcon {
                iconName: "skip_previous"
                fontSize: Config.typography.headlineLarge.size
                iconColor: Config.colors.onSurface
                backgroundColor: "transparent"
            }

            // Play/Pause кнопка (большая)
            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: Config.colors.primary

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "pause"
                    fontSize: Config.typography.displaySmall.size
                    iconColor: Config.colors.onPrimary
                    backgroundColor: "transparent"
                }
            }

            MaterialIcon {
                iconName: "skip_next"
                fontSize: Config.typography.headlineLarge.size
                iconColor: Config.colors.onSurface
                backgroundColor: "transparent"
            }

            Item { Layout.fillWidth: true }

            MaterialIcon {
                iconName: "favorite_border"
                fontSize: Config.typography.headlineMedium.size
                iconColor: Config.colors.onSurfaceVariant
                backgroundColor: "transparent"
            }
        }

        Item { height: Config.spacing.medium }
    }
}
