pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.core.config
import qs.src.features.cheatsheet.components as Components

// Read-only presentation. Discovery and filtering stay in CheatsheetContent.
MaterialCard {
    id: root
    property bool active: true
    property alias query: searchField.text
    property int currentTab: 0
    property var categories: []
    property var handlers: []
    property bool loading: false
    property string errorMessage: ""
    signal closeRequested()
    signal retryRequested()
    function focusSearch() { searchField.inputItem.forceActiveFocus() }

    color: Qt.alpha(Theme.surfaceContainer, 0.95)
    radius: Tokens.shape.extraLarge
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: root.active && root.visible
        onActivated: root.currentTab = (root.currentTab + 1) % tabs.labels.length
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: root.active && root.visible
        onActivated: root.currentTab = (root.currentTab + tabs.labels.length - 1) % tabs.labels.length
    }
    Keys.onPressed: event => {
        if (Keycodes.key(event) === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            root.focusSearch()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (root.query) root.query = ""
            else root.closeRequested()
            event.accepted = true
        }
    }

    // Usually exactly one viewport high. Very short outputs can scroll the
    // chrome as well, keeping both tabs and their content reachable.
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.large
        ColumnLayout {
            id: layout
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                MaterialIcon {
                    id: helpIcon
                    visible: header.width >= heading.implicitWidth + implicitWidth + closeButton.implicitWidth + header.spacing * 2
                    iconName: "help"
                    fontSize: Tokens.typography.titleLarge.size
                    iconColor: Theme.primary
                }
                MaterialText {
                    id: heading
                    Layout.fillWidth: true
                    text: "Cheatsheet"
                    textStyle: "titleLarge"
                    wrapMode: Text.Wrap
                }
                IconButton {
                    id: closeButton
                    objectName: "cheatsheetClose"
                    iconName: "close"
                    Accessible.name: "Close cheatsheet"
                    onClicked: root.closeRequested()
                }
            }
            MaterialTextField {
                id: searchField
                objectName: "cheatsheetSearch"
                Layout.fillWidth: true
                label: "Search keybindings and commands"
                placeholderText: "Search keybindings, commands…"
                leadingIcon: "search"
                trailingIcon: text ? "close" : ""
                onTrailingClicked: { root.query = ""; root.focusSearch() }
            }
            MaterialTabs {
                id: tabs
                objectName: "cheatsheetTabs"
                Layout.fillWidth: true
                labels: ["Keybindings", "IPC Reference"]
                accessibleName: "Cheatsheet sections"
                currentIndex: root.currentTab
                onActivated: index => root.currentTab = index
            }
            Divider { id: divider; Layout.fillWidth: true }
            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(Tokens.size.control * 3, root.height - Tokens.spacing.large * 2
                                                - header.implicitHeight - searchField.implicitHeight - tabs.implicitHeight
                                                - divider.implicitHeight - layout.spacing * 4)
                sourceComponent: root.currentTab === 0 ? bindingsComponent : ipcComponent
                Component {
                    id: bindingsComponent
                    Components.KeybindingsTab { categories: root.categories }
                }
                Component {
                    id: ipcComponent
                    Components.IpcReferenceTab {
                        handlers: root.handlers
                        loading: root.loading
                        errorMessage: root.errorMessage
                        onRetryRequested: root.retryRequested()
                    }
                }
            }
        }
    }
}
