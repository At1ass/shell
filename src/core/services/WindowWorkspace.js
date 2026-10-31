.pragma library

// A single membership rule for the bar and overview. The native QObject may
// lag behind the latest compositor client snapshot during a transfer.
function id(window) {
    return window?.lastIpcObject?.workspace?.id ?? window?.workspace?.id
}
function group(windows) {
    const result = Object.create(null)
    for (const window of windows) {
        const workspaceId = id(window)
        if (workspaceId === undefined || workspaceId === null) continue
        if (!result[workspaceId]) result[workspaceId] = []
        result[workspaceId].push(window)
    }
    return result
}
