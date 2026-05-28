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

    implicitHeight: Math.min(AppConfig.launcherWidth, 56 + appListView.contentHeight + Tokens.spacing.large * 3) + 4  // +4 для тени

    // MD3 Shadow (Elevation Level 2)

    MaterialCard {
        id: container
        anchors.fill: parent
        anchors.margins: 2  // Отступ для тени
        outlined: false

        color: Theme.surfaceContainer
        radius: Tokens.shape.extraLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            // Search Field (at top with fixed height)
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Tokens.shape.full
                color: Theme.surfaceContainerHighest
                border.width: searchField.activeFocus ? 2 : 0
                border.color: searchField.activeFocus ? Theme.primary : "transparent"

                Behavior on border.width {
                    NumberAnimation {
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "search"
                        iconColor: Theme.onSurfaceVariant
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true

                        placeholderText: "Search apps..."
                        color: Theme.onSurface
                        font.pixelSize: Tokens.typography.bodyLarge.size

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

                        Component.onCompleted: searchField.forceActiveFocus()
                    }

                    IconButton {
                        id: clearButton
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        iconName: "close"
                        visible: searchField.text.length > 0
                        iconSize: Tokens.iconSize.medium

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
                    AppConfig.launcherListMaxHeight
                )

                maximumFlickVelocity: 3000

                // ScriptModel для отслеживания изменений элементов
                model: ScriptModel {
                    id: scriptModel
                    objectProp: "id"  // Исправлено: все провайдеры используют "id"
                    values: LauncherService.filteredApps

                    onValuesChanged: appListView.currentIndex = 0
                }

                spacing: Tokens.spacing.extraSmall
                clip: true

                currentIndex: 0
                highlightFollowsCurrentItem: false

                // Автопрокрутка при изменении currentIndex
                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }

                // Transform origin для scale анимаций
                transformOrigin: Item.Center

                // Highlight
                highlight: Rectangle {
                    visible: !!appListView.currentItem
                    width: appListView.width
                    height: appListView.currentItem ? appListView.currentItem.height : 0
                    y: appListView.currentItem ? appListView.currentItem.y : 0
                    radius: Tokens.shape.medium
                    color: Theme.secondaryContainer
                    opacity: 0.3

                    Behavior on y {
                        NumberAnimation {
                            duration: Tokens.motion.duration.short4
                            easing.type: Tokens.motion.easing.standard
                            easing.bezierCurve: Tokens.motion.easing.standardPoints
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Tokens.motion.duration.short4
                            easing.type: Tokens.motion.easing.standard
                            easing.bezierCurve: Tokens.motion.easing.standardPoints
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

                // Флаг для отключения transitions при переоткрытии
                property bool transitionsEnabled: true

                // MD3 transitions for list item add/remove/move
                add: Transition {
                    enabled: appListView.transitionsEnabled
                    NumberAnimation {
                        properties: "opacity,scale"; from: 0; to: 1
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                populate: Transition {
                    enabled: appListView.transitionsEnabled
                    NumberAnimation {
                        properties: "opacity,scale"; from: 0; to: 1
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        properties: "opacity,scale"; from: 1; to: 0
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                move: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                    NumberAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                addDisplaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                    NumberAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.short4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                    NumberAnimation {
                        properties: "opacity,scale"; to: 1
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                rebound: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Tokens.motion.duration.medium4
                        easing.type: Tokens.motion.easing.standard
                        easing.bezierCurve: Tokens.motion.easing.standardPoints
                    }
                }

                // Scrollbar - всегда резервируем место
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                    visible: appListView.contentHeight > appListView.height
                    opacity: visible ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.motion.duration.short4
                            easing.type: Tokens.motion.easing.standard
                            easing.bezierCurve: Tokens.motion.easing.standardPoints
                        }
                    }
                }
            }
        }
    }

    // Reset search and focus when launcher opens/closes
    onVisibleChanged: {
        if (visible) {
            // Отключаем transitions при открытии
            appListView.transitionsEnabled = false

            // Pull fresh cliphist state — the clipboard-change watcher uses
            // a 100ms debounce, which races a fast Mod+Space after a copy.
            ClipboardService.refresh()

            // Очищаем и сбрасываем
            searchField.text = ""
            LauncherService.search("")
            appListView.currentIndex = 0

            // Включаем transitions обратно после небольшой задержки
            Qt.callLater(function() {
                appListView.transitionsEnabled = true
                searchField.forceActiveFocus()
            })
        } else {
            // Отключаем transitions при закрытии
            appListView.transitionsEnabled = false

            // Очищаем при закрытии
            searchField.text = ""
            LauncherService.search("")
        }
    }

    // Re-run the search when cliphist entries change in clipboard-prefix mode
    // (covers the case where ClipboardService.refresh in onVisibleChanged got
    // back stale data, then the 100ms debounce refresh delivered the new
    // entry afterwards — the displayed list needs to recompute).
    Connections {
        target: ClipboardService
        function onEntriesChanged() {
            if (root.visible && searchField.text.startsWith(">"))
                LauncherService.search(searchField.text)
        }
    }

    // Инициализация при создании
    Component.onCompleted: {
        LauncherService.search("")
        appListView.currentIndex = 0
    }
}
