import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config

pragma ComponentBehavior: Bound

Item {
    id: root

    property var categories: []

    readonly property var _categoryIcons: ({
        "Applications": "apps",
        "Window Control": "open_with",
        "Workspaces": "workspaces",
        "Focus and Movement": "swap_horiz",
        "Layout": "dashboard",
        "Modes": "tune",
        "Animations and Effects": "auto_awesome",
        "Misc Commands": "more_horiz",
        "System": "settings_power",
        "Shell": "widgets",
        "Other": "category"
    })

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            width: parent.width
            spacing: Tokens.spacing.medium

            // Empty state
            MaterialText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraLarge
                visible: root.categories.length === 0
                text: "No keybindings found"
                textStyle: "bodyLarge"
                colorRole: "onSurfaceVariant"
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                id: categoryRepeater
                model: root.categories

                ColumnLayout {
                    id: categoryDelegate
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 2

                    // Category header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: categoryDelegate.index > 0 ? Tokens.spacing.medium : 0
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            iconName: root._categoryIcons[categoryDelegate.modelData.name] || "category"
                            fontSize: Tokens.typography.titleSmall.size
                            iconColor: Theme.onSurfaceVariant
                        }

                        MaterialText {
                            text: categoryDelegate.modelData.name
                            textStyle: "titleSmall"
                            colorRole: "onSurfaceVariant"
                        }

                        // Neutral count chip, not the MD3 error badge — hence the
                        // explicit surface/onSurfaceVariant pair.
                        Badge {
                            inline: true
                            text: categoryDelegate.modelData.binds.length
                            badgeColor: Theme.surfaceContainerHighest
                            textColor: Theme.onSurfaceVariant
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Binds list
                    Repeater {
                        model: categoryDelegate.modelData.binds

                        BindRow {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
