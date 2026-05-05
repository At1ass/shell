import QtQuick

// Abstract template for wallpaper sources. Concrete subclasses
// (LocalDirectorySource, WallhavenSource, ...) inherit by setting the
// root element to BaseWallpaperSource and overriding behaviour.
//
// Item shape (each entry in `items`):
//   {
//     id:        string  // unique within this source
//     name:      string  // human-readable (file name, remote slug, ...)
//     url:       string  // file path or http(s) URL
//     thumbnail: string  // optional preview image (path or URL)
//     metadata:  object  // optional source-specific data (resolution, tags)
//   }
//
// Lifecycle:
//   1. Manager constructs source with sourceId + source-specific config
//   2. Manager calls refresh()
//   3. Source populates `items`, sets ready=true (loading=false)
//   4. Manager iterates items, calls resolveItem(itemId) to get a local
//      path suitable for the Wallpaper component to render

QtObject {
    id: root

    // Identity
    required property string sourceId
    property string name: sourceId
    property string iconName: "image"

    // Lifecycle / status
    property bool ready: false
    property bool loading: false
    property string lastError: ""

    // Items (populated by refresh()); see shape above.
    property var items: []

    signal itemsRefreshed()
    signal errorOccurred(string message)

    // Public API — concrete sources override.

    // Reload items from the underlying source. Local: rescan directory.
    // Remote: API call. Should set loading flag, populate items, emit
    // itemsRefreshed when done.
    function refresh() {
        console.warn(name + ": refresh() not implemented")
    }

    // Resolve an item to a local file path the Wallpaper component can
    // render. Local sources: identity (item.url is already a path).
    // Remote sources: download via WallpaperCache, return cached path.
    // Returns "" on failure or if item not found.
    function resolveItem(itemId) {
        const it = findItem(itemId)
        return it ? it.url : ""
    }

    // Optional: load more items (pagination for remote sources). No-op
    // by default.
    function loadMore() {}

    // Helper: find item by id, null if absent.
    function findItem(itemId) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].id === itemId) return items[i]
        }
        return null
    }

    // Helper: emit error and update state.
    function _setError(msg) {
        lastError = msg
        loading = false
        errorOccurred(msg)
    }
}
