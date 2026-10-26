import QtQuick
import Quickshell.Services.SystemTray

// Visible and overflow groups share one live model, with stable arrival order.
QtObject {
    id: root
    property list<SystemTrayItem> items: []
    property list<string> pinnedIds: []
    property int limit: 4
    property Item anchorItem: null
    readonly property list<SystemTrayItem> orderedItems: Array.from(root.items)
        .map((item, index) => ({item, index, rank: root.pinnedIds.indexOf(item.id)}))
        .sort((a, b) => (a.rank < 0 ? root.pinnedIds.length : a.rank)
            - (b.rank < 0 ? root.pinnedIds.length : b.rank) || a.index - b.index)
        .map(entry => entry.item)
    readonly property list<SystemTrayItem> visibleItems: root.limit < 0
        ? root.orderedItems : root.orderedItems.slice(0, root.limit)
    readonly property list<SystemTrayItem> hiddenItems: root.limit < 0
        ? [] : root.orderedItems.slice(root.limit)
    readonly property int hiddenAttentionCount: root.hiddenItems.filter(item => item.status === Status.NeedsAttention).length
}
