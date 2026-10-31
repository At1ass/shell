pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Calendar
import qs.src.core.config
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.inputs

ColumnLayout {
    id: root
    property date anchorDate: new Date()
    readonly property bool active: visible && GlobalStates.dashboardOpen && GlobalStates.dashboardOpenIndex === 2
    property bool agendaExpanded: false
    property string requestId: ""
    property var results: []
    property bool truncated: false
    property string errorMessage: ""
    property bool _focusResults: false
    readonly property bool searching: search.text.trim() !== ""
    readonly property date today: new Date(DateTime.clock.date.getFullYear(),DateTime.clock.date.getMonth(),DateTime.clock.date.getDate())
    readonly property bool busy: debounce.running || requestId !== ""
    readonly property var range: {
        const from = new Date(searching ? anchorDate : today)
        from.setHours(0,0,0,0)
        if (searching) { from.setDate(1);from.setMonth(from.getMonth()-6);if(from.getFullYear()<1)from.setFullYear(1,0,1) }
        const to = new Date(from)
        to.setDate(to.getDate() + (searching ? 365 : 13))
        if (to.getFullYear()>9999)to.setFullYear(9999,11,31)
        return {from:from,to:to}
    }
    signal dateRequested(date value)
    spacing: Tokens.spacing.extraSmall
    function focusSearch() { search.inputItem.forceActiveFocus() }
    function schedule() {
        _focusResults=false
        requestId = ""
        results = []
        errorMessage = ""
        if (active && (searching || agendaExpanded)) debounce.restart()
        else debounce.stop()
    }
    function request() {
        if (!active || (!searching && !agendaExpanded)) return
        requestId = CalendarBackend.searchEvents(search.text.trim(),range.from,range.to)
    }
    function focusFirst() {
        if (_focusResults && active && rows.count>0) rows.itemAt(0).forceActiveFocus()
        _focusResults=false
    }
    onActiveChanged: schedule()
    onRangeChanged: schedule()
    onAgendaExpandedChanged: schedule()
    Timer { id:debounce;interval:200;onTriggered:root.request() }
    Connections {
        target: CalendarBackend
        function onEventsChanged() { root.schedule() }
        function onSearchFinished(id, events, more, error) {
            if (id !== root.requestId || !root.active) return
            root.requestId="";root.results=events;root.truncated=more;root.errorMessage=error
            Qt.callLater(root.focusFirst)
        }
    }
    MaterialTextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search events"
        Accessible.name: placeholderText
        leadingIcon: "search"
        trailingIcon: text ? "close" : ""
        onTrailingClicked: { text="";inputItem.forceActiveFocus() }
        onTextChanged: root.schedule()
        onAccepted: {
            root._focusResults=true
            if (debounce.running) { debounce.stop();root.request() }
            else if (!root.busy) root.focusFirst()
        }
    }
    ListItem {
        Layout.fillWidth: true
        visible: !root.searching
        headline: "Upcoming events"
        supportingText: "Next 14 days"
        trailingIcon: root.agendaExpanded ? "expand_less" : "expand_more"
        Accessible.expanded: root.agendaExpanded
        onClicked: root.agendaExpanded=!root.agendaExpanded
    }
    MaterialText {
        Layout.fillWidth: true
        visible: root.searching
        textStyle: "bodySmall"
        colorRole: "onSurfaceVariant"
        wrapMode: Text.Wrap
        text: Qt.formatDate(root.range.from,"yyyy-MM-dd")+" — "+Qt.formatDate(root.range.to,"yyyy-MM-dd")
    }
    MaterialText {
        Layout.fillWidth: true
        visible: root.searching || root.agendaExpanded
        textStyle: "bodySmall"
        colorRole: root.errorMessage ? "error" : "onSurfaceVariant"
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: root.busy ? "Loading events…" : root.errorMessage || (root.results.length===0 ? "No matching events"
            : root.truncated || root.results.length>(root.searching ? 20 : 3) ? "Showing the first "+(root.searching ? 20 : 3)+" events" : "")
    }
    Repeater {
        id: rows
        model: root.active && (root.searching || root.agendaExpanded) ? root.results.slice(0,root.searching ? 20 : 3) : []
        delegate: ListItem {
            required property var modelData
            Layout.fillWidth: true
            headline: modelData.title || "Untitled event"
            headlineTextFormat: Text.PlainText
            supportingText: Qt.formatDateTime(new Date(modelData.start),modelData.allDay ? "ddd, d MMM" : "ddd, d MMM HH:mm")
                + (modelData.location ? " · "+modelData.location : "")
            supportingTextFormat: Text.PlainText
            trailingIcon: "arrow_forward"
            onClicked: root.dateRequested(new Date(modelData.start))
        }
    }
}
