import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.src.core.config

// Material Design 3 Scrollable List Container
Item {
    id: root

    property int spacing: Config.spacing.small
    property int contentPadding: 0

    // Content data for child items
    default property alias contentData: contentLayout.data

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        // Content container
        Item {
            width: scrollView.availableWidth
            implicitHeight: contentLayout.implicitHeight + root.contentPadding * 2

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: root.contentPadding
                spacing: root.spacing
            }
        }
    }
}
