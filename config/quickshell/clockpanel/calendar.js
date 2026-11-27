.pragma library

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

function dateKey(year, month, day) {
    return year + "-" + pad(month + 1) + "-" + pad(day)
}

function isLeap(year) {
    return (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0)
}

function daysInYear(year) {
    return isLeap(year) ? 366 : 365
}

function dayOfYear(year, month, day) {
    var start = Date.UTC(year, 0, 1)
    var cur = Date.UTC(year, month, day)
    return Math.round((cur - start) / 86400000) + 1
}

// Share of the year already behind this date. 1 January is 0, 31 December is 1.
function yearProgress(year, month, day) {
    return (dayOfYear(year, month, day) - 1) / daysInYear(year)
}

function yearProgressPercent(year, month, day) {
    return Math.round(yearProgress(year, month, day) * 100)
}

function isoWeek(year, month, day) {
    var date = new Date(Date.UTC(year, month, day))
    var dayNum = date.getUTCDay() || 7
    date.setUTCDate(date.getUTCDate() + 4 - dayNum)
    var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
    return Math.ceil((((date.getTime() - yearStart.getTime()) / 86400000) + 1) / 7)
}

function stepMonth(year, month, delta) {
    var total = year * 12 + month + delta
    var nextYear = Math.floor(total / 12)
    var nextMonth = total % 12
    if (nextMonth < 0) {
        nextMonth += 12
        nextYear -= 1
    }
    return { year: nextYear, month: nextMonth }
}

// weekStart uses Qt's numbering: Monday = 1 ... Sunday = 7.
function weekStartIndex(weekStart) {
    if (weekStart === 7 || weekStart === 0)
        return 0
    return weekStart
}

function monthGrid(year, month, weekStart, todayKey) {
    var start = weekStartIndex(weekStart)
    var firstDow = new Date(Date.UTC(year, month, 1)).getUTCDay()
    var leading = (firstDow - start + 7) % 7
    var thursdayCol = (4 - start + 7) % 7
    var weeks = []
    var cursor = 1 - leading
    for (var w = 0; w < 6; w++) {
        var days = []
        var hasToday = false
        var thursday = null
        for (var c = 0; c < 7; c++) {
            var dt = new Date(Date.UTC(year, month, cursor))
            var y = dt.getUTCFullYear()
            var m = dt.getUTCMonth()
            var d = dt.getUTCDate()
            var key = dateKey(y, m, d)
            var today = key === todayKey
            if (today)
                hasToday = true
            days.push({
                day: d,
                inMonth: m === month && y === year,
                today: today,
                key: key
            })
            if (c === thursdayCol)
                thursday = dt
            cursor++
        }
        weeks.push({
            week: isoWeek(thursday.getUTCFullYear(), thursday.getUTCMonth(), thursday.getUTCDate()),
            hasToday: hasToday,
            days: days
        })
    }
    return weeks
}
