import QtQuick
import QtQuick.Layouts
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import Quickshell
import qs.src.ui.base
import qs.src.core.config

ColumnLayout {
    id: root
    property alias menu: menuView.menu
    property Item animatingItem: null
    property bool animating: animatingItem != null

    signal menuClosed()

    QsMenuOpener { id: menuView }

    spacing: 0

    Repeater {
        model: menuView.children

        Loader {
            required property var modelData

            Layout.fillWidth: true

            sourceComponent: modelData.isSeparator ? separatorComponent : menuItemComponent

            Component {
                id: separatorComponent
                Item {
                    implicitHeight: 7

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Config.colors.outline
                        opacity: 0.3
                    }
                }
            }

            Component {
                id: menuItemComponent
                MouseArea {
                    id: menuItemRoot
                    property var entry: modelData

                    implicitWidth: contentRow.implicitWidth + 8
                    implicitHeight: contentRow.implicitHeight + 8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: entry.enabled

                    onClicked: {
                        if (entry.hasChildren) {
                            // Обработка подменю если нужно
                        } else {
                            entry.triggered()
                            root.menuClosed()
                        }
                    }

                    ColumnLayout {
                        id: contentRow
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 0

                        RowLayout {
                            id: innerRow

                            // Область для checkbox/radio или submenu индикатора
                            Item {
                                implicitWidth: 22
                                implicitHeight: 22

                            // Checkbox
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 12
                                color: (entry.checkState == 2) ? Config.colors.primary : "transparent"
                                border.color: Config.colors.outline
                                border.width: (entry.buttonType == 1) ? 1 : 0  // CheckBox = 1
                                visible: entry.buttonType == 1

                                MaterialText {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    textStyle: "labelSmall"
                                    // color: Config.colors.primaryText
                                    color: Config.colors.onPrimary
                                    visible: entry.checkState == 2
                                }
                            }

                            // Radio button
                            Rectangle {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                radius: 8
                                color: "transparent"
                                border.color: Config.colors.outline
                                border.width: (entry.buttonType == 2) ? 1 : 0  // RadioButton = 2
                                visible: entry.buttonType == 2

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Config.colors.primary
                                    visible: entry.checkState == 2
                                }
                            }

                            // Submenu arrow
                            MaterialText {
                                anchors.centerIn: parent
                                text: "▶"
                                textStyle: "labelSmall"
                                color: Config.colors.onSurfaceVariant
                                visible: entry.hasChildren
                            }
                        }

                            // Текст пункта меню
                            MaterialText {
                                text: entry.text
                                textStyle: "bodyMedium"
                                color: entry.enabled ? Config.colors.onSurface : Config.colors.onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            // Иконка справа
                            Item {
                                implicitWidth: 22
                                implicitHeight: 22

                                Image {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: entry.icon
                                    visible: source != ""
                                    width: parent.height
                                    height: parent.height
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }
                    }

                    // Фон для выделения
                    Rectangle {
                        anchors.fill: parent
                        visible: menuItemRoot.containsMouse && menuItemRoot.enabled
                        // color: Config.colors.primaryContainer
                        color: Config.colors.onSurface
                        // radius: Config.shape.extraSmall
                        radius: Config.shape.medium
                        opacity: menuItemRoot.containsMouse && menuItemRoot.enabled ? 0.12 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }
            }
        }
    }
}
