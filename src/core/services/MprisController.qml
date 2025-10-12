pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    // ===== PLAYER MANAGEMENT =====
    property MprisPlayer trackedPlayer: null
    property MprisPlayer activePlayer: trackedPlayer ?? Mpris.players.values[0] ?? null

    // ===== TRACK INFO =====
    signal trackChanged(reverse: bool)

    property bool __reverse: false
    property var activeTrack

    // ===== PLAYBACK STATE =====
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property var playbackState: activePlayer?.playbackState ?? MprisPlaybackState.Stopped

    // ===== POSITION & LENGTH (в секундах с миллисекундной точностью) =====
    readonly property real position: activePlayer?.position ?? 0
    readonly property bool positionSupported: activePlayer?.positionSupported ?? false
    readonly property real length: activePlayer?.length ?? 0
    readonly property bool lengthSupported: activePlayer?.lengthSupported ?? false

    // ===== LOOP & SHUFFLE =====
    property var loopState: activePlayer?.loopState ?? MprisLoopState.None
    readonly property bool loopSupported: activePlayer?.loopSupported ?? false
    property bool shuffle: activePlayer?.shuffle ?? false
    readonly property bool shuffleSupported: activePlayer?.shuffleSupported ?? false

    // ===== VOLUME & RATE =====
    property real volume: activePlayer?.volume ?? 1.0
    readonly property bool volumeSupported: activePlayer?.volumeSupported ?? false
    property real rate: activePlayer?.rate ?? 1.0
    readonly property real minRate: activePlayer?.minRate ?? 1.0
    readonly property real maxRate: activePlayer?.maxRate ?? 1.0

    // ===== PLAYER INFO =====
    readonly property string identity: activePlayer?.identity ?? ""
    readonly property string desktopEntry: activePlayer?.desktopEntry ?? ""

    // ===== CAPABILITIES =====
    readonly property bool canControl: activePlayer?.canControl ?? false
    readonly property bool canPlay: activePlayer?.canPlay ?? false
    readonly property bool canPause: activePlayer?.canPause ?? false
    readonly property bool canStop: activePlayer?.canStop ?? false
    readonly property bool canTogglePlaying: activePlayer?.canTogglePlaying ?? false
    readonly property bool canGoNext: activePlayer?.canGoNext ?? false
    readonly property bool canGoPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canSeek: activePlayer?.canSeek ?? false
    readonly property bool canQuit: activePlayer?.canQuit ?? false
    readonly property bool canRaise: activePlayer?.canRaise ?? false
    readonly property bool canSetFullscreen: activePlayer?.canSetFullscreen ?? false

    // ===== PLAYER MANAGEMENT =====
    readonly property var availablePlayers: Mpris.players.values ?? []

    function setActivePlayer(player: MprisPlayer) {
        root.trackedPlayer = player
    }

    function switchToPlayer(index: int) {
        if (index >= 0 && index < availablePlayers.length) {
            root.trackedPlayer = availablePlayers[index]
        }
    }

    // Track player changes
    Connections {
        target: Mpris.players

        function onValuesChanged() {
            // Если текущий плеер отключился
            if (root.trackedPlayer && !Mpris.players.values.includes(root.trackedPlayer)) {
                root.trackedPlayer = null
            }

            // Автоматический выбор нового плеера
            if (!root.trackedPlayer && Mpris.players.values.length > 0) {
                const playingPlayer = Mpris.players.values.find(p => p.isPlaying)
                root.trackedPlayer = playingPlayer ?? Mpris.players.values[0]
            }
        }
    }

    // ===== TRACK CHANGE TRACKING =====
    Connections {
        target: activePlayer

        function onPostTrackChanged() {
            root.updateTrack()
        }

        function onTrackArtUrlChanged() {
            if (root.activePlayer?.uniqueId == root.activeTrack?.uniqueId) {
                const r = root.__reverse
                root.updateTrack()
                root.__reverse = r
            }
        }
    }

    onActivePlayerChanged: updateTrack()

    function updateTrack() {
        if (!activePlayer) {
            activeTrack = null
            return
        }

        const prevTrack = activeTrack || {}
        const newTrack = {
            uniqueId: activePlayer.uniqueId ?? 0,
            artUrl: activePlayer.trackArtUrl || (prevTrack.artUrl || ""),
            title: activePlayer.trackTitle || (prevTrack.title || "Unknown Title"),
            artist: activePlayer.trackArtist || (prevTrack.artist || "Unknown Artist"),
            album: activePlayer.trackAlbum || "Unknown Album"
        }

        const hasChanges = !prevTrack ||
                          prevTrack.uniqueId !== newTrack.uniqueId ||
                          prevTrack.title !== newTrack.title ||
                          prevTrack.artist !== newTrack.artist ||
                          prevTrack.album !== newTrack.album ||
                          prevTrack.artUrl !== newTrack.artUrl

        if (hasChanges) {
            activeTrack = newTrack
            trackChanged(__reverse)
        }

        __reverse = false
    }

    // ===== PLAYBACK CONTROLS =====
    function play() {
        if (canPlay && activePlayer) {
            activePlayer.play()
        }
    }

    function pause() {
        if (canPause && activePlayer) {
            activePlayer.pause()
        }
    }

    function stop() {
        if (canStop && activePlayer) {
            activePlayer.stop()
        }
    }

    function togglePlaying() {
        if (canTogglePlaying && activePlayer) {
            activePlayer.togglePlaying()
        }
    }

    function next() {
        if (canGoNext && activePlayer) {
            __reverse = false
            activePlayer.next()
        }
    }

    function previous() {
        if (canGoPrevious && activePlayer) {
            __reverse = true
            activePlayer.previous()
        }
    }

    // ===== POSITION CONTROL (в секундах) =====
    function seek(offsetSeconds: real) {
        if (canSeek && activePlayer) {
            activePlayer.seek(offsetSeconds)
        }
    }

    function setPosition(seconds: real) {
        if (canSeek && positionSupported && activePlayer) {
            const currentPos = activePlayer.position ?? 0
            activePlayer.seek(seconds - currentPos)
        }
    }

    // ===== VOLUME & RATE CONTROL =====
    function setVolume(volume: real) {
        if (volumeSupported && canControl && activePlayer) {
            activePlayer.volume = Math.max(0, Math.min(1, volume))
        }
    }

    function setRate(rate: real) {
        if (canControl && activePlayer) {
            activePlayer.rate = Math.max(minRate, Math.min(maxRate, rate))
        }
    }

    // ===== LOOP & SHUFFLE CONTROL =====
    function toggleLoop() {
        if (loopSupported && canControl && activePlayer) {
            const states = [MprisLoopState.None, MprisLoopState.Track, MprisLoopState.Playlist]
            const currentIndex = states.indexOf(loopState)
            const nextIndex = (currentIndex + 1) % states.length
            activePlayer.loopState = states[nextIndex]
        }
    }

    function setLoopState(state: var) {
        if (loopSupported && canControl && activePlayer) {
            activePlayer.loopState = state
        }
    }

    function toggleShuffle() {
        if (shuffleSupported && canControl && activePlayer) {
            activePlayer.shuffle = !activePlayer.shuffle
        }
    }

    function setShuffle(enabled: bool) {
        if (shuffleSupported && canControl && activePlayer) {
            activePlayer.shuffle = enabled
        }
    }

    // ===== WINDOW CONTROL =====
    function raise() {
        if (canRaise && activePlayer) {
            activePlayer.raise()
        }
    }

    function quit() {
        if (canQuit && activePlayer) {
            activePlayer.quit()
        }
    }

    // ===== URI CONTROL =====
    function openUri(uri: string) {
        if (activePlayer) {
            activePlayer.openUri(uri)
        }
    }

    // ===== POSITION TRACKING TIMER =====
    // Рекомендовано в документации для live position updates
    Timer {
        id: positionTimer
        running: root.isPlaying && root.positionSupported
        interval: 1000  // Обновляем каждую секунду
        repeat: true
        onTriggered: {
            if (root.activePlayer && root.positionSupported) {
                root.activePlayer.positionChanged()
            }
        }
    }

    // ===== IPC COMMANDS =====
    IpcHandler {
        target: "mpris"

        function play(): void {
            root.play()
        }

        function pause(): void {
            root.pause()
        }

        function stop(): void {
            root.stop()
        }

        function togglePlaying(): void {
            root.togglePlaying()
        }

        function next(): void {
            root.next()
        }

        function previous(): void {
            root.previous()
        }

        function seek(offset: real): void {
            root.seek(offset)
        }

        function setPosition(position: real): void {
            root.setPosition(position)
        }

        function setVolume(volume: real): void {
            root.setVolume(volume)
        }

        function volumeUp(): void {
            root.setVolume(root.volume + 0.05)
        }

        function volumeDown(): void {
            root.setVolume(root.volume - 0.05)
        }

        function toggleShuffle(): void {
            root.toggleShuffle()
        }

        function toggleLoop(): void {
            root.toggleLoop()
        }

        function raise(): void {
            root.raise()
        }

        function quit(): void {
            root.quit()
        }

        function getPosition(): real {
            return root.position
        }

        function getLength(): real {
            return root.length
        }

        function getVolume(): real {
            return root.volume
        }

        function isPlaying(): bool {
            return root.isPlaying
        }

        function getCurrentTrack(): string {
            if (!root.activeTrack) return ""
            return JSON.stringify(root.activeTrack)
        }
    }

    // ===== GLOBAL SHORTCUTS (опционально) =====
    // Можно раскомментировать для глобальных хоткеев
    /*
    GlobalShortcut {
        name: "mprisPlayPause"
        description: "Toggle play/pause"
        onPressed: root.togglePlaying()
    }

    GlobalShortcut {
        name: "mprisNext"
        description: "Next track"
        onPressed: root.next()
    }

    GlobalShortcut {
        name: "mprisPrevious"
        description: "Previous track"
        onPressed: root.previous()
    }

    GlobalShortcut {
        name: "mprisStop"
        description: "Stop playback"
        onPressed: root.stop()
    }
    */
}
