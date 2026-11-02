.pragma library

// Lua bind arguments are registry references, never command-line arguments.
function dispatcherInfo(value) {
    const name = String(value || "")
    const wrapped = /^HL\.Dispatcher(?:\(([^)]*)\))?$/.exec(name)
    return {
        name: wrapped ? (wrapped[1] || "") : name,
        indirect: wrapped !== null || name === "__lua" || /^function\s*:/.test(name)
    }
}

function categoryDispatcher(name) {
    const aliases = {
        exec_cmd: "exec", close: "killactive", float: "togglefloating",
        focus: "movefocus", move: "movewindow", swap: "swapwindow",
        drag: "mouse", resize: "resizeactive", layout: "layoutmsg",
        toggle_special: "togglespecialworkspace"
    }
    return aliases[name] || name
}

function executionText(bind) {
    if (dispatcherInfo(bind.dispatcher).indirect) return ""
    return [bind.dispatcher || "", bind.arg || ""].filter(Boolean).join(" ")
}

function fallbackDescription(bind) {
    const info = dispatcherInfo(bind.dispatcher)
    if (!info.indirect) return ""
    const labels = {
        exec_cmd: "Run command", global: "Global shortcut", close: "Close window",
        exit: "Exit compositor", float: "Change floating state", fullscreen: "Change fullscreen state",
        layout: "Change layout", focus: "Change focus", move: "Move window",
        swap: "Swap windows", drag: "Drag window", resize: "Resize window",
        submap: "Change keybinding mode", toggle_special: "Toggle special workspace"
    }
    return labels[info.name] || "Lua action (no description)"
}
