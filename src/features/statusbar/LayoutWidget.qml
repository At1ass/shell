import QtQuick
import QtQuick.Controls
import qs.src.ui.containers
import qs.src.ui.inputs
import qs.src.ui.feedback
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.src.ui.base
import qs.src.core.config

BarElement {
    id: layoutWidget

    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    property var layoutCodes: []
    property var cachedLayoutCodes: ({})
    property bool capsLockEnabled: false
    property bool numLockEnabled: false

    // BarElement configuration
    clickable: true
    hoverable: true
    minWidth: 48
    expandOnHover: false
    animated: true

    // Показывать только если есть несколько раскладок
    visible: layoutCodes.length > 1

    onClicked: {
        layoutWidget.switchLayout()
    }

    // Получение текущих раскладок при инициализации
    nonVisualChildren: [
        Process {
            id: fetchLayoutsProcess
            running: true
            command: ["hyprctl", "-j", "devices"]

            stdout: StdioCollector {
                id: devicesCollector
                onStreamFinished: {
                    try {
                        const parsedOutput = JSON.parse(devicesCollector.text)
                        const hyprlandKeyboard = parsedOutput["keyboards"].find(kb => kb.main === true)
                        if (hyprlandKeyboard) {
                            layoutWidget.layoutCodes = hyprlandKeyboard["layout"].split(",")
                            layoutWidget.currentLayoutName = hyprlandKeyboard["active_keymap"]
                            layoutWidget.capsLockEnabled = hyprlandKeyboard["capsLock"] || false
                            layoutWidget.numLockEnabled = hyprlandKeyboard["numLock"] || false
                        }
                    } catch (e) {
                        console.warn("LayoutWidget: Ошибка парсинга devices:", e)
                    }
                }
            }
        },

        Process {
            id: getLayoutCodeProcess
            command: ["cat", "/usr/share/X11/xkb/rules/base.lst"]

            stdout: StdioCollector {
                id: layoutCollector
                onStreamFinished: {
                    const lines = layoutCollector.text.split("\n")
                    const targetDescription = layoutWidget.currentLayoutName
                    const foundLine = lines.find(line => {
                        if (!line.trim() || line.trim().startsWith('!'))
                            return false

                        const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/)
                        if (matchLayout && matchLayout[2] === targetDescription) {
                            layoutWidget.cachedLayoutCodes[matchLayout[2]] = matchLayout[1]
                            layoutWidget.currentLayoutCode = matchLayout[1]
                            return true
                        }

                        const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/)
                        if (matchVariant && matchVariant[3] === targetDescription) {
                            const complexLayout = matchVariant[2] + matchVariant[1]
                            layoutWidget.cachedLayoutCodes[matchVariant[3]] = complexLayout
                            layoutWidget.currentLayoutCode = complexLayout
                            return true
                        }

                        return false
                    })
                }
            }
        },

        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (event.name === "activelayout") {
                    if (layoutWidget.layoutCodes.length <= 1) return

                    const dataString = event.data
                    layoutWidget.currentLayoutName = dataString.split(",")[1]
                }
            }
        },

        Process {
            id: switchProcess
            running: false
        },

        // Периодическое обновление состояния клавиатуры
        Timer {
            id: keyboardStateTimer
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: false

            onTriggered: {
                fetchLayoutsProcess.running = true
            }
        }
    ]

    // Обновление кода раскладки при изменении имени
    onCurrentLayoutNameChanged: updateLayoutCode()

    function updateLayoutCode() {
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            currentLayoutCode = cachedLayoutCodes[currentLayoutName]
        } else {
            getLayoutCodeProcess.running = true
        }
    }

    // Функция переключения раскладки через hyprctl
    function switchLayout() {
        if (layoutCodes.length <= 1) return

        const currentIndex = layoutCodes.findIndex(layout => layout === currentLayoutCode)
        const nextIndex = (currentIndex + 1) % layoutCodes.length
        const nextLayout = layoutCodes[nextIndex]

        // Переключение через hyprctl
        switchProcess.command = ["hyprctl", "switchxkblayout", "main", "next"]
        switchProcess.running = true

        // console.log(`Переключение раскладки: ${currentLayoutCode} -> ${nextLayout}`)
    }

    Column {
        // anchors.centerIn: parent
        spacing: 2

        // Отображение текущей раскладки
        MaterialText {
            text: layoutWidget.currentLayoutCode.toUpperCase() || "EN"
            textStyle: "titleMedium"
            colorRole: layoutWidget.hovered ? "primary" : "onSurface"
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
                ColorAnimation {
                    duration: Config.motion.duration.short3
                    easing.type: Config.motion.easing.standard
                }
            }
        }

        // Индикаторы Caps/NumLock
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            // CapsLock индикатор
            MaterialIndicator {
                id: capsIndicator
                size: "extraSmall"
                colorRole: layoutWidget.capsLockEnabled ? "primary" : "outline"
                shape: "rounded"
                visible: layoutWidget.capsLockEnabled

                MouseArea {
                    id: capsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    ToolTip {
                        text: "Caps Lock"
                        visible: capsMouseArea.containsMouse
                        delay: 1000
                    }
                }
            }

            // NumLock индикатор
            MaterialIndicator {
                id: numIndicator
                size: "extraSmall"
                colorRole: layoutWidget.numLockEnabled ? "secondary" : "outline"
                shape: "rounded"
                visible: layoutWidget.numLockEnabled

                MouseArea {
                    id: numMouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    ToolTip {
                        text: "Num Lock"
                        visible: numMouseArea.containsMouse
                        delay: 1000
                    }
                }
            }
        }
    }
}
