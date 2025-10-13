import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.core.services
import "components" as LauncherComponents

Item {
    id: root

    property var screen

    implicitHeight: Math.min(600, 56 + appListView.contentHeight + Config.spacing.large * 3) + 4  // +4 для тени

    // MD3 Shadow (Elevation Level 2)

    MaterialCard {
        id: container
        anchors.fill: parent
        anchors.margins: 2  // Отступ для тени
        outlined: false

        color: Config.colors.surfaceContainer
        radius: Config.shape.extraLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.spacing.large
            spacing: Config.spacing.medium

            // Search Field (at top with fixed height)
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Config.shape.full
                color: Config.colors.surfaceContainerHighest
                border.width: searchField.activeFocus ? 2 : 0
                border.color: searchField.activeFocus ? Config.colors.primary : "transparent"

                Behavior on border.width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.small
                    spacing: Config.spacing.small

                    MaterialIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "search"
                        iconColor: Config.colors.onSurfaceVariant
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true

                        placeholderText: "Search apps..."
                        color: Config.colors.onSurface
                        font.pixelSize: Config.typography.bodyLarge.size

                        background: Item {}  // Transparent - используем внешний Rectangle

                        // Live search
                        onTextChanged: {
                            LauncherService.search(text)
                            appListView.currentIndex = 0
                        }

                        // Tab navigation
                        Keys.onTabPressed: (event) => {
                            if (event.modifiers & Qt.ShiftModifier) {
                                // Shift+Tab - вверх
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--
                                }
                            } else {
                                // Tab - вниз
                                if (appListView.currentIndex < appListView.count - 1) {
                                    appListView.currentIndex++
                                }
                            }
                            event.accepted = true
                        }

                        Keys.onBacktabPressed: (event) => {
                            // Shift+Tab альтернативный обработчик
                            if (appListView.currentIndex > 0) {
                                appListView.currentIndex--
                            }
                            event.accepted = true
                        }

                        // Keyboard navigation
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Down) {
                                if (appListView.currentIndex < appListView.count - 1) {
                                    appListView.currentIndex++
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (appListView.currentIndex > 0) {
                                    appListView.currentIndex--
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (appListView.currentItem) {
                                    LauncherService.launch(appListView.currentItem.modelData)
                                    GlobalStates.launcherOpen = false
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                GlobalStates.launcherOpen = false
                                event.accepted = true
                            }
                        }
                    }

                    IconButton {
                        id: clearButton
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "close"
                        visible: searchField.text.length > 0
                        iconSize: Config.iconSize.medium

                        onClicked: {
                            searchField.text = ""
                            searchField.forceActiveFocus()
                        }
                    }
                }
            }

            // App List (scrollable, takes remaining space)
            ListView {
                id: appListView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(
                    contentHeight,
                    400  // Max height
                )

                maximumFlickVelocity: 3000

                // ScriptModel для отслеживания изменений элементов
                model: ScriptModel {
                    id: scriptModel
                    values: LauncherService.filteredApps
                }

                spacing: Config.spacing.extraSmall
                clip: true

                currentIndex: 0
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 200

                // Transform origin для scale анимаций
                transformOrigin: Item.Center

                // Highlight
                highlight: Rectangle {
                    radius: Config.shape.medium
                    color: Config.colors.secondaryContainer
                    opacity: 0.3

                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                        }
                    }
                }

                delegate: LauncherComponents.AppListItem {
                    width: appListView.width
                    isCurrentItem: appListView.currentIndex === index

                    onClicked: {
                        LauncherService.launch(modelData)
                        GlobalStates.launcherOpen = false
                    }
                }

                // MD3 transitions для добавления/удаления элементов (как в Caelestia)
                add: Transition {
                    NumberAnimation {
                        properties: "opacity,scale"
                        from: 0
                        to: 1
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        properties: "opacity,scale"
                        from: 1
                        to: 0
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                addDisplaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                    NumberAnimation {
                        properties: "opacity,scale"
                        to: 1
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                rebound: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                    }
                }

                // Scrollbar - всегда резервируем место
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    visible: appListView.contentHeight > appListView.height
                    opacity: visible ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]  // MD3 standard
                        }
                    }
                }
            }
        }
    }

    // Reset search and focus when launcher opens
    onVisibleChanged: {
        if (visible) {
            // Reset search field
            searchField.text = ""
            LauncherService.search("")
            appListView.currentIndex = 0

            // Focus search field (с задержкой чтобы избежать Wayland warning)
            Qt.callLater(function() {
                searchField.forceActiveFocus()
            })
        }
    }
}
