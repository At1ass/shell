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
    // playerctld is a proxy that mirrors whichever player is active — it
    // must never be selected or listed (duplicate entry, commands routed
    // to a moving target). kdeconnect exports one bus name per phone
    // player; they are listed but deprioritized in auto-pick.
    function _isProxy(p) {
        return (p?.dbusName ?? "") === "org.mpris.MediaPlayer2.playerctld"
    }
    function _isRemote(p) {
        return (p?.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.kdeconnect")
    }

    // Best default: playing local > playing > any local > any (never proxy).
    function _defaultPick(values) {
        const real = values.filter(p => !_isProxy(p))
        return real.find(p => p.isPlaying && !_isRemote(p))
            ?? real.find(p => p.isPlaying)
            ?? real.find(p => !_isRemote(p))
            ?? real[0] ?? null
    }

    // Set by explicit user selection; auto-retracking backs off then.
    property bool _userPinned: false

    property MprisPlayer trackedPlayer: null
    property MprisPlayer activePlayer: trackedPlayer ?? _defaultPick(Mpris.players.values)

    // ===== TRACK INFO =====
    signal trackChanged(reverse: bool)

    property bool __reverse: false
    property var activeTrack

    // ===== PLAYBACK STATE =====
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property var playbackState: activePlayer?.playbackState ?? MprisPlaybackState.Stopped

    // ===== POSITION & LENGTH (in seconds with millisecond precision) =====
    // Upstream semantics (Quickshell 0.3.0, service/mpris/player.cpp):
    //  - position EXTRAPOLATES (last known + elapsed x rate); it resyncs
    //    ONLY on Seeked, playback-status changes (with a 100 ms re-query),
    //    detected track changes, and local setPosition writes. Emitting
    //    positionChanged() just re-evaluates bindings — no D-Bus query.
    //  - length RETURNS POSITION VERBATIM when the player's metadata has
    //    no mpris:length (lengthSupported false) — treating that mirror
    //    as a real duration is how the runaway shorts display happened.
    readonly property bool positionSupported: activePlayer?.positionSupported ?? false
    readonly property bool lengthSupported: activePlayer?.lengthSupported ?? false

    // 0 = unknown duration. Never the position-mirror fallback.
    readonly property real length: {
        if (!lengthSupported) return 0
        const l = activePlayer?.length ?? 0
        return (isFinite(l) && l > 0) ? l : 0
    }

    // Folded into [0, length) for loop-without-Seeked players when a REAL
    // duration exists; raw (approximate) when duration is unknown.
    readonly property real position: {
        const raw = activePlayer?.position ?? 0
        const len = length
        if (len > 0 && isPlaying && raw > len)
            return raw % len
        return len > 0 ? Math.min(raw, len) : raw
    }

    // ===== LOOP & SHUFFLE =====
    readonly property var loopState: activePlayer?.loopState ?? MprisLoopState.None
    readonly property bool loopSupported: activePlayer?.loopSupported ?? false
    readonly property bool shuffle: activePlayer?.shuffle ?? false
    readonly property bool shuffleSupported: activePlayer?.shuffleSupported ?? false

    // ===== VOLUME & RATE =====
    readonly property real volume: activePlayer?.volume ?? 1.0
    readonly property bool volumeSupported: activePlayer?.volumeSupported ?? false
    readonly property real rate: activePlayer?.rate ?? 1.0
    readonly property real minRate: activePlayer?.minRate ?? 1.0
    readonly property real maxRate: activePlayer?.maxRate ?? 1.0

    // ===== PLAYER INFO =====
    readonly property string identity: activePlayer?.identity ?? ""
    readonly property string desktopEntry: activePlayer?.desktopEntry ?? ""

    // ===== CAPABILITIES =====
    readonly property bool canControl: activePlayer?.canControl ?? false
    readonly property bool canPlay: activePlayer?.canPlay ?? false
    readonly property bool canPause: activePlayer?.canPause ?? false
    // MPRIS has no CanStop; the Stop command is gated by CanControl.
    readonly property bool canStop: activePlayer?.canControl ?? false
    readonly property bool canTogglePlaying: activePlayer?.canTogglePlaying ?? false
    readonly property bool canGoNext: activePlayer?.canGoNext ?? false
    readonly property bool canGoPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canSeek: activePlayer?.canSeek ?? false
    readonly property bool canQuit: activePlayer?.canQuit ?? false
    readonly property bool canRaise: activePlayer?.canRaise ?? false
    readonly property bool canSetFullscreen: activePlayer?.canSetFullscreen ?? false

    // ===== PLAYER MANAGEMENT =====
    readonly property var availablePlayers: (Mpris.players.values ?? []).filter(p => !root._isProxy(p))

    function setActivePlayer(player: MprisPlayer) {
        root.trackedPlayer = player
        root._userPinned = player !== null
    }

    function switchToPlayer(index: int) {
        if (index >= 0 && index < availablePlayers.length) {
            root.trackedPlayer = availablePlayers[index]
            root._userPinned = true
        }
    }

    // Track player changes
    Connections {
        target: Mpris.players

        function onValuesChanged() {
            // If the current player disconnected
            if (root.trackedPlayer && !Mpris.players.values.includes(root.trackedPlayer)) {
                root.trackedPlayer = null
                root._userPinned = false
            }

            // Auto-pick (players register one by one at startup — the pick
            // re-runs on every arrival, so a later playing player replaces
            // an idle first-comer unless the user pinned one explicitly).
            if (!root._userPinned) {
                const pick = root._defaultPick(Mpris.players.values)
                if (pick && pick !== root.trackedPlayer
                    && !(root.trackedPlayer?.isPlaying ?? false)) {
                    root.trackedPlayer = pick
                }
            }
        }
    }

    // ===== TRACK CHANGE TRACKING =====
    Connections {
        target: root.activePlayer

        function onPostTrackChanged() {
            root.updateTrack()
        }

        // Players update metadata IN PLACE all the time: the initial GetAll
        // lands after the player object appears (startup art/title),
        // browsers switch videos without a detectable track change (static
        // trackid), duration arrives once the stream knows it. None of
        // those emit postTrackChanged — refresh the snapshot on every
        // metadata delivery, preserving the slide direction for the real
        // track-change handler.
        function onMetadataChanged() {
            const r = root.__reverse
            root.updateTrack()
            root.__reverse = r
        }
    }

    onActivePlayerChanged: updateTrack()

    function updateTrack() {
        if (!activePlayer) {
            activeTrack = null
            return
        }

        // Carry stale fields over ONLY for the same track (covers transient
        // empty artUrl while art loads). A different track/player must not
        // inherit the previous metadata.
        const prev = activeTrack || {}
        const id = activePlayer.uniqueId ?? 0
        const sameTrack = prev.uniqueId === id
        const newTrack = {
            uniqueId: id,
            artUrl: activePlayer.trackArtUrl || (sameTrack ? (prev.artUrl || "") : ""),
            title: activePlayer.trackTitle || (sameTrack ? (prev.title || "") : "") || "Unknown Title",
            artist: activePlayer.trackArtist || (sameTrack ? (prev.artist || "") : "") || "Unknown Artist",
            album: activePlayer.trackAlbum || (sameTrack ? (prev.album || "") : "") || "Unknown Album"
        }

        const hasChanges = prev.uniqueId !== newTrack.uniqueId ||
                          prev.title !== newTrack.title ||
                          prev.artist !== newTrack.artist ||
                          prev.album !== newTrack.album ||
                          prev.artUrl !== newTrack.artUrl

        if (hasChanges) {
            activeTrack = newTrack
            trackChanged(__reverse)
            // Snap position consumers to the new track right away. The
            // 1 Hz poke timer only runs WHILE PLAYING — switching tracks
            // while paused left the position label stale indefinitely.
            if (activePlayer.positionSupported)
                activePlayer.positionChanged()
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

    // ===== POSITION CONTROL (in seconds) =====
    function seek(offsetSeconds: real) {
        if (canSeek && activePlayer) {
            activePlayer.seek(offsetSeconds)
        }
    }

    function setPosition(seconds: real) {
        if (canSeek && positionSupported && activePlayer) {
            activePlayer.position = seconds
            // const currentPos = activePlayer.position ?? 0
            // activePlayer.seek(seconds - currentPos)

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
    // Recommended in the docs for live position updates
    Timer {
        id: positionTimer
        // The only position consumers live in the dashboard; ticking all
        // day during playback is pure churn (and each tick re-emits
        // lengthChanged upstream for length-less players).
        running: root.isPlaying && root.positionSupported && GlobalStates.dashboardOpen
        interval: 1000  // Update every second
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
            // Direct read — the C++ getter computes the live position;
            // root.position only refreshes on poke ticks.
            return root.activePlayer?.position ?? 0
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

    // ===== GLOBAL SHORTCUTS (optional) =====
    // Can be uncommented for global hotkeys
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
