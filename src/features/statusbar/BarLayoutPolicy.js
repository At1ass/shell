.pragma library

// Geometry policy for the small configured widget list. Measurements are stable
// inputs; allocated widths and effective visibility must never feed back here.
function measure(entries, compact, hidden, moreWidth, gap) {
    const zones = {left:{minimum:0,preferred:0,count:0},center:{minimum:0,preferred:0,count:0},right:{minimum:0,preferred:0,count:0}}
    let hiddenCount = 0
    for (const entry of entries) {
        if (hidden.includes(entry.key)) { hiddenCount++; continue }
        const zone = zones[entry.section]
        if (!zone) continue
        if (zone.count++) { zone.minimum += gap; zone.preferred += gap }
        const small = compact.includes(entry.key)
        zone.minimum += small ? entry.compactMinimum : entry.minimum
        zone.preferred += small ? entry.compactPreferred : entry.preferred
    }
    if (hiddenCount) {
        const right = zones.right
        if (right.count++) { right.minimum += gap; right.preferred += gap }
        right.minimum += moreWidth; right.preferred += moreWidth
    }
    const active = Object.values(zones).filter(zone=>zone.count>0)
    return {zones:zones, minimum:active.reduce((total,zone)=>total+zone.minimum,0)+Math.max(0,active.length-1)*gap, hiddenCount:hiddenCount}
}

function plan(entries, width, gap, moreWidth, allowOverflow) {
    const compact = [], hidden = []
    let measured = measure(entries,compact,hidden,moreWidth,gap)
    const compress = entries.slice().sort((a,b)=>a.compactPriority-b.compactPriority || b.order-a.order)
    for (const entry of compress) {
        if (measured.minimum <= width) break
        if (entry.compactMinimum < entry.minimum) {
            compact.push(entry.key)
            measured = measure(entries,compact,hidden,moreWidth,gap)
        }
    }
    if (allowOverflow && measured.minimum > width) {
        const candidates = entries.slice().sort((a,b)=>a.priority-b.priority || b.order-a.order)
        for (const entry of candidates) {
            hidden.push(entry.key)
            measured = measure(entries,compact,hidden,moreWidth,gap)
            if (measured.minimum <= width) break
        }
    }
    return {compact:compact,hidden:hidden,zones:measured.zones,
        scroll:measured.minimum>width, width:Math.max(width,measured.minimum), hiddenCount:measured.hiddenCount}
}
