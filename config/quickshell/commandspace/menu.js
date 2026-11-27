.pragma library

function searchableToken(value) {
    return String(value || "").replace(/[._-]+/g, " ")
}

function leafId(id) {
    var parts = String(id || "").split(".")
    return parts.length ? parts[parts.length - 1] : id
}

function nameSearchText(entry) {
    if (!entry)
        return ""
    var aliases = []
    var values = entry.aliases || []
    for (var i = 0; i < values.length; i++)
        aliases.push(searchableToken(values[i]))
    return [entry.label, searchableToken(leafId(entry.id)), aliases.join(" ")].join(" ").toLowerCase()
}

function termInWords(term, text) {
    var words = String(text || "").toLowerCase().split(/\s+/)
    for (var i = 0; i < words.length; i++) {
        if (words[i] === term)
            return true
    }
    return false
}

function matches(entry, query) {
    if (!entry || entry.id === "root" || entry.kind === "divider")
        return false
    var nameText = nameSearchText(entry)
    var description = String(entry.description || "").toLowerCase()
    var terms = String(query || "").toLowerCase().trim().split(/\s+/)
    for (var i = 0; i < terms.length; i++) {
        if (!terms[i])
            continue
        if (nameText.indexOf(terms[i]) >= 0)
            continue
        if (termInWords(terms[i], description))
            continue
        return false
    }
    return true
}

function depthFor(items, id) {
    var depth = 0
    var current = items[id]
    var guard = 0
    while (current && current.parent && current.parent !== "root" && guard < 32) {
        depth += 1
        current = items[current.parent]
        guard += 1
    }
    return depth
}

function pathFor(items, id) {
    var labels = []
    var current = items[id]
    var guard = 0
    while (current && current.id !== "root" && guard < 32) {
        labels.unshift(current.label)
        current = items[current.parent]
        guard += 1
    }
    return labels.join(" › ")
}

function parentPath(items, id) {
    var entry = items[id]
    if (!entry || !entry.parent || entry.parent === "root")
        return ""
    return pathFor(items, entry.parent)
}

function isDescendant(items, id, ancestorId) {
    if (ancestorId === "root")
        return id !== "root"
    var current = items[id]
    var guard = 0
    while (current && current.parent && guard < 32) {
        if (current.parent === ancestorId)
            return true
        current = items[current.parent]
        guard += 1
    }
    return false
}

// Same tiers as Omarchy 4.5 shell/plugins/menu/MenuModel.js searchScore().
function searchScore(items, entry, query) {
    var needle = String(query || "").toLowerCase().trim()
    var label = String(entry.label || "").toLowerCase()
    var nameText = nameSearchText(entry)
    var description = String(entry.description || "").toLowerCase()
    var score = 80

    if (label === needle)
        score = entry.parent === "root" ? 2 : 0
    else if (entry.kind === "app" && label.split(/\s+/).indexOf(needle) >= 0)
        score = 0
    else if (label.indexOf(needle) === 0)
        score = 10
    else if (label.indexOf(needle) >= 0)
        score = 30
    else if (nameText.indexOf(needle) >= 0)
        score = 40
    else if (needle && termInWords(needle, description))
        score = 60

    if (entry.kind === "menu")
        score -= 2
    if (entry.kind === "app")
        score -= 5

    return score * 1000 + depthFor(items, entry.id) * 25 + (entry.order || 0)
}
