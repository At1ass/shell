pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

// Presentation only: authentication and system effects belong to LockSurface.
Item {
    id: root
    component LockButton: MaterialButton {
        Keys.forwardTo: [root]
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
    }
    property bool formActive: true
    property string username: ""
    property date now: new Date()
    property string layoutCode: ""
    property bool multipleLayouts: false
    property bool capsLock: false
    property string errorMessage: ""
    property string powerError: ""
    property bool powerBusy: false
    property bool mediaAvailable: false
    property bool playing: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackArt: ""
    property bool canPrevious: false
    property bool canNext: false
    property bool canToggle: false
    property bool batteryAvailable: false
    property int batteryPercent: 0
    property bool charging: false
    property string networkIcon: "network_wifi"
    property string networkStatus: ""
    property bool weatherAvailable: false
    property string weatherText: ""
    property bool powerOpen: false
    property string confirming: ""
    property alias password: passwordField.text
    property alias inputItem: passwordField.inputItem
    readonly property bool mediaShown: formActive && AppConfig.lockscreenShowMedia
        && mediaAvailable && (playing || AppConfig.lockscreenMediaShowPaused)
    signal submitted(string password)
    signal edited()
    signal switchLayout()
    signal previous()
    signal next()
    signal togglePlaying()
    signal powerRequested(string action)

    function ensureItemVisible(item) {
        if (!formActive || powerOpen || !item) return
        let ancestor = item
        while (ancestor && ancestor !== column) ancestor = ancestor.parent
        if (!ancestor) return
        const top = item.mapToItem(scroll.contentItem, 0, 0).y
        const bottom = top + item.height
        if (top < scroll.contentY) scroll.contentY = top
        else if (bottom > scroll.contentY + scroll.height) scroll.contentY = bottom - scroll.height
        scroll.contentY = Math.max(0, Math.min(scroll.contentY, scroll.contentHeight - scroll.height))
    }
    function ensurePasswordVisible() {
        if (passwordField.inputItem.activeFocus) ensureItemVisible(passwordField)
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(() => root.ensureItemVisible(root.Window.window?.activeFocusItem)) }
    }
    function focusPassword() {
        if (formActive && !powerOpen) {
            passwordField.inputItem.forceActiveFocus()
            Qt.callLater(ensurePasswordVisible)
        }
    }
    function clearPassword() { passwordField.text = ""; passwordField.password = true }
    function closePower() { powerOpen = false; confirming = ""; focusPassword() }
    function openPower() { powerOpen = true; confirming = ""; powerError = ""; Qt.callLater(() => cancelPower.forceActiveFocus()) }
    function requestPower(action) {
        if (powerBusy || !["suspend", "reboot", "shutdown"].includes(action)) return
        clearPassword()
        powerRequested(action)
    }
    onFormActiveChanged: if (!formActive) { clearPassword(); powerOpen = false; confirming = "" }
    onPowerBusyChanged: if (!powerBusy && powerOpen) Qt.callLater(() => cancelPower.forceActiveFocus())
    onVisibleChanged: if (!visible) clearPassword()
    Keys.onPressed: event => {
        if (!powerOpen || (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)) return
        const controls = [sleepButton, rebootButton, shutdownButton, confirmButton, cancelPower].filter(item => item.visible && item.enabled)
        const index = controls.findIndex(item => item.activeFocus)
        const direction = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1
        controls[(index + direction + controls.length) % controls.length].forceActiveFocus()
        event.accepted = true
    }
    Keys.onEscapePressed: { if (powerOpen) closePower(); else { clearPassword(); focusPassword() } }

    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.small
        visible: root.formActive
        MaterialIcon {
            visible: AppConfig.lockscreenShowNetwork
            iconName: root.networkIcon
            iconColor: Theme.scrimForeground
            Accessible.name: root.networkStatus
        }
        MaterialIcon {
            visible: AppConfig.lockscreenShowBattery && root.batteryAvailable
            iconName: root.charging ? "battery_charging_full" : "battery_full"
            iconColor: Theme.scrimForeground
        }
        MaterialText {
            visible: AppConfig.lockscreenShowBattery && root.batteryAvailable
            text: root.batteryPercent + "%"
            colorRole: "scrimForeground"
            textStyle: "labelLarge"
        }
    }

    // Scrolling preserves access to the form on small outputs and large fonts.
    Flickable {
        id: scroll
        objectName: "lockScroll"
        onHeightChanged: Qt.callLater(root.ensurePasswordVisible)
        onContentHeightChanged: Qt.callLater(root.ensurePasswordVisible)
        enabled: !root.powerOpen
        visible: !root.powerOpen
        anchors.fill: parent
        anchors.topMargin: Tokens.size.control + Tokens.spacing.large
        anchors.bottomMargin: Tokens.size.control + Tokens.spacing.large
        anchors.leftMargin: Tokens.spacing.large
        anchors.rightMargin: Tokens.spacing.large
        contentWidth: width
        contentHeight: Math.max(height, column.implicitHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: column
            width: Math.min(scroll.width, Tokens.size.fieldWidth + Tokens.spacing.extraHuge * 3)
            x: (scroll.width - width) / 2
            y: Math.max(0, (scroll.height - implicitHeight) / 2)
            spacing: Tokens.spacing.medium
            MaterialText {
                objectName: "lockClock"
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Tokens.typography.titleLarge.size
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm")
                textStyle: "displayLarge"
                colorRole: "scrimForeground"
                visible: AppConfig.lockscreenShowClock
            }
            MaterialText {
                objectName: "lockDate"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.now, "dddd, d MMMM")
                textStyle: "titleMedium"
                colorRole: "scrimForeground"
                wrapMode: Text.WordWrap
                visible: AppConfig.lockscreenShowDate
            }
            MaterialText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.weatherText
                textStyle: "bodyMedium"
                colorRole: "scrimForeground"
                wrapMode: Text.WordWrap
                visible: root.formActive && AppConfig.lockscreenShowWeather && root.weatherAvailable
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: authColumn.implicitHeight + Tokens.spacing.large * 2
                visible: root.formActive
                ColumnLayout {
                    id: authColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.large
                    spacing: Tokens.spacing.small
                    MaterialText {
                        objectName: "lockUsername"
                        colorRole: "scrimForeground"
                        Layout.fillWidth: true
                        text: root.username
                        horizontalAlignment: Text.AlignHCenter
                        textStyle: "titleMedium"
                        elide: Text.ElideRight
                        visible: AppConfig.lockscreenShowUsername
                    }
                    MaterialTextField {
                        id: passwordField
                        objectName: "lockPassword"
                        Layout.fillWidth: true
                        placeholderText: "Password"
                        leadingIcon: "lock"
                        password: true
                        trailingIcon: password ? "visibility" : "visibility_off"
                        inputItem.onActiveFocusChanged: if (inputItem.activeFocus) Qt.callLater(root.ensurePasswordVisible)
                        inputItem.inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        inputItem.Accessible.name: "Password"
                        onTrailingClicked: { password = !password; root.focusPassword() }
                        onAccepted: if (text.length > 0 && !root.powerOpen) root.submitted(text)
                        onTextEdited: root.edited()
                        trailingContent: [
                            LockButton {
                                objectName: "lockLayout"
                                variant: "text"
                                text: root.layoutCode.toUpperCase() || "EN"
                                implicitWidth: Math.max(Tokens.touchTarget.minimum, implicitContentWidth + Tokens.spacing.small * 2)
                                leftPadding: Tokens.spacing.small
                                rightPadding: Tokens.spacing.small
                                enabled: root.multipleLayouts
                                onActiveFocusChanged: if (activeFocus) root.ensureItemVisible(this)
                                onClicked: { root.switchLayout(); root.focusPassword() }
                            },
                            IconButton {
                                objectName: "lockSubmit"
                                iconName: "arrow_forward"
                                enabled: passwordField.text.length > 0 && !root.powerOpen
                                Accessible.name: "Unlock"
                                onActiveFocusChanged: if (activeFocus) root.ensureItemVisible(this)
                                onClicked: root.submitted(passwordField.text)
                            }
                        ]
                    }
                    MaterialText {
                        visible: root.capsLock
                        text: "Caps Lock"
                        textStyle: "labelMedium"
                        colorRole: "error"
                    }
                    MaterialText {
                        objectName: "lockAuthError"
                        Layout.fillWidth: true
                        Layout.minimumHeight: Tokens.typography.bodySmall.lineHeight * 2
                        text: root.errorMessage
                        textStyle: "bodySmall"
                        colorRole: "error"
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.AlertMessage
                    }
                }
            }
            Surface {
                objectName: "lockMedia"
                Layout.fillWidth: true
                visible: root.mediaShown
                implicitHeight: mediaColumn.implicitHeight + Tokens.spacing.medium * 2
                color: Theme.surfaceContainer
                ColumnLayout {
                    id: mediaColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.medium
                    spacing: Tokens.spacing.small
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Tokens.size.control * 2
                        Layout.preferredHeight: Tokens.size.control * 2
                        visible: AppConfig.lockscreenMediaShowArt && root.trackArt !== ""
                        source: visible ? root.trackArt : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                    }
                    MaterialText { Layout.fillWidth: true; text: root.trackTitle; textStyle: "titleSmall"; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    MaterialText { Layout.fillWidth: true; text: root.trackArtist; textStyle: "bodySmall"; colorRole: "onSurfaceVariant"; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        IconButton { objectName: "lockPrevious"; iconName: "skip_previous"; enabled: root.canPrevious; Accessible.name: "Previous track"; onClicked: root.previous() }
                        IconButton { objectName: "lockPlay"; iconName: root.playing ? "pause" : "play_arrow"; enabled: root.canToggle; Accessible.name: root.playing ? "Pause" : "Play"; onClicked: root.togglePlaying() }
                        IconButton { objectName: "lockNext"; iconName: "skip_next"; enabled: root.canNext; Accessible.name: "Next track"; onClicked: root.next() }
                    }
                }
            }
        }
    }
    IconButton {
        objectName: "lockPower"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.large
        enabled: !root.powerOpen
        visible: root.formActive && AppConfig.lockscreenShowPower
        iconName: "power_settings_new"
        iconColor: Theme.scrimForeground
        Accessible.name: "Power actions"
        onClicked: root.powerOpen ? root.closePower() : root.openPower()
    }
    // Same lock surface: a separate layer-shell popup cannot sit above a session lock.
    Surface {
        id: powerPanel
        objectName: "lockPowerPanel"
        visible: root.formActive && root.powerOpen
        anchors.centerIn: parent
        width: Math.min(parent.width - Tokens.spacing.large * 2, Tokens.size.fieldWidth + Tokens.spacing.extraLarge * 2)
        height: Math.min(parent.height - Tokens.spacing.large * 2, powerActions.implicitHeight + Tokens.spacing.large * 2)
        elevation: 2
        Flickable {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            contentHeight: powerActions.implicitHeight
            clip: true
            ColumnLayout {
                id: powerActions
                width: parent.width
                spacing: Tokens.spacing.small
                MaterialText { Layout.fillWidth: true; text: root.confirming ? "Confirm " + root.confirming + "?" : "Power"; textStyle: "titleMedium"; wrapMode: Text.WordWrap }
                MaterialText { Layout.fillWidth: true; visible: root.confirming !== ""; text: "Unsaved work may be lost."; textStyle: "bodyMedium"; wrapMode: Text.WordWrap }
                LockButton { id: sleepButton; objectName: "lockSleep"; Layout.fillWidth: true; visible: !root.confirming; text: "Sleep"; enabled: !root.powerBusy; onClicked: root.requestPower("suspend") }
                LockButton { id: rebootButton; objectName: "lockReboot"; Layout.fillWidth: true; visible: !root.confirming; text: "Restart…"; enabled: !root.powerBusy; onClicked: { root.confirming = "reboot"; cancelPower.forceActiveFocus() } }
                LockButton { id: shutdownButton; objectName: "lockShutdown"; Layout.fillWidth: true; visible: !root.confirming; text: "Shut down…"; enabled: !root.powerBusy; onClicked: { root.confirming = "shutdown"; cancelPower.forceActiveFocus() } }
                MaterialText { Layout.fillWidth: true; visible: root.powerError !== ""; text: root.powerError; colorRole: "error"; wrapMode: Text.WordWrap }
                LockButton { id: confirmButton; objectName: "lockConfirmPower"; Layout.fillWidth: true; visible: root.confirming !== ""; text: root.confirming === "reboot" ? "Restart" : "Shut down"; enabled: !root.powerBusy; onClicked: root.requestPower(root.confirming) }
                LockButton { id: cancelPower; objectName: "lockCancelPower"; Layout.fillWidth: true; text: "Cancel"; variant: "text"; onClicked: root.closePower() }
            }
        }
    }
}
