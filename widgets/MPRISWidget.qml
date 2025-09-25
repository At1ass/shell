import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Mpris
import qs.components.base
import qs.config

BarElement {
    id: root
    minWidth: 220
    hoverEnabled: true

    // запоминаем выбранный плеер (по уникальному busName/identity)
    property string selectedId: ""
    readonly property MprisPlayer activePlayer: {
        // если выбранного нет — берём первый playing, иначе первый в списке
        let chosen = null
        for (let i = 0; i < Mpris.players.count; i++) {
            const p = Mpris.players.get(i)
            if (!p) continue
            if (root.selectedId && (p.busName === root.selectedId || p.identity === root.selectedId)) chosen = p
        }
        if (chosen) return chosen
        for (let i = 0; i < Mpris.players.count; i++) {
            const p = Mpris.players.get(i)
            if (p && p.isPlaying) return p
        }
        return Mpris.players.count > 0 ? Mpris.players.get(0) : null
    }

    // открытие меню выбора плеера правым кликом
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: if (mouse.button === Qt.RightButton) playerMenu.open()
        hoverEnabled: false
        propagateComposedEvents: true
    }

    // содержимое в баре: ⏮ ⏯ ⏭ и название
    contentItem: RowLayout {
        spacing: Config.spacing.small
        anchors.fill: parent

        ToolButton {
            text: "⏮"
            enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
            onClicked: root.activePlayer.previous()
        }

        ToolButton {
            text: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶"
            enabled: !!root.activePlayer
            onClicked: if (root.activePlayer) root.activePlayer.isPlaying = !root.activePlayer.isPlaying
        }

        ToolButton {
            text: "⏭"
            enabled: !!root.activePlayer && root.activePlayer.canGoNext
            onClicked: root.activePlayer.next()
        }

        // название трека
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                elide: Text.ElideRight
                font.pixelSize: 12
                color: Config.colors.onSurface
                text: root.activePlayer && root.activePlayer.track
                    ? (root.activePlayer.track.title || root.activePlayer.identity || "Воспроизведение")
                    : "Нет воспроизведения"
            }
            Text {
                elide: Text.ElideRight
                font.pixelSize: 11
                opacity: 0.7
                visible: !!(root.activePlayer && root.activePlayer.track)
                text: {
                    if (!root.activePlayer || !root.activePlayer.track) return ""
                    const a = root.activePlayer.track.artist || ""
                    const al = root.activePlayer.track.album || ""
                    return al ? `${a} — ${al}` : a
                }
            }
        }

        // индикатор/кнопка меню выбора плеера
        ToolButton {
            text: "▾"
            enabled: Mpris.players.count > 1
            onClicked: playerMenu.open()
            ToolTip.visible: hovered
            ToolTip.text: "Выбрать плеер"
        }
    }

    // меню со списком плееров
    Popup {
        id: playerMenu
        y: root.height + 6
        x: 0
        padding: 8
        modal: false
        focus: true
        background: Rectangle {
            radius: 10
            color: Config.colors.surface
            border.color: Config.colors.outline
        }

        ColumnLayout {
            spacing: 6
            Repeater {
                model: Mpris.players
                delegate: Item {
                    width: 260
                    height: 32
                    RowLayout {
                        anchors.fill: parent
                        spacing: 6
                        RadioButton {
                            checked: {
                                const pid = (modelData.busName || modelData.identity)
                                return pid === root.selectedId ||
                                       (!root.selectedId && model.index === 0)
                            }
                            onClicked: {
                                root.selectedId = (modelData.busName || modelData.identity)
                                playerMenu.close()
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.identity || "Плеер"
                            color: Config.colors.onSurface
                        }
                        // быстрые действия
                        ToolButton { text: "⏮"; enabled: modelData.canGoPrevious; onClicked: modelData.previous() }
                        ToolButton { text: modelData.isPlaying ? "⏸" : "▶"; onClicked: modelData.isPlaying = !modelData.isPlaying }
                        ToolButton { text: "⏭"; enabled: modelData.canGoNext; onClicked: modelData.next() }
                    }
                }
            }
            // если плееров нет
            Label {
                visible: Mpris.players.count === 0
                text: "Нет доступных MPRIS-плееров"
                opacity: 0.7
            }
        }
    }
}

