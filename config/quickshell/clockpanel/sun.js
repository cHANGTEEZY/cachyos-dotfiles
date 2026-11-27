.pragma library

var RAD = Math.PI / 180

function norm360(x) {
    var v = x % 360
    if (v < 0)
        v += 360
    return v
}

function pad(n) {
    n = Math.floor(Math.abs(n))
    return (n < 10 ? "0" : "") + n
}

// Subsolar point: where the sun is directly overhead.
function subsolar(date) {
    var j2000 = Date.UTC(2000, 0, 1, 12, 0, 0)
    var n = (date.getTime() - j2000) / 86400000
    var meanLong = norm360(280.460 + 0.9856474 * n)
    var anomaly = norm360(357.528 + 0.9856003 * n) * RAD
    var lambda = norm360(meanLong + 1.915 * Math.sin(anomaly) + 0.020 * Math.sin(2 * anomaly))
    var eps = (23.439 - 0.0000004 * n) * RAD
    var dec = Math.asin(Math.sin(eps) * Math.sin(lambda * RAD))
    var ra = Math.atan2(Math.cos(eps) * Math.sin(lambda * RAD), Math.cos(lambda * RAD))
    var gmst = norm360(280.46061837 + 360.98564736629 * n)
    var raDeg = ra / RAD
    if (raDeg < 0)
        raDeg += 360
    var lon = raDeg - gmst
    lon = ((lon + 540) % 360) - 180
    return { lat: dec / RAD, lon: lon }
}

// Latitude of the day/night boundary on a meridian. North of it is night when
// the sun is in the southern hemisphere, and the other way around in summer.
function terminatorLat(lon, subLat, subLon) {
    var dec = subLat * RAD
    var ha = (lon - subLon) * RAD
    if (Math.abs(Math.sin(dec)) < 1e-4)
        return Math.cos(ha) >= 0 ? -89 : 89
    return Math.atan(-Math.cos(ha) * Math.cos(dec) / Math.sin(dec)) / RAD
}

function eventUtc(lat, lon, year, month, day, rise) {
    var zenith = 90.833
    var n1 = Math.floor(275 * month / 9)
    var n2 = Math.floor((month + 9) / 12)
    var n3 = (1 + Math.floor((year - 4 * Math.floor(year / 4) + 2) / 3))
    var n = n1 - (n2 * n3) + day - 30
    var lngHour = lon / 15
    var t = n + (((rise ? 6 : 18) - lngHour) / 24)
    var m = (0.9856 * t) - 3.289
    var l = norm360(m + (1.916 * Math.sin(m * RAD)) + (0.020 * Math.sin(2 * m * RAD)) + 282.634)
    var ra = Math.atan(0.91764 * Math.tan(l * RAD)) / RAD
    ra = norm360(ra)
    var lq = Math.floor(l / 90) * 90
    var raq = Math.floor(ra / 90) * 90
    ra = (ra + (lq - raq)) / 15
    var sinDec = 0.39782 * Math.sin(l * RAD)
    var cosDec = Math.cos(Math.asin(sinDec))
    var cosH = (Math.cos(zenith * RAD) - (sinDec * Math.sin(lat * RAD))) / (cosDec * Math.cos(lat * RAD))
    if (cosH > 1)
        return "polarNight"
    if (cosH < -1)
        return "midnightSun"
    var h = (rise ? (360 - Math.acos(cosH) / RAD) : (Math.acos(cosH) / RAD)) / 15
    var ut = h + ra - (0.06571 * t) - 6.622 - lngHour
    ut = ((ut % 24) + 24) % 24
    return ut
}

// month is 0-based. riseUtc/setUtc are hours UTC.
function sunTimes(lat, lon, year, monthIndex, day) {
    var month = monthIndex + 1
    var rise = eventUtc(lat, lon, year, month, day, true)
    var set = eventUtc(lat, lon, year, month, day, false)
    if (rise === "polarNight" || set === "polarNight")
        return { kind: "polarNight" }
    if (rise === "midnightSun" || set === "midnightSun")
        return { kind: "midnightSun" }
    return { kind: "normal", riseUtc: rise, setUtc: set }
}

function localMinutes(utcHours, offsetMin) {
    var mins = Math.round(utcHours * 60 + offsetMin)
    return ((mins % 1440) + 1440) % 1440
}

function formatMinutes(mins) {
    mins = ((mins % 1440) + 1440) % 1440
    return pad(Math.floor(mins / 60)) + ":" + pad(mins % 60)
}

function formatLocal(utcHours, offsetMin) {
    return formatMinutes(localMinutes(utcHours, offsetMin))
}

function dayLength(riseUtc, setUtc) {
    var mins = Math.round((setUtc - riseUtc) * 60)
    if (mins < 0)
        mins += 1440
    return Math.floor(mins / 60) + "h " + pad(mins % 60) + "m"
}
