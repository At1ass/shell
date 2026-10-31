.pragma library

// A bounded calculation, even after years asleep: never replay missed phases.
function snapshot(state, now) {
    const idle = {status:"idle",mode:"timer",phase:"timer",stage:0,remainingMs:0,elapsedMs:0,round:0}
    if (!state || state.status === "idle") return idle
    if (!["running","paused","finished"].includes(state.status)
        || !["timer","pomodoro"].includes(state.mode)) return idle
    const valid = value => Number.isFinite(value) && value >= 0 && value <= 8640000000000000
    if (!valid(state.elapsedMs) || !valid(state.startedAt)) return idle
    const elapsed = state.elapsedMs + (state.status === "running" ? Math.max(0,now - state.startedAt) : 0)
    if (!valid(elapsed)) return idle
    if (state.mode === "timer") {
        if (!Number.isFinite(state.durationMs) || state.durationMs < 60000 || state.durationMs > 86400000) return idle
        return {status:elapsed >= state.durationMs ? "finished" : state.status,mode:"timer",phase:"timer",stage:0,
            remainingMs:Math.max(0,state.durationMs-elapsed),elapsedMs:Math.min(elapsed,state.durationMs),round:0}
    }
    for (const key of ["workMs","shortMs","longMs"])
        if (!Number.isFinite(state[key]) || state[key] < 60000 || state[key] > 86400000) return idle
    const count = state.longEvery
    if (!Number.isInteger(count) || count < 1 || count > 12 || state.status === "finished") return idle
    const cycleMs = count * state.workMs + (count-1)*state.shortMs + state.longMs
    const cycles = Math.floor(elapsed / cycleMs)
    const within = elapsed % cycleMs
    const regularSpan = (count-1)*(state.workMs+state.shortMs)
    const index = within >= regularSpan ? count-1 : Math.floor(within/(state.workMs+state.shortMs))
    const offset = within - index*(state.workMs+state.shortMs)
    const work = offset < state.workMs
    const duration = work ? state.workMs : index === count-1 ? state.longMs : state.shortMs
    return {status:state.status,mode:"pomodoro",phase:work ? "work" : index === count-1 ? "longBreak" : "shortBreak",
        stage:cycles*count*2+index*2+(work ? 0 : 1),round:index+1,
        remainingMs:duration-(work ? offset : offset-state.workMs),elapsedMs:elapsed}
}
