import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.components.base
import qs.services
import "." as Panel

MaterialCard {
    id: root

    property int currentTab: 0
    property int bottomTab: 0 // 0 = Calendar, 1 = Notes

    // Calendar properties
    property date currentDate: DateTime.clock.date
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    readonly property int actualYear: currentDate.getFullYear()
    property var calendarData: generateCalendarData(currentMonth, currentYear)
    property bool showDateSelector: false

    function generateCalendarData(month, year) {
        let firstDay = new Date(year, month, 1);
        let lastDay = new Date(year, month + 1, 0);
        let daysInMonth = lastDay.getDate();
        let startDayOfWeek = (firstDay.getDay() + 6) % 7; // Monday = 0

        let calendar = [];

        // Previous month's trailing days
        let prevMonth = month === 0 ? 11 : month - 1;
        let prevYear = month === 0 ? year - 1 : year;
        let prevMonthLastDay = new Date(prevYear, prevMonth + 1, 0).getDate();

        for (let i = startDayOfWeek - 1; i >= 0; i--) {
            calendar.push({
                day: prevMonthLastDay - i,
                isCurrentMonth: false,
                isPrevMonth: true,
                isNextMonth: false
            });
        }

        // Current month days
        for (let day = 1; day <= daysInMonth; day++) {
            calendar.push({
                day: day,
                isCurrentMonth: true,
                isPrevMonth: false,
                isNextMonth: false
            });
        }

        // Next month's leading days to fill the grid (42 cells = 6 weeks)
        let remainingCells = 42 - calendar.length;
        for (let day = 1; day <= remainingCells; day++) {
            calendar.push({
                day: day,
                isCurrentMonth: false,
                isPrevMonth: false,
                isNextMonth: true
            });
        }

        return calendar;
    }

    function previousMonth() {
        if (currentMonth === 0) {
            currentMonth = 11;
            currentYear--;
        } else {
            currentMonth--;
        }
        calendarData = generateCalendarData(currentMonth, currentYear);
    }

    function nextMonth() {
        if (currentMonth === 11) {
            currentMonth = 0;
            currentYear++;
        } else {
            currentMonth++;
        }
        calendarData = generateCalendarData(currentMonth, currentYear);
    }

    // Global overlay to close date selector when clicking anywhere
    MouseArea {
        anchors.fill: parent
        visible: root.showDateSelector
        onClicked: function (mouse) {
            // Only close if click is outside the selector area
            // The selector MouseArea should handle clicks inside
            console.log("Global overlay clicked - closing date selector");
            root.showDateSelector = false;
        }
        // z: 98
        propagateComposedEvents: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.spacing.medium
        spacing: Config.spacing.medium

        // Top section - Uptime and Quick Toggles
        Rectangle {
            id: topSection
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            color: Config.colors.surfaceContainer
            radius: Config.shape.medium

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.medium
                spacing: Config.spacing.small

                // First row - Uptime (left) and Time+Date (right)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing.medium

                    MaterialText {
                        text: "Uptime: " + DateTime.uptime
                        textStyle: "bodyMedium"
                        colorRole: "surfaceText"
                        Layout.alignment: Qt.AlignTop
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: Config.spacing.extraSmall
                        Layout.alignment: Qt.AlignTop

                        MaterialText {
                            text: DateTime.time
                            textStyle: "headlineSmall"
                            colorRole: "surfaceText"
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                        }

                        MaterialText {
                            text: DateTime.date
                            textStyle: "bodySmall"
                            colorRole: "surfaceVariantText"
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Third row - Quick toggle buttons (centered, no label)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Config.spacing.medium

                    Panel.QuickToggle {
                        toggleIcon: "wifi-high"
                        toggled: true // TODO: Connect to Network service
                        onClicked: {
                            toggled = !toggled;
                            console.log("WiFi toggled:", toggled);
                        }
                    }

                    Panel.QuickToggle {
                        toggleIcon: "bluetooth"
                        toggled: false // TODO: Connect to Bluetooth service
                        onClicked: {
                            toggled = !toggled;
                            console.log("Bluetooth toggled:", toggled);
                        }
                    }

                    Panel.QuickToggle {
                        toggleIcon: "bell-simple" // Do Not Disturb
                        toggled: false // TODO: Connect to Notification service
                        onClicked: {
                            toggled = !toggled;
                            console.log("DND toggled:", toggled);
                        }
                    }
                }
            }
        }

        // Middle section - Tabbed Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Config.spacing.small

            // Tab bar
            Rectangle {
                id: tabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Config.colors.surfaceContainerHigh
                radius: Config.shape.medium

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Config.spacing.small
                    spacing: 0

                    // Tab buttons
                    Repeater {
                        model: ["Dashboard", "Audio", "Settings"]

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Config.shape.small
                            color: index === root.currentTab ? Config.colors.primaryContainer : "transparent"

                            MaterialText {
                                anchors.centerIn: parent
                                text: modelData
                                textStyle: "labelMedium"
                                colorRole: index === root.currentTab ? "primaryContainerText" : "surfaceText"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentTab = index;
                                    console.log("Tab switched to:", modelData);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.motion.duration.short3
                                    easing.type: Config.motion.easing.standard
                                }
                            }
                        }
                    }
                }
            }

            // Tab content area
            Rectangle {
                id: tabContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Config.colors.surfaceContainer
                radius: Config.shape.medium

                // Tab content loader
                Loader {
                    id: tabLoader
                    anchors.fill: parent
                    anchors.margins: Config.spacing.medium

                    sourceComponent: {
                        switch (root.currentTab) {
                        case 0:
                            return dashboardTab;
                        case 1:
                            return audioTab;
                        case 2:
                            return settingsTab;
                        default:
                            return dashboardTab;
                        }
                    }
                }

                // Tab content components
                Component {
                    id: dashboardTab
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Config.spacing.medium

                        // System monitoring section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "System Monitor"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                // First row: CPU, RAM, CPU Temp
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.primaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "CPU"
                                                textStyle: "labelSmall"
                                                colorRole: "primaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "45%"
                                                textStyle: "labelLarge"
                                                colorRole: "primaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.secondaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "RAM"
                                                textStyle: "labelSmall"
                                                colorRole: "secondaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "8.2GB"
                                                textStyle: "labelLarge"
                                                colorRole: "secondaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.tertiaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "CPU °C"
                                                textStyle: "labelSmall"
                                                colorRole: "tertiaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "62°"
                                                textStyle: "labelLarge"
                                                colorRole: "tertiaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }
                                }

                                // Second row: GPU, Disk, GPU Temp
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.primaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "GPU"
                                                textStyle: "labelSmall"
                                                colorRole: "primaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "78%"
                                                textStyle: "labelLarge"
                                                colorRole: "primaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.secondaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "DISK"
                                                textStyle: "labelSmall"
                                                colorRole: "secondaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "156GB"
                                                textStyle: "labelLarge"
                                                colorRole: "secondaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48
                                        color: Config.colors.tertiaryContainer
                                        radius: Config.shape.small

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            MaterialText {
                                                text: "GPU °C"
                                                textStyle: "labelSmall"
                                                colorRole: "tertiaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            MaterialText {
                                                text: "71°"
                                                textStyle: "labelLarge"
                                                colorRole: "tertiaryContainerText"
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Notifications section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "Notifications"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    ColumnLayout {
                                        width: parent.width
                                        spacing: Config.spacing.small

                                        Repeater {
                                            model: [
                                                {title: "Firefox", text: "Download completed", time: "2m ago", icon: "🌐"},
                                                {title: "Discord", text: "New message from @user", time: "5m ago", icon: "💬"},
                                                {title: "System", text: "Updates available", time: "1h ago", icon: "⚙️"},
                                                {title: "Spotify", text: "Now playing: Song Title", time: "2h ago", icon: "🎵"}
                                            ]

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 60
                                                color: Config.colors.surface
                                                radius: Config.shape.small

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: Config.spacing.small
                                                    spacing: Config.spacing.medium

                                                    MaterialText {
                                                        text: modelData.icon
                                                        textStyle: "titleMedium"
                                                        Layout.preferredWidth: 24
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2

                                                        RowLayout {
                                                            Layout.fillWidth: true

                                                            MaterialText {
                                                                text: modelData.title
                                                                textStyle: "labelMedium"
                                                                colorRole: "surfaceText"
                                                                font.weight: Font.Medium
                                                                Layout.fillWidth: true
                                                            }

                                                            MaterialText {
                                                                text: modelData.time
                                                                textStyle: "labelSmall"
                                                                colorRole: "surfaceVariantText"
                                                            }
                                                        }

                                                        MaterialText {
                                                            text: modelData.text
                                                            textStyle: "bodySmall"
                                                            colorRole: "surfaceVariantText"
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // System tray section (compact)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "System Tray"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                // Tray apps row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    Repeater {
                                        model: 6

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            color: Config.colors.surface
                                            radius: Config.shape.small
                                            border.width: 1
                                            border.color: Config.colors.outline

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: ["🔷", "📁", "🔊", "🌐", "💬", "⚙️"][index]
                                                textStyle: "bodyMedium"
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    MaterialText {
                                        text: "+3"
                                        textStyle: "labelSmall"
                                        colorRole: "surfaceVariantText"
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: audioTab
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Config.spacing.medium

                        // Master volume section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.medium

                                MaterialText {
                                    text: "🔊"
                                    textStyle: "headlineSmall"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.extraSmall

                                    MaterialText {
                                        text: "Master Volume"
                                        textStyle: "titleSmall"
                                        colorRole: "surfaceText"
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        color: Config.colors.outline
                                        radius: 3

                                        Rectangle {
                                            width: parent.width * 0.65
                                            height: parent.height
                                            color: Config.colors.primary
                                            radius: 3
                                        }
                                    }
                                }

                                MaterialText {
                                    text: "65%"
                                    textStyle: "labelMedium"
                                    colorRole: "surfaceText"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // Audio devices section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true

                                    MaterialText {
                                        text: "Audio Devices"
                                        textStyle: "titleSmall"
                                        colorRole: "surfaceText"
                                    }

                                    Item { Layout.fillWidth: true }

                                    MaterialText {
                                        text: "⚙️"
                                        textStyle: "bodyMedium"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.small

                                    // Output device
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        color: Config.colors.primaryContainer
                                        radius: Config.shape.small

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🎧"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "Headphones (Active)"
                                                textStyle: "labelMedium"
                                                colorRole: "primaryContainerText"
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Input device
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        color: Config.colors.surface
                                        radius: Config.shape.small
                                        border.width: 1
                                        border.color: Config.colors.outline

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🎙️"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "Built-in Microphone"
                                                textStyle: "labelMedium"
                                                colorRole: "surfaceText"
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // App volume mixer
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "App Volume Mixer"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    ColumnLayout {
                                        width: parent.width
                                        spacing: Config.spacing.small

                                        Repeater {
                                            model: ["Firefox", "Discord", "Spotify", "System Sounds"]

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 50
                                                color: Config.colors.surface
                                                radius: Config.shape.small

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: Config.spacing.small
                                                    spacing: Config.spacing.medium

                                                    Rectangle {
                                                        Layout.preferredWidth: 24
                                                        Layout.preferredHeight: 24
                                                        color: Config.colors.primary
                                                        radius: 4

                                                        MaterialText {
                                                            anchors.centerIn: parent
                                                            text: modelData.charAt(0)
                                                            textStyle: "labelSmall"
                                                            colorRole: "primaryText"
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2

                                                        MaterialText {
                                                            text: modelData
                                                            textStyle: "labelMedium"
                                                            colorRole: "surfaceText"
                                                        }

                                                        Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 4
                                                            color: Config.colors.outline
                                                            radius: 2

                                                            Rectangle {
                                                                width: parent.width * (0.3 + index * 0.2)
                                                                height: parent.height
                                                                color: Config.colors.secondary
                                                                radius: 2
                                                            }
                                                        }
                                                    }

                                                    MaterialText {
                                                        text: Math.round((30 + index * 20)) + "%"
                                                        textStyle: "labelSmall"
                                                        colorRole: "surfaceVariantText"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: settingsTab
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Config.spacing.medium

                        // Display settings section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "Display Settings"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.medium

                                    // Brightness control
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.spacing.small

                                        MaterialText {
                                            text: "🔆 Brightness"
                                            textStyle: "labelMedium"
                                            colorRole: "surfaceText"
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 8
                                            color: Config.colors.outline
                                            radius: 4

                                            Rectangle {
                                                width: parent.width * 0.75
                                                height: parent.height
                                                color: Config.colors.primary
                                                radius: 4
                                            }
                                        }

                                        MaterialText {
                                            text: "75%"
                                            textStyle: "labelSmall"
                                            colorRole: "surfaceVariantText"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.fillHeight: true
                                        color: Config.colors.outline
                                    }

                                    // Resolution/Monitor
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.spacing.small

                                        MaterialText {
                                            text: "📺 Monitor"
                                            textStyle: "labelMedium"
                                            colorRole: "surfaceText"
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            color: Config.colors.primaryContainer
                                            radius: Config.shape.small

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: "1920×1080 @ 60Hz"
                                                textStyle: "labelSmall"
                                                colorRole: "primaryContainerText"
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            color: Config.colors.surface
                                            radius: Config.shape.small
                                            border.width: 1
                                            border.color: Config.colors.outline

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: "2560×1440 @ 144Hz"
                                                textStyle: "labelSmall"
                                                colorRole: "surfaceText"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // System settings section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "System Settings"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: Config.spacing.small
                                    columnSpacing: Config.spacing.medium

                                    // Night Light toggle
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: Config.colors.secondaryContainer
                                        radius: Config.shape.small

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🌙"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "Night Light"
                                                textStyle: "labelMedium"
                                                colorRole: "secondaryContainerText"
                                                Layout.fillWidth: true
                                            }
                                            MaterialText {
                                                text: "ON"
                                                textStyle: "labelSmall"
                                                colorRole: "secondaryContainerText"
                                            }
                                        }
                                    }

                                    // Auto rotate
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: Config.colors.surface
                                        radius: Config.shape.small
                                        border.width: 1
                                        border.color: Config.colors.outline

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🔄"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "Auto Rotate"
                                                textStyle: "labelMedium"
                                                colorRole: "surfaceText"
                                                Layout.fillWidth: true
                                            }
                                            MaterialText {
                                                text: "OFF"
                                                textStyle: "labelSmall"
                                                colorRole: "surfaceVariantText"
                                            }
                                        }
                                    }

                                    // Color profile
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: Config.colors.surface
                                        radius: Config.shape.small
                                        border.width: 1
                                        border.color: Config.colors.outline

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🎨"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "sRGB"
                                                textStyle: "labelMedium"
                                                colorRole: "surfaceText"
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Scaling
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: Config.colors.surface
                                        radius: Config.shape.small
                                        border.width: 1
                                        border.color: Config.colors.outline

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🔍"
                                                textStyle: "bodyMedium"
                                            }
                                            MaterialText {
                                                text: "100% Scale"
                                                textStyle: "labelMedium"
                                                colorRole: "surfaceText"
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Power management section
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Config.colors.surfaceContainerHigh
                            radius: Config.shape.medium

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Config.spacing.medium
                                spacing: Config.spacing.small

                                MaterialText {
                                    text: "Power Management"
                                    textStyle: "titleSmall"
                                    colorRole: "surfaceText"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Config.spacing.medium

                                    // Battery info (if applicable)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        color: Config.colors.tertiaryContainer
                                        radius: Config.shape.small

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Config.spacing.small
                                            spacing: Config.spacing.small

                                            MaterialText {
                                                text: "🔋"
                                                textStyle: "headlineSmall"
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                MaterialText {
                                                    text: "AC Power"
                                                    textStyle: "labelMedium"
                                                    colorRole: "tertiaryContainerText"
                                                }
                                                MaterialText {
                                                    text: "Plugged In"
                                                    textStyle: "labelSmall"
                                                    colorRole: "tertiaryContainerText"
                                                }
                                            }
                                        }
                                    }

                                    // Power actions
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Config.spacing.small

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28
                                            color: Config.colors.surface
                                            radius: Config.shape.small
                                            border.width: 1
                                            border.color: Config.colors.outline

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: "⏾ Suspend"
                                                textStyle: "labelSmall"
                                                colorRole: "surfaceText"
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28
                                            color: Config.colors.surface
                                            radius: Config.shape.small
                                            border.width: 1
                                            border.color: Config.colors.outline

                                            MaterialText {
                                                anchors.centerIn: parent
                                                text: "🔄 Restart"
                                                textStyle: "labelSmall"
                                                colorRole: "surfaceText"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom section - Calendar and Notes with tabs
        Rectangle {
            id: bottomSection
            Layout.fillWidth: true
            Layout.preferredHeight: 340
            color: Config.colors.surfaceContainer
            radius: Config.shape.medium

            RowLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing.medium
                spacing: Config.spacing.medium

                // Left side - Tab buttons
                ColumnLayout {
                    Layout.preferredWidth: 60
                    Layout.maximumWidth: 60
                    spacing: Config.spacing.small

                    Repeater {
                        model: ["Calendar", "Notes"]

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Config.shape.small
                            color: index === root.bottomTab ? Config.colors.primaryContainer : "transparent"

                            MaterialText {
                                anchors.centerIn: parent
                                text: modelData
                                textStyle: "labelSmall"
                                colorRole: index === root.bottomTab ? "primaryContainerText" : "surfaceText"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.bottomTab = index;
                                    console.log("Bottom tab switched to:", modelData);
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.motion.duration.short3
                                    easing.type: Config.motion.easing.standard
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Config.colors.outlineVariant
                    Layout.topMargin: Config.spacing.small
                    Layout.bottomMargin: Config.spacing.small
                }

                // Right side - Tab content
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        anchors.fill: parent
                        sourceComponent: {
                            switch (root.bottomTab) {
                            case 0:
                                return calendarComponent;
                            case 1:
                                return notesComponent;
                            default:
                                return calendarComponent;
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom tab components
    Component {
        id: calendarComponent
        ColumnLayout {
            spacing: Config.spacing.small

            // Month/Year header
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialText {
                    text: "<"
                    textStyle: "bodyMedium"
                    colorRole: "surfaceText"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.previousMonth()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Config.shape.small
                    color: "transparent"

                    MaterialText {
                        anchors.centerIn: parent
                        text: new Date(root.currentYear, root.currentMonth).toLocaleString(Qt.locale(), "MMMM yyyy")
                        textStyle: "labelMedium"
                        colorRole: "surfaceText"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showDateSelector = !root.showDateSelector;
                        }
                    }

                    // Combined date selector overlay
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200
                        height: 240
                        color: Config.colors.surfaceContainerHigh
                        radius: Config.shape.medium
                        border.width: 1
                        border.color: Config.colors.outlineVariant
                        visible: root.showDateSelector
                        // z: 99

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function (mouse) {
                                console.log("Date selector clicked - staying open");
                                // Consume the click to prevent propagation
                                mouse.accepted = true;
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Config.spacing.small
                            spacing: Config.spacing.small

                            // Year selector column
                            Column {
                                Layout.preferredWidth: 60
                                Layout.fillHeight: true
                                spacing: 2

                                MaterialText {
                                    text: "Year"
                                    textStyle: "labelSmall"
                                    colorRole: "surfaceVariantText"
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                PathView {
                                    id: yearPathView
                                    width: parent.width
                                    height: parent.height - 20
                                    model: 101

                                    delegate: Rectangle {
                                        width: yearPathView.width
                                        height: 30
                                        radius: Config.shape.small
                                        // property int yearValue: modelData
                                        property int yearValue: root.actualYear - 50 + modelData//index

                                        color: PathView.isCurrentItem ? Config.colors.primaryContainer : "transparent"

                                        MaterialText {
                                            anchors.centerIn: parent
                                            text: yearValue
                                            textStyle: "labelSmall"
                                            colorRole: PathView.isCurrentItem ? "primaryContainerText" : "surfaceText"
                                        }
                                    }

                                    path: Path {
                                        startX: yearPathView.width / 2
                                        startY: 0
                                        PathLine { x: yearPathView.width / 2; y: yearPathView.height }
                                    }

                                    pathItemCount: 7
                                    preferredHighlightBegin: 0.5
                                    preferredHighlightEnd: 0.5
                                    highlightRangeMode: PathView.StrictlyEnforceRange
                                    highlightMoveDuration: 200
                                    flickDeceleration: 1000
                                    maximumFlickVelocity: 1000

                                    Component.onCompleted: currentIndex = 50

                                    onCurrentIndexChanged: {
                                        const yearValue = root.actualYear - 50 + currentIndex
                                        root.currentYear = yearValue
                                        root.calendarData = root.generateCalendarData(root.currentMonth, root.currentYear)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: function (wheel) {
                                            if (wheel.angleDelta.y > 0) {
                                                yearPathView.decrementCurrentIndex()
                                            } else if (wheel.angleDelta.y < 0) {
                                                yearPathView.incrementCurrentIndex()
                                            }
                                            wheel.accepted = true
                                        }
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: Config.colors.outlineVariant
                            }

                            // Month selector column
                            Column {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2

                                MaterialText {
                                    text: "Month"
                                    textStyle: "labelSmall"
                                    colorRole: "surfaceVariantText"
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                PathView {
                                    id: monthPathView
                                    width: parent.width
                                    height: parent.height - 20
                                    model: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

                                    delegate: Rectangle {
                                        width: monthPathView.width
                                        height: 30
                                        radius: Config.shape.small
                                        // property int mounthValue: root.currentYear - 10 + index

                                        color: PathView.isCurrentItem ? Config.colors.primaryContainer : "transparent"

                                        MaterialText {
                                            anchors.centerIn: parent
                                            text: modelData
                                            textStyle: "labelSmall"
                                            colorRole: PathView.isCurrentItem ? "primaryContainerText" : "surfaceText"
                                        }
                                    }

                                    path: Path {
                                        startX: monthPathView.width / 2
                                        startY: 0
                                        PathLine { x: monthPathView.width / 2; y: monthPathView.height }
                                    }

                                    pathItemCount: 7
                                    preferredHighlightBegin: 0.5
                                    preferredHighlightEnd: 0.5
                                    highlightRangeMode: PathView.StrictlyEnforceRange
                                    highlightMoveDuration: 200

                                    Component.onCompleted: currentIndex = root.currentMonth
                                    onVisibleChanged: currentIndex = root.currentMonth

                                    onCurrentIndexChanged: {
                                        root.currentMonth = currentIndex
                                        root.calendarData = root.generateCalendarData(root.currentMonth, root.currentYear)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: function (wheel) {
                                            if (wheel.angleDelta.y > 0) {
                                                monthPathView.decrementCurrentIndex()
                                            } else if (wheel.angleDelta.y < 0 ) {
                                                monthPathView.incrementCurrentIndex()
                                            }
                                            wheel.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MaterialText {
                    text: ">"
                    textStyle: "bodyMedium"
                    colorRole: "surfaceText"
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            // Days grid
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                // Day headers
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    MaterialText {
                        text: modelData
                        textStyle: "labelSmall"
                        colorRole: "surfaceVariantText"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Calendar days
                Repeater {
                    model: root.calendarData
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 18
                        radius: 3

                        property bool isToday: modelData.isCurrentMonth && modelData.day === parseInt(Qt.locale().toString(DateTime.clock.date, "dd"))

                        color: isToday ? Config.colors.primary : "transparent"

                        MaterialText {
                            anchors.centerIn: parent
                            text: modelData.day
                            textStyle: "labelLarge"
                            colorRole: {
                                if (isToday)
                                    return "primaryText";
                                if (!modelData.isCurrentMonth)
                                    return "surfaceVariantText";
                                return "surfaceText";
                            }
                            opacity: modelData.isCurrentMonth ? 1.0 : 0.5
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.showDateSelector === false
                            onClicked: {
                                console.log("Day clicked:", modelData.day, modelData.isCurrentMonth ? "current" : modelData.isPrevMonth ? "prev" : "next");
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: notesComponent
        Rectangle {
            color: Config.colors.surfaceContainerHigh
            radius: Config.shape.small

            MaterialText {
                anchors.centerIn: parent
                text: "Quick notes\n& reminders\n\nClick to add..."
                textStyle: "bodySmall"
                colorRole: "surfaceVariantText"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    console.log("Notes area clicked - TODO: Add note functionality");
                }
            }
        }
    }
}
