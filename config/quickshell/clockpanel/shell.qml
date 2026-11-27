import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "calendar.js" as Calendar
import "sun.js" as Sun
import "land.js" as Land

// Clicking the center clock opens this panel: live time with seconds, a month
// grid, year progress, sunrise and sunset, and a day/night world map with
// clocks for home and a handful of cities.
PanelWindow {
    id: root

    property bool opened: false
    property date now: new Date()
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property string weekStartSetting: ""
    property var weeks: []
    property int weekEpoch: 0
    property var weekdayLabels: []
    property string localZone: ""
    property var offsets: ({})
    property int offsetEpoch: 0
    property var coords: ({})
    property int coordEpoch: 0
    property var allZones: []
    property var cities: []
    property int cityEpoch: 0
    property bool configLoaded: false
    property bool triedConfig: false
    property bool famousReady: false
    property bool configDirReady: false
    property bool savePending: false
    property bool searching: false
    property string query: ""
    property var matches: []
    property int matchEpoch: 0
    property int searchIndex: 0
    property var probeQueue: []
    property string pointerHint: ""

    readonly property color background: "#1a1b26"
    readonly property color foreground: "#e4e1e7"
    readonly property color muted: "#9aa0b8"
    readonly property color faint: "#5c6378"
    readonly property color accent: "#7aa2f7"
    readonly property color sunColor: "#f6c177"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int borderWidth: 2
    readonly property int panelPad: 18
    readonly property int inset: borderWidth + panelPad
    readonly property int cardWidth: Math.max(320, Math.min(960, width - 40))
    readonly property int columnGap: 28
    readonly property int calWidth: Math.floor((cardWidth - inset * 2 - columnGap) * 0.48)
    readonly property int worldWidth: cardWidth - inset * 2 - columnGap - calWidth
    readonly property int weekCol: 28
    readonly property int calSpacing: 3
    readonly property int cellH: 30
    readonly property int cellW: Math.floor((calWidth - weekCol - calSpacing * 7) / 7)
    readonly property int cityCap: 8

    readonly property string configDir: {
        var base = Quickshell.env("XDG_STATE_HOME")
        if (!base)
            base = Quickshell.env("HOME") + "/.local/state"
        return base + "/changteezy/clockpanel"
    }
    readonly property string configPath: configDir + "/config.json"

    readonly property bool viewingCurrentMonth: viewYear === now.getFullYear() && viewMonth === now.getMonth()
    readonly property string gridStamp: viewYear + ":" + viewMonth + ":" + weekStart + ":"
        + now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate()
    readonly property int weekStart: {
        if (weekStartSetting === "sunday")
            return 7
        if (weekStartSetting === "monday")
            return 1
        var first = Qt.locale().firstDayOfWeek
        return (first >= 1 && first <= 7) ? first : 1
    }
    readonly property real yearFraction: Calendar.yearProgress(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property int yearPercent: Calendar.yearProgressPercent(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property int dayOfYear: Calendar.dayOfYear(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property int daysInYear: Calendar.daysInYear(now.getFullYear())
    readonly property int quarter: Math.floor(now.getMonth() / 3) + 1
    readonly property int weekNumber: Calendar.isoWeek(now.getFullYear(), now.getMonth(), now.getDate())
    readonly property string minuteStamp: now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate()
        + "-" + now.getHours() + "-" + now.getMinutes()
    readonly property int rowCount: 1 + (cities ? cities.length : 0)
    readonly property int matchCount: matches ? matches.length : 0
    readonly property string footerHint: pointerHint.length > 0
        ? pointerHint
        : "← → month     ↑ ↓ year     T today     W week start     / add city     Esc close"

    function digits(n) {
        return (n < 10 ? "0" : "") + n
    }

    function zoneCity(zone) {
        if (!zone || zone.length === 0)
            return "Local"
        var parts = String(zone).split("/")
        return parts[parts.length - 1].replace(/_/g, " ")
    }

    function formatUtcOffset(mins) {
        var sign = mins >= 0 ? "+" : "-"
        var a = Math.abs(mins)
        return "UTC" + sign + Math.floor(a / 60) + ":" + digits(a % 60)
    }

    function formatDelta(mins) {
        if (mins === 0)
            return "same time"
        var sign = mins > 0 ? "+" : "−"
        var a = Math.abs(mins)
        var h = Math.floor(a / 60)
        var m = a % 60
        if (m === 0)
            return sign + h + "h"
        return sign + h + "h " + digits(m) + "m"
    }

    function localOffsetMinutes() {
        var probed = offsets[localZone]
        if (probed !== undefined && probed !== null)
            return probed
        return -now.getTimezoneOffset()
    }

    function zonedParts(ms, offsetMin) {
        var d = new Date(ms + offsetMin * 60000)
        return {
            h: d.getUTCHours(),
            mi: d.getUTCMinutes(),
            s: d.getUTCSeconds(),
            y: d.getUTCFullYear(),
            mo: d.getUTCMonth(),
            da: d.getUTCDate()
        }
    }

    function offsetFor(zone) {
        var value = offsets[zone]
        if (value === undefined || value === null)
            return NaN
        return value
    }

    function clockText(date) {
        return digits(date.getHours()) + ":" + digits(date.getMinutes())
    }

    function secondsText(date) {
        return ":" + digits(date.getSeconds())
    }

    function dateLine(date) {
        var loc = Qt.locale()
        var qt = date.getDay() === 0 ? 7 : date.getDay()
        return loc.dayName(qt, Locale.LongFormat) + ", " + date.getDate() + " "
            + loc.monthName(date.getMonth(), Locale.LongFormat) + " " + date.getFullYear()
    }

    function zoneLine() {
        var name = localZone && localZone.length > 0 ? localZone : "Local"
        return name + "   ·   " + formatUtcOffset(localOffsetMinutes())
    }

    function isoStamp(date) {
        var off = -date.getTimezoneOffset()
        var sign = off >= 0 ? "+" : "-"
        var a = Math.abs(off)
        return date.getFullYear() + "-" + digits(date.getMonth() + 1) + "-" + digits(date.getDate())
            + "T" + digits(date.getHours()) + ":" + digits(date.getMinutes()) + ":" + digits(date.getSeconds())
            + sign + digits(Math.floor(a / 60)) + ":" + digits(a % 60)
    }

    function sunDetail(date) {
        var spot = coords[localZone]
        if (!spot)
            return ""
        var times = Sun.sunTimes(spot.lat, spot.lon, date.getFullYear(), date.getMonth(), date.getDate())
        if (!times)
            return ""
        if (times.kind === "polarNight")
            return "Polar night"
        if (times.kind === "midnightSun")
            return "Midnight sun"
        var off = localOffsetMinutes()
        return "Sunrise " + Sun.formatLocal(times.riseUtc, off)
            + "     Sunset " + Sun.formatLocal(times.setUtc, off)
            + "     Daylight " + Sun.dayLength(times.riseUtc, times.setUtc)
    }

    function monthTitle() {
        var loc = Qt.locale()
        return loc.monthName(viewMonth, Locale.LongFormat) + " " + viewYear
    }

    function nextWeekStartName() {
        var next = weekStart === 1 ? 7 : 1
        return Qt.locale().dayName(next, Locale.LongFormat)
    }

    function rebuildLabels() {
        var loc = Qt.locale()
        var labels = []
        var day = weekStart
        for (var i = 0; i < 7; i++) {
            var name = String(loc.dayName(day, Locale.ShortFormat) || "")
            if (name.length > 2)
                name = name.substring(0, 2)
            labels.push(name.toUpperCase())
            day = day === 7 ? 1 : day + 1
        }
        weekdayLabels = labels
    }

    function weekdayLabel(index) {
        return (weekdayLabels && index < weekdayLabels.length) ? weekdayLabels[index] : ""
    }

    function rebuildWeeks() {
        var key = Calendar.dateKey(now.getFullYear(), now.getMonth(), now.getDate())
        weeks = Calendar.monthGrid(viewYear, viewMonth, weekStart, key)
        weekEpoch = weekEpoch + 1
    }

    function weekAt(index) {
        if (!weeks || index < 0 || index >= weeks.length)
            return null
        return weeks[index]
    }

    function goToToday() {
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    function moveMonth(delta) {
        var next = Calendar.stepMonth(viewYear, viewMonth, delta)
        viewYear = next.year
        viewMonth = next.month
    }

    function moveYear(delta) {
        moveMonth(delta * 12)
    }

    function toggleWeekStart() {
        var next = weekStart === 1 ? 7 : 1
        weekStartSetting = next === 7 ? "sunday" : "monday"
        saveConfig()
        pointerHint = "Weeks start on " + Qt.locale().dayName(next, Locale.LongFormat)
    }

    function famousCities() {
        return [
            { name: "New York", zone: "America/New_York" },
            { name: "Los Angeles", zone: "America/Los_Angeles" },
            { name: "Chicago", zone: "America/Chicago" },
            { name: "Sao Paulo", zone: "America/Sao_Paulo" },
            { name: "London", zone: "Europe/London" },
            { name: "Paris", zone: "Europe/Paris" },
            { name: "Berlin", zone: "Europe/Berlin" },
            { name: "Cairo", zone: "Africa/Cairo" },
            { name: "Johannesburg", zone: "Africa/Johannesburg" },
            { name: "Dubai", zone: "Asia/Dubai" },
            { name: "Mumbai", zone: "Asia/Kolkata" },
            { name: "Singapore", zone: "Asia/Singapore" },
            { name: "Hong Kong", zone: "Asia/Hong_Kong" },
            { name: "Tokyo", zone: "Asia/Tokyo" },
            { name: "Sydney", zone: "Australia/Sydney" },
            { name: "Auckland", zone: "Pacific/Auckland" }
        ]
    }

    function pickDefaults() {
        var home = offsets[localZone]
        if (home === undefined || home === null)
            home = -new Date().getTimezoneOffset()
        var pool = famousCities()
        var picked = []
        for (var gap = 180; gap >= 60 && picked.length < 4; gap -= 30) {
            for (var i = 0; i < pool.length && picked.length < 4; i++) {
                var zone = pool[i].zone
                if (zone === localZone || hasZone(zone, picked))
                    continue
                var off = offsets[zone]
                if (off === undefined || off === null)
                    continue
                if (Math.abs(off - home) < gap)
                    continue
                var far = true
                for (var j = 0; j < picked.length; j++) {
                    var other = offsets[picked[j].zone]
                    if (other !== undefined && Math.abs(off - other) < gap)
                        far = false
                }
                if (far)
                    picked.push({ name: pool[i].name, zone: zone })
            }
        }
        picked.sort(function(a, b) {
            var oa = offsets[a.zone]
            var ob = offsets[b.zone]
            if (oa === undefined) oa = 0
            if (ob === undefined) ob = 0
            return oa - ob
        })
        return picked
    }

    function hasZone(zone, list) {
        var source = list || cities
        for (var i = 0; i < source.length; i++) {
            if (source[i].zone === zone)
                return true
        }
        return false
    }

    function setCities(list) {
        cities = list
        cityEpoch = cityEpoch + 1
        if (map)
            map.requestPaint()
    }

    function cityAt(index) {
        if (!cities || index < 0 || index >= cities.length)
            return null
        return cities[index]
    }

    function copyCities() {
        var next = []
        for (var i = 0; i < cities.length; i++)
            next.push({ name: cities[i].name, zone: cities[i].zone })
        return next
    }

    function sanitizeCities(list) {
        var out = []
        var seen = {}
        if (!list)
            return out
        for (var i = 0; i < list.length && out.length < cityCap; i++) {
            var item = list[i]
            if (!item || !item.zone)
                continue
            var zone = String(item.zone)
            if (seen[zone] || zone === localZone)
                continue
            seen[zone] = true
            out.push({ name: item.name ? String(item.name) : zoneCity(zone), zone: zone })
        }
        return out
    }

    function renderConfig() {
        var data = { cities: [] }
        for (var i = 0; i < cities.length; i++)
            data.cities.push({ name: String(cities[i].name), zone: String(cities[i].zone) })
        if (weekStartSetting === "sunday" || weekStartSetting === "monday")
            data.weekStart = weekStartSetting
        return JSON.stringify(data, null, 2) + "\n"
    }

    function saveConfig() {
        if (!configDirReady) {
            savePending = true
            return
        }
        savePending = false
        configFile.setText(renderConfig())
    }

    function readConfig(text) {
        triedConfig = true
        var raw = String(text || "").trim()
        if (!raw) {
            maybePickDefaults()
            return
        }
        try {
            var data = JSON.parse(raw)
            if (data.weekStart === "sunday" || data.weekStart === "monday")
                weekStartSetting = data.weekStart
            if (data.cities)
                setCities(sanitizeCities(data.cities))
            configLoaded = true
            var zones = []
            for (var i = 0; i < cities.length; i++)
                zones.push(cities[i].zone)
            if (zones.length)
                probe(zones)
        } catch (e) {
            maybePickDefaults()
        }
    }

    function maybePickDefaults() {
        if (configLoaded || !triedConfig || !famousReady)
            return
        configLoaded = true
        setCities(pickDefaults())
        saveConfig()
    }

    function trackedZones() {
        var zones = []
        var pool = famousCities()
        for (var i = 0; i < pool.length; i++)
            zones.push(pool[i].zone)
        for (var j = 0; j < cities.length; j++)
            zones.push(cities[j].zone)
        return zones
    }

    function probe(zones) {
        var list = []
        var seen = {}
        for (var i = 0; i < zones.length; i++) {
            var zone = zones[i]
            if (!zone || seen[zone])
                continue
            seen[zone] = true
            list.push(zone)
        }
        if (!list.length)
            return
        if (zoneProbe.running) {
            probeQueue = list
            return
        }
        var args = ["python3", Quickshell.shellPath("zones.py")]
        for (var j = 0; j < list.length; j++)
            args.push(list[j])
        zoneProbe.exec(args)
    }

    function pumpProbe() {
        if (zoneProbe.running || !probeQueue || !probeQueue.length)
            return
        var next = probeQueue
        probeQueue = []
        probe(next)
    }

    function ingestZones(text) {
        var data
        try {
            data = JSON.parse(text)
        } catch (e) {
            return
        }
        if (!data || !data.offsets)
            return
        var merged = {}
        var key
        for (key in offsets)
            merged[key] = offsets[key]
        for (key in data.offsets)
            merged[key] = data.offsets[key]
        offsets = merged
        offsetEpoch = offsetEpoch + 1
        if (data.local)
            localZone = data.local
        famousReady = true
        maybePickDefaults()
        if (map)
            map.requestPaint()
    }

    function ingestZoneList(text) {
        var lines = String(text || "").split("\n")
        var out = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length > 0)
                out.push(line)
        }
        allZones = out
        if (searching && query.length > 0)
            updateMatches()
    }

    function decodeCoord(token) {
        if (!token || token.length < 2)
            return NaN
        var sign = token.charAt(0) === "-" ? -1 : 1
        var digits = token.substring(1)
        var deg = 0
        var min = 0
        var sec = 0
        if (digits.length === 4) {
            deg = parseInt(digits.substring(0, 2), 10)
            min = parseInt(digits.substring(2, 4), 10)
        } else if (digits.length === 5) {
            deg = parseInt(digits.substring(0, 3), 10)
            min = parseInt(digits.substring(3, 5), 10)
        } else if (digits.length === 6) {
            deg = parseInt(digits.substring(0, 2), 10)
            min = parseInt(digits.substring(2, 4), 10)
            sec = parseInt(digits.substring(4, 6), 10)
        } else if (digits.length === 7) {
            deg = parseInt(digits.substring(0, 3), 10)
            min = parseInt(digits.substring(3, 5), 10)
            sec = parseInt(digits.substring(5, 7), 10)
        } else {
            return NaN
        }
        if (isNaN(deg) || isNaN(min) || isNaN(sec))
            return NaN
        return sign * (deg + min / 60 + sec / 3600)
    }

    function parseIso6709(text) {
        var split = -1
        for (var i = 1; i < text.length; i++) {
            var ch = text.charAt(i)
            if (ch === "+" || ch === "-") {
                split = i
                break
            }
        }
        if (split < 0)
            return null
        var lat = decodeCoord(text.substring(0, split))
        var lon = decodeCoord(text.substring(split))
        if (isNaN(lat) || isNaN(lon))
            return null
        return { lat: lat, lon: lon }
    }

    function ingestCoords(text) {
        var next = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line || line.charAt(0) === "#")
                continue
            var fields = line.split("\t")
            if (fields.length < 3)
                continue
            var spot = parseIso6709(fields[1])
            if (!spot)
                continue
            var zones = fields[2].split(",")
            for (var z = 0; z < zones.length; z++) {
                if (zones[z].length > 0)
                    next[zones[z]] = spot
            }
        }
        coords = next
        coordEpoch = coordEpoch + 1
        if (map)
            map.requestPaint()
    }

    function zonePool() {
        if (allZones && allZones.length)
            return allZones
        var keys = []
        for (var key in coords)
            keys.push(key)
        keys.sort()
        return keys
    }

    function updateMatches() {
        var q = query.trim().toLowerCase()
        if (!q.length) {
            matches = []
            matchEpoch = matchEpoch + 1
            searchIndex = 0
            return
        }
        var qUnder = q.replace(/ /g, "_")
        var pool = zonePool()
        var ranked = []
        for (var i = 0; i < pool.length; i++) {
            var zone = pool[i]
            if (zone === localZone || hasZone(zone))
                continue
            var city = zoneCity(zone).toLowerCase()
            var zl = zone.toLowerCase()
            var rank = -1
            if (city.indexOf(q) === 0)
                rank = 0
            else if (zl.indexOf(qUnder) === 0 || zl.indexOf(q) === 0)
                rank = 1
            else if (city.indexOf(q) !== -1)
                rank = 2
            else if (zl.indexOf(qUnder) !== -1 || zl.indexOf(q) !== -1)
                rank = 3
            if (rank >= 0)
                ranked.push({ zone: zone, rank: rank, city: city })
        }
        ranked.sort(function(a, b) {
            if (a.rank !== b.rank)
                return a.rank - b.rank
            if (a.city < b.city)
                return -1
            if (a.city > b.city)
                return 1
            return 0
        })
        var out = []
        var missing = []
        for (var j = 0; j < ranked.length && out.length < 6; j++) {
            out.push(ranked[j].zone)
            if (offsets[ranked[j].zone] === undefined)
                missing.push(ranked[j].zone)
        }
        matches = out
        matchEpoch = matchEpoch + 1
        if (searchIndex >= out.length)
            searchIndex = 0
        if (missing.length)
            probe(missing)
    }

    function matchAt(index) {
        if (!matches || index < 0 || index >= matches.length)
            return ""
        return matches[index]
    }

    function zoneMeta(zone) {
        var off = offsets[zone]
        var where = zone
        if (off === undefined || off === null)
            return where
        return where + "   " + formatUtcOffset(off)
    }

    function openSearch() {
        if (cities.length >= cityCap) {
            pointerHint = "Eight cities fit on the card"
            return
        }
        searching = true
        query = ""
        matches = []
        matchEpoch = matchEpoch + 1
        searchIndex = 0
        searchInput.text = ""
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    function closeSearch() {
        searching = false
        query = ""
        matches = []
        matchEpoch = matchEpoch + 1
        searchInput.text = ""
        keyCatcher.forceActiveFocus()
    }

    function moveSearch(delta) {
        if (!matches || !matches.length)
            return
        var next = searchIndex + delta
        if (next < 0)
            next = matches.length - 1
        if (next >= matches.length)
            next = 0
        searchIndex = next
    }

    function addZone(zone) {
        if (!zone || zone === localZone || hasZone(zone))
            return
        if (cities.length >= cityCap) {
            pointerHint = "Eight cities fit on the card"
            return
        }
        var next = copyCities()
        next.push({ name: zoneCity(zone), zone: zone })
        next.sort(function(a, b) {
            var oa = offsets[a.zone]
            var ob = offsets[b.zone]
            if (oa === undefined) oa = 0
            if (ob === undefined) ob = 0
            return oa - ob
        })
        setCities(next)
        saveConfig()
        probe([zone])
        closeSearch()
    }

    function addHighlighted() {
        if (!matches || !matches.length)
            return
        var index = searchIndex
        if (index < 0 || index >= matches.length)
            index = 0
        addZone(matches[index])
    }

    function removeCity(zone) {
        var next = []
        for (var i = 0; i < cities.length; i++) {
            if (cities[i].zone !== zone)
                next.push({ name: cities[i].name, zone: cities[i].zone })
        }
        setCities(next)
        saveConfig()
    }

    function rowTime(zone, home, date) {
        if (home)
            return digits(date.getHours()) + ":" + digits(date.getMinutes()) + ":" + digits(date.getSeconds())
        var off = offsets[zone]
        if (off === undefined || off === null)
            return "--:--:--"
        var parts = zonedParts(date.getTime(), off)
        return digits(parts.h) + ":" + digits(parts.mi) + ":" + digits(parts.s)
    }

    function rowMeta(zone, home, date) {
        var off = offsets[zone]
        if ((off === undefined || off === null) && home)
            off = -date.getTimezoneOffset()
        if (off === undefined || off === null)
            return ""
        if (home)
            return "Here   ·   " + formatUtcOffset(off)
        var parts = zonedParts(date.getTime(), off)
        var localDay = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
        var thereDay = Date.UTC(parts.y, parts.mo, parts.da)
        var diff = Math.round((thereDay - localDay) / 86400000)
        var when
        if (diff === 1)
            when = "Tomorrow"
        else if (diff === -1)
            when = "Yesterday"
        else {
            var qt = new Date(Date.UTC(parts.y, parts.mo, parts.da)).getUTCDay()
            qt = qt === 0 ? 7 : qt
            when = Qt.locale().dayName(qt, Locale.ShortFormat) + " " + parts.da
        }
        var homeOff = offsets[localZone]
        if (homeOff === undefined || homeOff === null)
            homeOff = -date.getTimezoneOffset()
        return when + "   ·   " + formatDelta(off - homeOff)
    }

    function daySpan(zone, stamp) {
        var off = offsets[zone]
        var homeOff = offsets[localZone]
        if (homeOff === undefined || homeOff === null)
            homeOff = -new Date().getTimezoneOffset()
        if ((off === undefined || off === null) && zone === localZone)
            off = homeOff
        if (off === undefined || off === null)
            return null
        var spot = coords[zone]
        if (!spot)
            return null
        var fields = String(stamp).split("-")
        if (fields.length < 5)
            return null
        var year = parseInt(fields[0], 10)
        var month = parseInt(fields[1], 10)
        var day = parseInt(fields[2], 10)
        var hour = parseInt(fields[3], 10)
        var minute = parseInt(fields[4], 10)
        var utcMs = Date.UTC(year, month, day, hour, minute) - homeOff * 60000
        var there = zonedParts(utcMs, off)
        var times = Sun.sunTimes(spot.lat, spot.lon, there.y, there.mo, there.da)
        if (!times)
            return null
        if (times.kind === "midnightSun")
            return { kind: "midnightSun", rise: 0, set: 1440 }
        if (times.kind === "polarNight")
            return { kind: "polarNight", rise: 0, set: 0 }
        return {
            kind: "normal",
            rise: Sun.localMinutes(times.riseUtc, off),
            set: Sun.localMinutes(times.setUtc, off)
        }
    }

    function minuteFraction(zone, date) {
        if (!zone || zone === localZone)
            return (date.getHours() * 60 + date.getMinutes() + date.getSeconds() / 60) / 1440
        var off = offsets[zone]
        if (off === undefined || off === null)
            return 0
        var parts = zonedParts(date.getTime(), off)
        return (parts.h * 60 + parts.mi + parts.s / 60) / 1440
    }

    function markerInDay(span, frac) {
        if (!span)
            return false
        if (span.kind === "midnightSun")
            return true
        if (span.kind === "polarNight")
            return false
        var minute = frac * 1440
        if (span.set >= span.rise)
            return minute >= span.rise && minute <= span.set
        return minute >= span.rise || minute <= span.set
    }

    function project(lon, lat, mapWidth, mapHeight) {
        return {
            x: ((lon + 180) / 360) * mapWidth,
            y: ((90 - lat) / 180) * mapHeight
        }
    }

    function paintMap(ctx) {
        var mapWidth = map.width
        var mapHeight = map.height
        if (mapWidth < 2 || mapHeight < 2)
            return
        ctx.clearRect(0, 0, mapWidth, mapHeight)
        ctx.fillStyle = "#152033"
        ctx.fillRect(0, 0, mapWidth, mapHeight)

        var rings = Land.rings
        ctx.beginPath()
        for (var i = 0; i < rings.length; i++) {
            var ring = rings[i]
            if (!ring || ring.length < 3)
                continue
            var start = project(ring[0][0], ring[0][1], mapWidth, mapHeight)
            ctx.moveTo(start.x, start.y)
            for (var j = 1; j < ring.length; j++) {
                var point = project(ring[j][0], ring[j][1], mapWidth, mapHeight)
                ctx.lineTo(point.x, point.y)
            }
            ctx.closePath()
        }
        ctx.fillStyle = "#6d82a3"
        ctx.fill()
        ctx.strokeStyle = "rgba(232, 236, 244, 0.28)"
        ctx.lineWidth = 1
        ctx.stroke()

        var sun = Sun.subsolar(root.now)
        ctx.fillStyle = "rgba(3, 8, 18, 0.62)"
        ctx.beginPath()
        var steps = Math.max(24, Math.round(mapWidth / 2))
        function terminatorY(step) {
            var lon = -180 + (step / steps) * 360
            var lat = Sun.terminatorLat(lon, sun.lat, sun.lon)
            var y = ((90 - lat) / 180) * mapHeight
            if (y < 0)
                return 0
            if (y > mapHeight)
                return mapHeight
            return y
        }
        ctx.moveTo(0, terminatorY(0))
        for (var step = 1; step <= steps; step++)
            ctx.lineTo((step / steps) * mapWidth, terminatorY(step))
        if (sun.lat >= 0) {
            ctx.lineTo(mapWidth, mapHeight)
            ctx.lineTo(0, mapHeight)
        } else {
            ctx.lineTo(mapWidth, 0)
            ctx.lineTo(0, 0)
        }
        ctx.closePath()
        ctx.fill()

        ctx.strokeStyle = "rgba(228, 225, 231, 0.08)"
        ctx.lineWidth = 1
        ctx.beginPath()
        for (var latLine = -60; latLine <= 60; latLine += 30) {
            var yLine = ((90 - latLine) / 180) * mapHeight
            ctx.moveTo(0, yLine)
            ctx.lineTo(mapWidth, yLine)
        }
        for (var lonLine = -150; lonLine < 180; lonLine += 30) {
            var xLine = ((lonLine + 180) / 360) * mapWidth
            ctx.moveTo(xLine, 0)
            ctx.lineTo(xLine, mapHeight)
        }
        ctx.stroke()

        var sunPoint = project(sun.lon, sun.lat, mapWidth, mapHeight)
        ctx.fillStyle = "rgba(246, 193, 119, 0.28)"
        ctx.beginPath()
        ctx.arc(sunPoint.x, sunPoint.y, 11, 0, Math.PI * 2)
        ctx.fill()
        ctx.fillStyle = root.sunColor
        ctx.beginPath()
        ctx.arc(sunPoint.x, sunPoint.y, 3.5, 0, Math.PI * 2)
        ctx.fill()

        function drawDot(zone, home) {
            var spot = root.coords[zone]
            if (!spot)
                return
            var dot = project(spot.lon, spot.lat, mapWidth, mapHeight)
            ctx.beginPath()
            ctx.arc(dot.x, dot.y, home ? 4.5 : 3, 0, Math.PI * 2)
            ctx.fillStyle = home ? root.accent : "#f4f4f8"
            ctx.fill()
            if (home) {
                ctx.beginPath()
                ctx.arc(dot.x, dot.y, 8, 0, Math.PI * 2)
                ctx.strokeStyle = root.accent
                ctx.lineWidth = 1
                ctx.stroke()
                var label = root.zoneCity(zone)
                ctx.font = "12px 'JetBrainsMono Nerd Font'"
                ctx.fillStyle = "#f4f4f8"
                var labelWidth = ctx.measureText(label).width
                var labelX = dot.x + 12
                if (labelX + labelWidth > mapWidth - 6)
                    labelX = dot.x - 12 - labelWidth
                ctx.fillText(label, labelX, Math.max(14, dot.y - 8))
            }
        }

        for (var c = 0; c < root.cities.length; c++)
            drawDot(root.cities[c].zone, false)
        if (root.localZone)
            drawDot(root.localZone, true)
    }

    function open() {
        now = new Date()
        goToToday()
        opened = true
        probe(trackedZones())
    }

    function close() {
        opened = false
        searching = false
        pointerHint = ""
    }

    function handleKey(event) {
        if (searching)
            return
        if (event.key === Qt.Key_Escape)
            close()
        else if (event.key === Qt.Key_Left)
            moveMonth(-1)
        else if (event.key === Qt.Key_Right)
            moveMonth(1)
        else if (event.key === Qt.Key_Up)
            moveYear(-1)
        else if (event.key === Qt.Key_Down)
            moveYear(1)
        else if (event.key === Qt.Key_T)
            goToToday()
        else if (event.key === Qt.Key_W)
            toggleWeekStart()
        else if (event.key === Qt.Key_Slash || event.text === "/")
            openSearch()
        else if (event.key === Qt.Key_BracketLeft)
            moveMonth(-1)
        else if (event.key === Qt.Key_BracketRight)
            moveMonth(1)
        else
            return
        event.accepted = true
    }

    onGridStampChanged: rebuildWeeks()
    onWeekStartChanged: rebuildLabels()
    onOpenedChanged: {
        if (!opened)
            return
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        Qt.callLater(function() { if (map) map.requestPaint() })
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    color: "transparent"
    focusable: opened
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    visible: opened

    WlrLayershell.namespace: "clockpanel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Component.onCompleted: {
        rebuildLabels()
        rebuildWeeks()
        mkdirProc.running = true
        probe(trackedZones())
        tzList.running = true
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.opened && !root.searching
        context: Qt.WindowShortcut
        onActivated: root.close()
    }

    Timer {
        interval: 250
        running: root.opened
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 30000
        running: root.opened
        repeat: true
        onTriggered: if (map) map.requestPaint()
    }

    Timer {
        interval: 300000
        running: root.opened
        repeat: true
        onTriggered: root.probe(root.trackedZones())
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.configDir]
        onExited: {
            root.configDirReady = true
            if (root.savePending)
                root.saveConfig()
        }
    }

    Process {
        id: zoneProbe
        stdout: StdioCollector {
            id: zoneOut
            waitForEnd: true
            onStreamFinished: root.ingestZones(zoneOut.text)
        }
        onExited: root.pumpProbe()
    }

    Process {
        id: tzList
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            id: tzOut
            waitForEnd: true
            onStreamFinished: root.ingestZoneList(tzOut.text)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.readConfig(text())
        onLoadFailed: {
            root.triedConfig = true
            root.maybePickDefaults()
        }
    }

    FileView {
        id: zoneTab
        path: "/usr/share/zoneinfo/zone1970.tab"
        printErrors: false
        onLoaded: root.ingestCoords(text())
    }

    IpcHandler {
        target: "clockpanel"

        function ping(): string {
            return "ok"
        }

        function toggle(): string {
            if (root.opened)
                root.close()
            else
                root.open()
            return root.opened ? "open" : "closed"
        }
    }

    MouseArea {
        id: scrim
        anchors.fill: parent
        enabled: root.opened
        onClicked: root.close()

        Rectangle {
            anchors.fill: parent
            color: "#66101420"
        }

        Item {
            id: card
            width: root.cardWidth
            height: body.implicitHeight + root.inset * 2
            y: 36
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#33ccff" }
                    GradientStop { position: 1.0; color: "#00ff99" }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.borderWidth
                    color: root.background
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            Column {
                id: body
                x: root.inset
                y: root.inset
                width: card.width - root.inset * 2
                spacing: 14

                Item {
                    width: parent.width
                    implicitHeight: 58
                    height: 58

                    Row {
                        id: timeRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: root.clockText(root.now)
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 46
                            font.bold: true
                        }

                        Text {
                            text: root.secondsText(root.now)
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: 46
                            font.bold: true
                        }
                    }

                    Column {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            anchors.right: parent.right
                            text: root.dateLine(root.now)
                            color: dateMouse.containsMouse && !root.viewingCurrentMonth ? root.accent : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 18
                            font.bold: true

                            MouseArea {
                                id: dateMouse
                                anchors.fill: parent
                                enabled: !root.viewingCurrentMonth
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.goToToday()
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.zoneLine()
                            color: root.muted
                            font.family: root.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    width: parent.width
                    implicitHeight: 44
                    height: 44

                    Text {
                        id: yearName
                        anchors.left: parent.left
                        y: 0
                        text: String(root.now.getFullYear())
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.letterSpacing: 1
                    }

                    Text {
                        id: yearPct
                        anchors.right: parent.right
                        y: 0
                        text: root.yearPercent + "%"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }

                    Rectangle {
                        anchors.left: yearName.right
                        anchors.right: yearPct.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: yearName.verticalCenter
                        height: 6
                        color: "#14e4e1e7"

                        Rectangle {
                            width: Math.max(0, Math.round(parent.width * root.yearFraction))
                            height: parent.height
                            color: root.accent

                            Behavior on width {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: "Day " + root.dayOfYear + " of " + root.daysInYear
                            + "    ·    Week " + root.weekNumber
                            + "    ·    Q" + root.quarter
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: 198
                    height: 198
                    color: "#10131c"
                    border.width: 1
                    border.color: "#22e4e1e7"

                    Canvas {
                        id: map
                        anchors.fill: parent
                        anchors.margins: 1
                        antialiasing: true
                        onPaint: root.paintMap(getContext("2d"))
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onVisibleChanged: if (visible) requestPaint()
                    }
                }

                Row {
                    width: parent.width
                    spacing: root.columnGap

                    Column {
                        id: calendarCol
                        width: root.calWidth
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 26
                            spacing: 8

                            Rectangle {
                                width: 26
                                height: 26
                                color: prevMouse.containsMouse ? "#14e4e1e7" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.moveMonth(-1)
                                }
                            }

                            Item {
                                width: parent.width - 26 * 2 - (todayLink.visible ? todayLink.width + 24 : 16)
                                height: 26

                                Text {
                                    id: monthLabel
                                    anchors.centerIn: parent
                                    text: root.monthTitle()
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }

                            Text {
                                id: todayLink
                                visible: !root.viewingCurrentMonth
                                anchors.verticalCenter: parent.verticalCenter
                                text: "today"
                                color: todayMouse.containsMouse ? root.foreground : root.accent
                                font.family: root.fontFamily
                                font.pixelSize: 12

                                MouseArea {
                                    id: todayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goToToday()
                                }
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                color: nextMouse.containsMouse ? "#14e4e1e7" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 20
                                }

                                MouseArea {
                                    id: nextMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.moveMonth(1)
                                }
                            }
                        }

                        Column {
                            spacing: root.calSpacing

                            WheelHandler {
                                onWheel: function(event) {
                                    if (event.angleDelta.y === 0)
                                        return
                                    root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                                }
                            }

                            Row {
                                spacing: root.calSpacing
                                height: 16

                                Item {
                                    width: root.weekCol
                                    height: 16

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "W"
                                        color: weekStartMouse.containsMouse ? root.accent : root.faint
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }

                                    MouseArea {
                                        id: weekStartMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleWeekStart()
                                        onContainsMouseChanged: {
                                            root.pointerHint = containsMouse
                                                ? ("Start weeks on " + root.nextWeekStartName())
                                                : ""
                                        }
                                    }
                                }

                                Repeater {
                                    model: 7

                                    Text {
                                        required property int index
                                        width: root.cellW
                                        height: 16
                                        text: root.weekdayLabel(index)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        color: root.muted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        font.letterSpacing: 1
                                    }
                                }
                            }

                            Repeater {
                                model: 6

                                Row {
                                    id: weekRow
                                    required property int index
                                    spacing: root.calSpacing
                                    height: root.cellH
                                    readonly property var week: root.weekEpoch >= 0 ? root.weekAt(index) : null

                                    Text {
                                        width: root.weekCol
                                        height: root.cellH
                                        text: weekRow.week ? weekRow.week.week : ""
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        color: weekRow.week && weekRow.week.hasToday ? root.accent : root.faint
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                    }

                                    Repeater {
                                        model: 7

                                        Rectangle {
                                            required property int index
                                            readonly property var day: (weekRow.week && weekRow.week.days) ? weekRow.week.days[index] : null
                                            width: root.cellW
                                            height: root.cellH
                                            color: day && day.today ? root.accent : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: day ? day.day : ""
                                                color: !day ? root.faint : (day.today ? root.background : (day.inMonth ? root.foreground : root.faint))
                                                font.family: root.fontFamily
                                                font.pixelSize: 13
                                                font.bold: day && day.today
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: worldCol
                        width: root.worldWidth
                        spacing: 2

                        Repeater {
                            model: root.rowCount

                            Item {
                                id: cityRow
                                required property int index
                                width: worldCol.width
                                height: 52
                                implicitHeight: 52
                                readonly property bool home: index === 0
                                readonly property var stored: home ? null : root.cityAt(index - 1)
                                readonly property string rowZone: home ? root.localZone : (stored ? stored.zone : "")
                                readonly property string rowName: home ? root.zoneCity(root.localZone) : (stored ? stored.name : "")
                                readonly property var daylight: root.daySpan(rowZone, root.minuteStamp)
                                readonly property real marker: root.minuteFraction(rowZone, root.now)

                                Rectangle {
                                    anchors.fill: parent
                                    color: rowMouse.containsMouse ? "#10e4e1e7" : "transparent"
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }

                                Text {
                                    x: 4
                                    y: 3
                                    width: parent.width - timeLabel.implicitWidth - 36
                                    elide: Text.ElideRight
                                    text: cityRow.rowName
                                    color: cityRow.home ? root.accent : root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.bold: cityRow.home
                                }

                                Text {
                                    id: timeLabel
                                    anchors.right: parent.right
                                    anchors.rightMargin: (!cityRow.home && rowMouse.containsMouse) ? 22 : 4
                                    y: 3
                                    text: root.rowTime(cityRow.rowZone, cityRow.home, root.now)
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    x: 4
                                    y: 22
                                    width: parent.width - 12
                                    elide: Text.ElideRight
                                    text: root.rowMeta(cityRow.rowZone, cityRow.home, root.now)
                                    color: root.muted
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    id: track
                                    x: 4
                                    y: 42
                                    width: parent.width - 8
                                    height: 4
                                    color: "#14e4e1e7"
                                }

                                Rectangle {
                                    visible: cityRow.daylight && cityRow.daylight.kind !== "polarNight" && cityRow.daylight.set >= cityRow.daylight.rise
                                    x: track.x + (cityRow.daylight ? cityRow.daylight.rise / 1440 * track.width : 0)
                                    y: track.y
                                    width: cityRow.daylight ? Math.max(0, (cityRow.daylight.set - cityRow.daylight.rise) / 1440 * track.width) : 0
                                    height: track.height
                                    color: "#997aa2f7"
                                }

                                Rectangle {
                                    visible: cityRow.daylight && cityRow.daylight.set < cityRow.daylight.rise
                                    x: track.x
                                    y: track.y
                                    width: cityRow.daylight ? cityRow.daylight.set / 1440 * track.width : 0
                                    height: track.height
                                    color: "#997aa2f7"
                                }

                                Rectangle {
                                    visible: cityRow.daylight && cityRow.daylight.set < cityRow.daylight.rise
                                    x: track.x + (cityRow.daylight ? cityRow.daylight.rise / 1440 * track.width : 0)
                                    y: track.y
                                    width: cityRow.daylight ? (1440 - cityRow.daylight.rise) / 1440 * track.width : 0
                                    height: track.height
                                    color: "#997aa2f7"
                                }

                                Rectangle {
                                    x: track.x + Math.max(0, Math.min(track.width - 2, cityRow.marker * track.width - 1))
                                    y: track.y - 2
                                    width: 2
                                    height: 8
                                    color: root.markerInDay(cityRow.daylight, cityRow.marker) ? root.sunColor : root.foreground
                                }

                                Text {
                                    visible: !cityRow.home && rowMouse.containsMouse
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.top: parent.top
                                    anchors.topMargin: 2
                                    text: "×"
                                    color: removeMouse.containsMouse ? root.accent : root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 16

                                    MouseArea {
                                        id: removeMouse
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeCity(cityRow.rowZone)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !root.searching
                            width: parent.width
                            height: 30
                            implicitHeight: 30
                            color: addMouse.containsMouse ? "#14e4e1e7" : "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.cities.length >= root.cityCap ? "City list is full" : "+   Add a city"
                                color: addMouse.containsMouse ? root.foreground : root.muted
                                font.family: root.fontFamily
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSearch()
                            }
                        }

                        Column {
                            visible: root.searching
                            width: parent.width
                            spacing: 2

                            Rectangle {
                                width: parent.width
                                height: 32
                                color: "#10e4e1e7"
                                border.width: 1
                                border.color: root.accent

                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    color: root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    clip: true
                                    selectByMouse: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: {
                                        if (text === root.query)
                                            return
                                        root.query = text
                                        root.updateMatches()
                                    }
                                    Keys.onEscapePressed: function(event) {
                                        root.closeSearch()
                                        event.accepted = true
                                    }
                                    Keys.onReturnPressed: function(event) {
                                        root.addHighlighted()
                                        event.accepted = true
                                    }
                                    Keys.onEnterPressed: function(event) {
                                        root.addHighlighted()
                                        event.accepted = true
                                    }
                                    Keys.onUpPressed: function(event) {
                                        root.moveSearch(-1)
                                        event.accepted = true
                                    }
                                    Keys.onDownPressed: function(event) {
                                        root.moveSearch(1)
                                        event.accepted = true
                                    }
                                }

                                Text {
                                    anchors.fill: searchInput
                                    visible: searchInput.text.length === 0 && !searchInput.preeditText
                                    text: "Search cities or time zones"
                                    color: root.faint
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Repeater {
                                model: root.matchCount

                                Rectangle {
                                    required property int index
                                    readonly property string zone: root.matchAt(index)
                                    width: worldCol.width
                                    height: 30
                                    color: index === root.searchIndex ? "#14e4e1e7" : "transparent"
                                    border.width: index === root.searchIndex ? 1 : 0
                                    border.color: "#4033ccff"

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * 0.34
                                        elide: Text.ElideRight
                                        text: root.zoneCity(zone)
                                        color: root.foreground
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * 0.58
                                        elide: Text.ElideLeft
                                        horizontalAlignment: Text.AlignRight
                                        text: root.zoneMeta(zone)
                                        color: root.muted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: root.searchIndex = index
                                        onClicked: root.addZone(zone)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: 1
                    height: 1
                    color: "#18e4e1e7"
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: root.sunDetail(root.now)
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: "Unix " + Math.floor(root.now.getTime() / 1000) + "     " + root.isoStamp(root.now)
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.footerHint
                    color: root.faint
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true
                Keys.onPressed: function(event) { root.handleKey(event) }
            }
        }
    }
}
