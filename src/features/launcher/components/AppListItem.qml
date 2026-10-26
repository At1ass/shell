import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.src.ui.containers
import qs.src.ui.base
import qs.src.ui.feedback
import qs.src.core.config
import qs.src.core.services

Item {
    id: root

    required property var modelData  // Result object from provider (from ScriptModel)
    required property int index  // Index from ListView
    property bool isCurrentItem: false

    signal clicked()

    // The view's transitions animate `scale` and `opacity` ON THIS ITEM, and
    // ScriptModel REUSES delegates keyed by resultId. Interrupt a transition —
    // which fast typing does, since the query changes faster than the 400 ms
    // remove — and the delegate keeps whatever partial scale it had, then comes
    // back bound to a different result still shrunk. Reported as a row stuck
    // ever smaller the faster you type. A row handed new data starts sane
    // regardless of what any half-finished transition left behind.
    onModelDataChanged: {
        scale = 1
        opacity = 1
        Qt.callLater(root._requestThumbnail)
    }

    readonly property bool _thumbnailWanted: GlobalStates.launcherOpen
        && root.modelData?.data?.isImage === true
        && root.ListView.view !== null
        && root.y + root.height > root.ListView.view.contentY
        && root.y < root.ListView.view.contentY + root.ListView.view.height
    on_ThumbnailWantedChanged: if (_thumbnailWanted) root._requestThumbnail()
    Component.onCompleted: root._requestThumbnail()

    function _requestThumbnail() {
        if (root._thumbnailWanted)
            ClipboardService.requestThumbnail(root.modelData.data.entry)
    }

    // Constant across results, including rows without a description, so
    // delegate reuse never positions a row using another result's height.
    implicitHeight: Math.max(Tokens.size.listItem,
        Math.ceil(Tokens.typography.titleMedium.lineHeight + Tokens.typography.bodySmall.lineHeight)
        + Tokens.spacing.small * 2 + Tokens.spacing.extraSmall)
    implicitWidth: parent ? parent.width : 0

    Accessible.role: Accessible.ListItem
    Accessible.name: modelData?.text ?? ""
    Accessible.description: modelData?.description ?? ""
    Accessible.selected: isCurrentItem
    Surface {
        anchors.fill: parent
        outlined: false
        radius: Tokens.shape.medium
        color: root.isCurrentItem ? Theme.secondaryContainer : "transparent"
    }

    StateLayer {
        hovered: mouseArea.containsMouse
        pressed: mouseArea.pressed
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.medium
        anchors.rightMargin: Tokens.spacing.medium
        spacing: Tokens.spacing.medium

        // Clipboard image thumbnail
        Image {
            id: clipboardThumb
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Tokens.size.itemIcon
            Layout.preferredHeight: Tokens.size.itemIcon
            visible: _thumbSource !== ""

            readonly property string _thumbSource: {
                if (root.modelData?.data?.isImage !== true) return ""
                // Depend on version to re-evaluate when new thumbnails arrive
                let v = ClipboardService._thumbnailVersion
                void(v)
                return ClipboardService.thumbnailFor(root.modelData.data.entry) || ""
            }

            source: _thumbSource ? "file://" + _thumbSource : ""
            sourceSize.width: Tokens.size.itemIcon
            sourceSize.height: Tokens.size.itemIcon
            fillMode: Image.PreserveAspectCrop
            smooth: true
            cache: false
            asynchronous: true

            Surface {
                anchors.fill: parent
                color: "transparent"
                radius: Tokens.shape.small
                outlined: true
                outlineColor: Theme.outlineVariant
            }
        }

        // App Icon (hidden when thumbnail is shown)
        Image {
            id: appIcon
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Tokens.size.itemIcon
            Layout.preferredHeight: Tokens.size.itemIcon
            visible: !clipboardThumb.visible

            // The ?fallback= query is resolved by Quickshell's icon image
            // provider itself — stripping it (as this code once did) threw
            // the fallback away and rendered a blank gap for unknown icons.
            source: Quickshell.iconPath(root.modelData?.icon || "application-x-executable", "image-missing")

            sourceSize.width: Tokens.size.itemIcon
            sourceSize.height: Tokens.size.itemIcon
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
            // Synchronous, like every other icon-provider load in the shell.
            // `Quickshell.iconPath` resolves through the same `image://icon/`
            // provider, i.e. QIcon::fromTheme -> KIconEngine (qt6ct pulls in
            // KIconThemes), which is not thread safe. Asynchronous hands that
            // call to Qt's pixmap-reader thread while the dock loads its icons
            // on the GUI thread: reproduced as a SIGSEGV in
            // KIconEngine::createPixmap, the same stack as the 2026-09-02
            // crashes. The state it leaves behind when it does NOT crash is the
            // "icons vanish after a hot reload, except the dock's" bug -- the
            // dock's pixmaps are already cached, every new lookup comes back
            // empty. check.sh's async-icon-provider rule missed this site
            // because it did not recognise iconPath; it does now.
            asynchronous: false
        }

        // App Info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.extraSmall

            // Result Name
            MaterialText {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.modelData?.text || ""
                textStyle: "titleMedium"
                colorRole: "onSurface"
                elide: Text.ElideRight
            }

            // Result Description
            MaterialText {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.modelData?.description || ""
                textStyle: "bodySmall"
                colorRole: "onSurfaceVariant"
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
