pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer trackedPlayer: null
    property MprisPlayer activePlayer: trackedPlayer ?? Mpris.players.values[0] ?? null

    signal trackChanged(reverse: bool)

    property bool __reverse: false
    property var activeTrack

    // Track player changes
    Connections {
        target: Mpris.players

        function onValuesChanged() {
            if (!root.trackedPlayer && Mpris.players.values.length > 0) {
                // Find first playing player or just take the first one
                const playingPlayer = Mpris.players.values.find(p => p.isPlaying)
                root.trackedPlayer = playingPlayer ?? Mpris.players.values[0]
            }
        }
    }

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

    onActivePlayerChanged: this.updateTrack()

    function updateTrack() {
        if (!this.activePlayer) {
            this.activeTrack = null
            return
        }

        // Keep previous values if new ones are empty or undefined, but prefer real new data
        const prevTrack = this.activeTrack || {}
        const newTrack = {
            uniqueId: this.activePlayer.uniqueId ?? 0,
            artUrl: this.activePlayer.trackArtUrl || (prevTrack.artUrl || ""),
            title: this.activePlayer.trackTitle ? this.activePlayer.trackTitle : (prevTrack.title || "Unknown Title"),
            artist: this.activePlayer.trackArtist ? this.activePlayer.trackArtist : (prevTrack.artist || "Unknown Artist"),
            album: this.activePlayer.trackAlbum ? this.activePlayer.trackAlbum : (prevTrack.album || "Unknown Album")
        }

        // Only update if something actually changed
        const hasChanges = !prevTrack ||
                          prevTrack.uniqueId !== newTrack.uniqueId ||
                          prevTrack.title !== newTrack.title ||
                          prevTrack.artist !== newTrack.artist ||
                          prevTrack.album !== newTrack.album ||
                          prevTrack.artUrl !== newTrack.artUrl

        if (hasChanges) {
            this.activeTrack = newTrack
            this.trackChanged(__reverse)
        }

        this.__reverse = false
    }

    // Playback controls
    property bool isPlaying: this.activePlayer?.isPlaying ?? false
    property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false
    function togglePlaying() {
        if (this.canTogglePlaying) this.activePlayer.togglePlaying()
    }

    property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false
    function previous() {
        if (this.canGoPrevious) {
            this.__reverse = true
            this.activePlayer.previous()
        }
    }

    property bool canGoNext: this.activePlayer?.canGoNext ?? false
    function next() {
        if (this.canGoNext) {
            this.__reverse = false
            this.activePlayer.next()
        }
    }

    // Position control - disabled until proper API is found
    property bool canSeek: false
    function setPosition(positionMs: real) {
        // MPRIS setPosition API not available in current QuickShell version
        console.log("Seek to position requested but not implemented:", positionMs)
        if (this.activePlayer.positionSupported) {
            console.log("-----Seek to position requested but not implemented:", positionMs)

            this.activePlayer.seek(this.activePlayer.position + positionMs)
        }

        console.log("Seek to position requested but not implemented:", positionMs)
    }

    function setActivePlayer(player: MprisPlayer) {
        this.trackedPlayer = player
    }
}
