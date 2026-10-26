import QtQuick
import QtQuick.Layouts
import qs.src.core.services
import qs.src.ui.base
import qs.src.ui.containers
import qs.src.ui.feedback
import qs.src.core.config

BarElement {
    id: clockWidget

    property var widgetConfig: null
    property var widgetSettings: widgetConfig?.settings ?? ({})

    property var tooltipManager: null

    // Driven by the SHARED SystemClock (minute precision) instead of a private
    // 1 Hz Timer. The bar is instantiated PER SCREEN, so that timer was one
    // wakeup per second per monitor — ~86k a day each — to refresh a string
    // that changes 1440 times. DateTime.clock is one clock for the whole
    // shell and Quickshell wakes it on the minute boundary, not on a drifting
    // interval.
    //
    // Seconds are the exception: they are needed when the user's own format
    // asks for them, and by the tooltip, which only exists while hovered. The
    // Timer below covers exactly those two cases and is otherwise stopped.
    readonly property bool _needsSeconds: timeFormat.indexOf("s") >= 0

    // NOT `property date _now: DateTime.clock.date`. The seconds Timer below
    // assigns to _now, and an imperative write SEVERS a binding permanently —
    // the clock would freeze after the first hover. Both sources push into a
    // plain property instead.
    property date _now: new Date()

    readonly property string currentTime: Qt.formatTime(_now, timeFormat)
    readonly property string currentDate: Qt.formatDate(_now, "dd MMM")
    readonly property string currentDateTime:
        Qt.formatDateTime(_now, "hh:mm:ss\ndddd, d MMMM yyyy")
    property string timeFormat: widgetSettings.format ?? "HH:mm"
    property bool showDate: widgetSettings.showDate ?? true

    preferredWidth: timeLabel.implicitWidth + Tokens.spacing.medium
        + (showDate ? dateLabel.implicitWidth + separator.implicitWidth + Tokens.spacing.extraSmall * 2 : 0)
    minimumWidth: preferredWidth
    compactWidth: timeLabel.implicitWidth + Tokens.spacing.medium

    // BarElement configuration
    expandOnHover: false
    clickable: true
    minWidth: Tokens.size.control + Tokens.spacing.medium

    nonVisualChildren: [
        Connections {
            target: DateTime.clock
            function onDateChanged() { clockWidget._now = DateTime.clock.date }
        },

        Timer {
            interval: 1000
            running: clockWidget._needsSeconds || (clockWidget.hovered && clockWidget.tooltipManager && !clockWidget.tooltipManager.suspended)
            repeat: true
            triggeredOnStart: true
            onTriggered: clockWidget._now = new Date()
        },

        // Tooltip with detailed date/time information
        TooltipItem {
            id: clockTooltip
            tooltip: clockWidget.tooltipManager
            owner: clockWidget
            show: clockWidget.hovered && clockWidget.barRevealed

            text: clockWidget.currentDateTime
        }
    ]

    clickHandler: function(mouse) {
        if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
            GlobalStates.handleClickAction(clockWidget.widgetConfig?.clickAction ?? "dashboard-calendar")
            mouse.accepted = true
            return
        }

        mouse.accepted = false
    }

    // Time display content
    RowLayout {
        spacing: Tokens.spacing.extraSmall

        MaterialText {
            id: timeLabel
            text: clockWidget.currentTime
            textStyle: "titleMedium"
            colorRole: "onSurface"
        }

        MaterialText {
            id: separator
            text: "•"
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
            visible: clockWidget.showDate && !clockWidget.compactPresentation
        }

        MaterialText {
            id: dateLabel
            text: clockWidget.currentDate
            textStyle: "bodyMedium"
            colorRole: "onSurfaceVariant"
            visible: clockWidget.showDate && !clockWidget.compactPresentation
        }
    }
}
