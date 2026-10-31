pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.core.config
import qs.src.core.services

ColumnLayout {
    id: root
    readonly property bool recorderEnabled: AppConfig.moduleEnabled("recorder")
    readonly property string recorderError: recorderEnabled ? RecorderService.errorMessage : ""
    visible: IdleInhibitorService.errorMessage !== "" || NightLightService.errorMessage !== "" || recorderError !== ""
    spacing: Tokens.spacing.extraSmall
    ListItem {
        Layout.fillWidth:true
        visible:IdleInhibitorService.errorMessage!==""
        clickable:false
        headline:"Caffeine"
        leadingIcon:"coffee"
        supportingText:IdleInhibitorService.errorMessage
        supportingTextFormat:Text.PlainText
    }
    MaterialButton {
        visible:IdleInhibitorService.errorMessage!==""
        text:"Retry"
        Accessible.name:"Retry caffeine"
        enabled:IdleInhibitorService.canRetry
        onClicked:IdleInhibitorService.retry()
    }
    ListItem {
        Layout.fillWidth: true
        visible: NightLightService.errorMessage !== ""
        clickable: false
        leadingIcon: "nightlight"
        headline: "Night light"
        supportingText: NightLightService.errorMessage
        supportingTextFormat: Text.PlainText
    }
    MaterialButton {
        objectName: "nightLightRetry"
        visible: NightLightService.errorMessage !== ""
        text: "Retry"
        Accessible.name: "Retry night light"
        enabled: NightLightService.canRetry
        onClicked: NightLightService.retry()
    }
    ListItem {
        Layout.fillWidth: true
        visible: root.recorderError !== ""
        clickable: false
        leadingIcon: "screen_record"
        headline: "Recording"
        supportingText: root.recorderError + (root.recorderEnabled && RecorderService.retryUnavailableReason ? "\n"+RecorderService.retryUnavailableReason : "")
        supportingTextFormat: Text.PlainText
    }
    MaterialButton {
        objectName: "recorderRetry"
        visible: root.recorderError !== ""
        text: "Retry"
        Accessible.name: "Retry recording operation"
        enabled: root.recorderEnabled && RecorderService.canRetry
        onClicked: RecorderService.retry()
    }
}
