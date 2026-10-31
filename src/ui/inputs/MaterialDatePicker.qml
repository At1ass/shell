pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.src.core.config
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback

Dialog {
    id: root
    objectName: "materialDatePicker"
    property int firstDayOfWeek: 1
    property date value: new Date()
    property date cursorDate: new Date()
    readonly property int year: cursorDate.getFullYear()
    readonly property int month: cursorDate.getMonth()
    readonly property real cellSize: Math.max(Tokens.touchTarget.minimum,
        Tokens.typography.labelLarge.lineHeight+Tokens.spacing.small*2)
    readonly property var days: {
        const first=root.makeDate(year,month,1)
        const offset=(first.getDay()-firstDayOfWeek+7)%7
        return Array.from({length:42},(_,index)=>root.makeDate(year,month,index-offset+1))
    }
    signal dateChosen(date selected)
    dialogWidth: Tokens.size.fieldWidth*2+Tokens.spacing.large*2
    dialogHeight: form.implicitHeight+Tokens.spacing.medium*2
    function makeDate(year,month,day) { const date=new Date(0);date.setHours(0,0,0,0);date.setFullYear(year,month,day);return date }
    function sameDay(a,b) { return a.getFullYear()===b.getFullYear() && a.getMonth()===b.getMonth() && a.getDate()===b.getDate() }
    function openFor(date) {
        value=!isNaN(date.getTime()) && date.getFullYear()>=1 && date.getFullYear()<=9999 ? new Date(date) : new Date()
        cursorDate=new Date(value)
        open()
        Qt.callLater(focusCurrent)
    }
    function focusCurrent() {
        if (!visible || opacity===0) return
        const index=days.findIndex(date=>root.sameDay(date,cursorDate))
        const button=dates.itemAt(index)
        if (!button) return
        button.forceActiveFocus()
        Qt.callLater(revealCurrent)
    }
    function revealCurrent() {
        if(!visible || opacity===0)return
        const index=days.findIndex(date=>root.sameDay(date,cursorDate))
        const button=dates.itemAt(index)
        if(!button)return
        viewport.contentX=Math.max(0,Math.min(viewport.contentWidth-viewport.width,
            button.x<viewport.contentX ? button.x : button.x+button.width>viewport.contentX+viewport.width
                ? button.x+button.width-viewport.width : viewport.contentX))
    }
    function moveDays(delta) {
        const date=new Date(cursorDate);date.setDate(date.getDate()+delta)
        if (date.getFullYear()<1 || date.getFullYear()>9999) return
        cursorDate=date;Qt.callLater(focusCurrent)
    }
    function moveMonth(delta) {
        const first=makeDate(year,month+delta,1)
        if(first.getFullYear()<1 || first.getFullYear()>9999)return
        const last=makeDate(first.getFullYear(),first.getMonth()+1,0).getDate()
        cursorDate=makeDate(first.getFullYear(),first.getMonth(),Math.min(cursorDate.getDate(),last))
        Qt.callLater(focusCurrent)
    }
    function choose(date) {
        if(isNaN(date.getTime()) || date.getFullYear()<1 || date.getFullYear()>9999)return false
        dateChosen(new Date(date));close();return true
    }
    function dayKey(event) {
        const key=Keycodes.key(event)
        if (key===Qt.Key_Left || key===Qt.Key_H) moveDays(-1)
        else if (key===Qt.Key_Right || key===Qt.Key_L) moveDays(1)
        else if (key===Qt.Key_Up || key===Qt.Key_K) moveDays(-7)
        else if (key===Qt.Key_Down || key===Qt.Key_J) moveDays(7)
        else return
        event.accepted=true
    }
    ScrollableList {
        anchors.fill: parent
        contentPadding: Tokens.spacing.medium
        ColumnLayout {
            id: form
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            RowLayout {
                Layout.fillWidth: true
                IconButton {
                    iconName: "chevron_left"
                    Accessible.name: "Previous month"
                    enabled: root.year>1 || root.month>0
                    onClicked: root.moveMonth(-1)
                }
                MaterialText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.makeDate(root.year,root.month,1),"MMMM yyyy")
                    textStyle: "titleMedium"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
                IconButton {
                    iconName: "chevron_right"
                    Accessible.name: "Next month"
                    enabled: root.year<9999 || root.month<11
                    onClicked: root.moveMonth(1)
                }
            }
            Flickable {
                id: viewport
                Layout.fillWidth: true
                implicitHeight: grid.implicitHeight
                contentWidth: Math.max(width,grid.implicitWidth)
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                onWidthChanged: Qt.callLater(root.revealCurrent)
                GridLayout {
                    id: grid
                    width: viewport.contentWidth
                    columns: 7
                    columnSpacing: Tokens.spacing.extraSmall
                    rowSpacing: Tokens.spacing.extraSmall
                    Repeater {
                        model: 7
                        MaterialText {
                            required property int index
                            Layout.preferredWidth: root.cellSize
                            textStyle: "labelSmall"
                            colorRole: "onSurfaceVariant"
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().standaloneDayName((root.firstDayOfWeek+index)%7 || 7,Locale.ShortFormat)
                        }
                    }
                    Repeater {
                        id: dates
                        model: root.days
                        MaterialButton {
                            required property date modelData
                            implicitWidth: root.cellSize
                            implicitHeight: root.cellSize
                            leftPadding: 0
                            rightPadding: 0
                            Layout.preferredWidth: root.cellSize
                            Layout.preferredHeight: root.cellSize
                            text: modelData.getMonth()===root.month ? modelData.getDate() : ""
                            enabled: modelData.getMonth()===root.month && modelData.getFullYear()===root.year
                            activeFocusOnTab: root.sameDay(modelData,root.cursorDate)
                            variant: root.sameDay(modelData,root.value) ? "tonal" : "text"
                            Accessible.name: Qt.formatDate(modelData,"dddd, d MMMM yyyy")
                            Accessible.selected: root.sameDay(modelData,root.value)
                            onModelDataChanged: if(root.sameDay(modelData,root.cursorDate))Qt.callLater(root.focusCurrent)
                            onXChanged: if(activeFocus)Qt.callLater(root.revealCurrent)
                            onActiveFocusChanged: if(activeFocus) {
                                if(!root.sameDay(root.cursorDate,modelData))root.cursorDate=new Date(modelData)
                                Qt.callLater(root.revealCurrent)
                            }
                            Keys.onPressed: event=>root.dayKey(event)
                            onClicked: root.choose(modelData)
                        }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width>=today.implicitWidth+cancel.implicitWidth+columnSpacing ? 2 : 1
                columnSpacing: Tokens.spacing.small
                MaterialButton {
                    id: today
                    Layout.fillWidth: true
                    text: "Today"
                    onClicked: { root.cursorDate=new Date();Qt.callLater(root.focusCurrent) }
                }
                MaterialButton { id:cancel;Layout.fillWidth:true;text:"Cancel";variant:"text";onClicked:root.close() }
            }
        }
    }
}
