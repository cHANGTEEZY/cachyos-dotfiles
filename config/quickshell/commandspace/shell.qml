import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "menu.js" as Menu

// Super+Space command palette, matching Omarchy 4.5's menu:
// a centered card, "Go…" at the root, apps and nested commands in one search.
PanelWindow {
    id: root

    property bool opened: false
    property bool acceptToggle: false
    property bool syncing: false
    property bool pointerArmed: false
    property real pointerX: -1
    property real pointerY: -1
    property bool cursorActive: true
    property int toggleGeneration: 0
    property int selectedIndex: 0
    property int layoutSerial: 0
    property int frozenTop: -1
    property int frozenRows: -1
    property string filterText: ""
    property string activeMenu: "root"
    property var navStack: []
    property var staticItems: ({})
    property var staticOrder: []
    property var items: ({})
    property var itemOrder: []

    readonly property color background: "#1a1b26"
    readonly property color foreground: "#e4e1e7"
    readonly property color accent: "#7aa2f7"
    readonly property color selectedBackground: "#14e4e1e7"
    readonly property color selectedBorder: "#4033ccff"
    readonly property string fontFamily: "Iosevka Nerd Font"
    readonly property int pad: 18
    readonly property int borderWidth: 2
    readonly property int headerHeight: 34
    readonly property int contentSpacing: 6
    readonly property int rowHeight: 50
    readonly property int detailRowHeight: 58
    readonly property int rowSpacing: 3
    readonly property int dividerHeight: 17
    readonly property int inset: borderWidth + pad
    readonly property int cardChrome: inset * 2 + headerHeight + contentSpacing
    readonly property int cardWidth: Math.min(300, Math.max(240, width - 20))
    readonly property int rowsViewport: computeRows(layoutSerial, displayModel.count, filterText, frozenRows, height)
    readonly property int cardHeight: Math.min(cardChrome + rowsViewport, Math.max(cardChrome + rowHeight, height - 20))
    readonly property int centeredTop: Math.max(10, Math.round((height - cardHeight) / 2))
    readonly property int cardY: frozenTop >= 0 ? frozenTop : centeredTop
    readonly property string placeholder: ((items[activeMenu] && (items[activeMenu].title || items[activeMenu].label)) || "Go") + "…"

    function stateDir() {
        var base = Quickshell.env("XDG_STATE_HOME")
        if (!base)
            base = Quickshell.env("HOME") + "/.local/state"
        return base + "/changteezy/commandspace"
    }

    function computeRows(serial, count, filter, cap, screenHeight) {
        if (count === 0)
            return 72
        var total = 0
        var totals = []
        for (var i = 0; i < count; i++) {
            var row = displayModel.get(i)
            if (i > 0)
                total += root.rowSpacing
            total += row && row.kind === "divider" ? root.dividerHeight : root.rowHeightFor(row, filter)
            totals.push(total)
        }
        var available = cap >= 0 ? cap : Math.round(screenHeight * 0.7)
        return foldRows(totals, available)
    }

    function rowHeightFor(row, filter) {
        if (!row)
            return rowHeight
        if (row.kind === "divider")
            return dividerHeight
        return filter && row.detail ? detailRowHeight : rowHeight
    }

    function foldRows(totals, available) {
        var count = totals.length
        if (count === 0)
            return rowHeight
        if (totals[count - 1] <= available)
            return totals[count - 1]
        var peek = Math.round(rowHeight * 0.55)
        var full = 0
        while (full < count && totals[full] <= available)
            full++
        while (full > 1 && totals[full - 1] + rowSpacing + peek > available)
            full--
        if (full < 1)
            return Math.max(available, rowHeight)
        return totals[full - 1] + rowSpacing + peek
    }

    // The menu opens under the pointer. Ignore that hover until the mouse
    // actually moves, or the row at screen center becomes the selection.
    function disarmPointer() {
        pointerArmed = false
        pointerX = -1
        pointerY = -1
    }

    function notePointer(x, y) {
        if (pointerX < 0) {
            pointerX = x
            pointerY = y
            return
        }
        var dx = x - pointerX
        var dy = y - pointerY
        if ((dx * dx + dy * dy) > 36)
            pointerArmed = true
    }

    function freeze() {
        // The first keystroke pins the card so later results grow downward
        // instead of recentering. Skip the pin until the window has a real
        // height, or a just-opened menu gets stuck at the top of the screen.
        if (!opened || frozenTop >= 0 || height < 200)
            return
        frozenTop = centeredTop
        frozenRows = rowsViewport
    }

    function loadMenu(text) {
        var parsed = []
        try {
            parsed = JSON.parse(text || "[]")
        } catch (error) {
            console.warn("commandspace menu.json:", error)
            parsed = []
        }
        var map = ({})
        var order = []
        for (var i = 0; i < parsed.length; i++) {
            var raw = parsed[i] || ({})
            var id = String(raw.id || "")
            if (!id)
                continue
            var dot = id.lastIndexOf(".")
            var parent = dot >= 0 ? id.substring(0, dot) : "root"
            var kind = raw.exec ? "action" : "menu"
            map[id] = {
                id: id,
                parent: parent,
                kind: kind,
                label: String(raw.label || id),
                title: String(raw.title || raw.label || id),
                icon: String(raw.icon || ""),
                aliases: raw.aliases || [],
                description: String(raw.description || ""),
                exec: String(raw.exec || ""),
                order: i
            }
            order.push(id)
        }
        staticItems = map
        staticOrder = order
        rebuildIndex()
        markReady()
    }

    function collectApps() {
        var values = DesktopEntries.applications.values
        var apps = []
        if (!values)
            return apps
        for (var i = 0; i < values.length; i++) {
            var entry = values[i]
            if (!entry || entry.noDisplay || !entry.name)
                continue
            var aliases = []
            if (entry.genericName)
                aliases.push(entry.genericName)
            if (entry.keywords) {
                for (var k = 0; k < entry.keywords.length; k++)
                    aliases.push(entry.keywords[k])
            }
            aliases.push(entry.id)
            apps.push({
                id: "apps." + entry.id,
                parent: "apps",
                kind: "app",
                label: entry.name,
                title: entry.name,
                icon: "",
                appIcon: entry.icon || "",
                appId: entry.id,
                aliases: aliases,
                description: entry.comment || "",
                exec: "",
                order: 1000 + i
            })
        }
        apps.sort(function(a, b) {
            var left = a.label.toLowerCase()
            var right = b.label.toLowerCase()
            if (left < right)
                return -1
            if (left > right)
                return 1
            return 0
        })
        return apps
    }

    function rebuildIndex() {
        var map = ({
            root: {
                id: "root",
                parent: "",
                kind: "menu",
                label: "Go",
                title: "Go",
                icon: "",
                aliases: [],
                description: "",
                exec: "",
                order: 0
            }
        })
        var order = []
        for (var i = 0; i < staticOrder.length; i++) {
            var entry = staticItems[staticOrder[i]]
            if (!entry)
                continue
            map[entry.id] = entry
            order.push(entry.id)
        }
        var apps = collectApps()
        for (var a = 0; a < apps.length; a++) {
            map[apps[a].id] = apps[a]
            order.push(apps[a].id)
        }
        items = map
        itemOrder = order
        if (!map[activeMenu])
            activeMenu = "root"
        if (opened)
            rebuild()
    }

    function blankRow() {
        return {
            itemId: "",
            kind: "divider",
            icon: "",
            appIcon: "",
            appId: "",
            label: "",
            detail: "",
            path: "",
            exec: "",
            score: 0
        }
    }

    function displayRow(entry, detail) {
        return {
            itemId: entry.id,
            kind: entry.kind,
            icon: entry.icon || "",
            appIcon: entry.appIcon || "",
            appId: entry.appId || "",
            label: entry.label || "",
            detail: detail || "",
            path: Menu.pathFor(items, entry.id),
            exec: entry.exec || "",
            score: 0
        }
    }

    function rebuild() {
        var rows = []
        var query = filterText.trim()
        var active = items[activeMenu] ? activeMenu : "root"
        if (active !== activeMenu)
            activeMenu = active

        if (query) {
            var current = []
            var deeper = []
            for (var i = 0; i < itemOrder.length; i++) {
                var entry = items[itemOrder[i]]
                if (!entry || !Menu.isDescendant(items, entry.id, active))
                    continue
                if (!Menu.matches(entry, query))
                    continue
                var row = displayRow(entry, Menu.parentPath(items, entry.id))
                row.score = Menu.searchScore(items, entry, query)
                if (entry.parent === active)
                    current.push(row)
                else
                    deeper.push(row)
            }
            var byScore = function(a, b) {
                if (a.score !== b.score)
                    return a.score - b.score
                if (a.path < b.path)
                    return -1
                if (a.path > b.path)
                    return 1
                return 0
            }
            current.sort(byScore)
            deeper.sort(byScore)
            rows = current
            if (current.length && deeper.length)
                rows = rows.concat([blankRow()]).concat(deeper)
            else
                rows = rows.concat(deeper)
        } else {
            for (var j = 0; j < itemOrder.length; j++) {
                var child = items[itemOrder[j]]
                if (!child || child.parent !== active)
                    continue
                rows.push(displayRow(child, ""))
            }
            if (active === "apps") {
                rows.sort(function(a, b) {
                    var left = a.label.toLowerCase()
                    var right = b.label.toLowerCase()
                    if (left < right)
                        return -1
                    if (left > right)
                        return 1
                    return 0
                })
            }
        }

        displayModel.clear()
        for (var r = 0; r < rows.length; r++)
            displayModel.append(rows[r])
        layoutSerial += 1
        settle()
        Qt.callLater(reveal)
    }

    function nextSelectable(from, direction) {
        var count = displayModel.count
        if (count === 0)
            return -1
        var step = direction < 0 ? -1 : 1
        var index = ((from % count) + count) % count
        for (var i = 0; i < count; i++) {
            var row = displayModel.get(index)
            if (row && row.kind !== "divider")
                return index
            index = (index + step + count) % count
        }
        return -1
    }

    function settle() {
        if (displayModel.count === 0) {
            selectedIndex = 0
            cursorActive = false
            return
        }
        var target = nextSelectable(0, 1)
        selectedIndex = target >= 0 ? target : 0
        cursorActive = target >= 0
    }

    function move(delta) {
        if (displayModel.count === 0)
            return
        var step = delta < 0 ? -1 : 1
        var from = cursorActive ? selectedIndex + delta : (delta < 0 ? displayModel.count - 1 : 0)
        var target = nextSelectable(from, step)
        if (target < 0)
            return
        cursorActive = true
        selectedIndex = target
        reveal()
    }

    function reveal() {
        if (displayModel.count === 0 || !resultList)
            return
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function setMenu(id, push) {
        if (!items[id])
            id = "root"
        freeze()
        if (push && id !== activeMenu) {
            var stack = navStack.slice()
            stack.push(activeMenu)
            navStack = stack
        }
        activeMenu = id
        syncing = true
        filterText = ""
        filterInput.text = ""
        syncing = false
        root.disarmPointer()
        selectedIndex = 0
        cursorActive = true
        rebuild()
    }

    function goBack() {
        if (activeMenu === "root" && navStack.length === 0)
            return false
        var stack = navStack.slice()
        var previous = stack.length ? stack.pop() : ((items[activeMenu] && items[activeMenu].parent) || "root")
        navStack = stack
        setMenu(previous || "root", false)
        return true
    }

    function openMenu() {
        frozenTop = -1
        frozenRows = -1
        navStack = []
        activeMenu = "root"
        syncing = true
        filterText = ""
        filterInput.text = ""
        syncing = false
        root.disarmPointer()
        selectedIndex = 0
        cursorActive = true
        opened = true
        rebuild()
        Qt.callLater(function() { filterInput.forceActiveFocus() })
    }

    function closeMenu() {
        opened = false
        frozenTop = -1
        frozenRows = -1
        syncing = true
        filterText = ""
        filterInput.text = ""
        syncing = false
    }

    function desktopArgv(id) {
        var entry = DesktopEntries.byId(id)
        if (!entry)
            return []
        var argv = ["uwsm", "app", "--"]
        if (entry.runInTerminal)
            argv.push("alacritty", "-e")
        var cmd = entry.command
        var any = false
        if (cmd) {
            for (var i = 0; i < cmd.length; i++) {
                var part = String(cmd[i] || "")
                if (!part || part.charAt(0) === "%")
                    continue
                argv.push(part)
                any = true
            }
        }
        return any ? argv : []
    }

    function schedule(shellCommand, argv) {
        launchTimer.stop()
        launchTimer.shellCommand = shellCommand || ""
        launchTimer.desktopArgv = argv || []
        closeMenu()
        launchTimer.start()
    }

    function activate(index) {
        if (index < 0 || index >= displayModel.count)
            return
        var row = displayModel.get(index)
        if (!row || row.kind === "divider")
            return
        if (row.kind === "menu") {
            setMenu(row.itemId, true)
            return
        }
        if (row.kind === "app") {
            var argv = desktopArgv(row.appId)
            if (argv.length)
                schedule("", argv)
            else {
                var entry = DesktopEntries.byId(row.appId)
                closeMenu()
                if (entry)
                    entry.execute()
            }
            return
        }
        if (row.exec)
            schedule(row.exec, [])
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (filterText) {
                syncing = true
                filterText = ""
                filterInput.text = ""
                syncing = false
                selectedIndex = 0
                rebuild()
            } else {
                closeMenu()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            move(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            move(1)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            move(-6)
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            move(6)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
            if (cursorActive)
                activate(selectedIndex)
            event.accepted = true
        } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && !filterText) {
            goBack()
            event.accepted = true
        }
    }

    function iconSource(name) {
        if (!name)
            return ""
        var path = Quickshell.iconPath(name)
        if (!path)
            return ""
        return path.charAt(0) === "/" ? "file://" + path : path
    }

    function onToggleChanged() {
        if (!acceptToggle)
            return
        var text = String(toggleFile.text() || "").trim()
        if (text.indexOf("query:") === 0) {
            var query = text.substring(6)
            if (!opened)
                openMenu()
            syncing = true
            filterText = query
            filterInput.text = query
            syncing = false
            freeze()
            selectedIndex = 0
            cursorActive = true
            rebuild()
            return
        }
        var generation = parseInt(text, 10)
        if (!isFinite(generation) || generation === toggleGeneration)
            return
        toggleGeneration = generation
        if (opened)
            closeMenu()
        else
            openMenu()
    }

    function markReady() {
        if (acceptToggle)
            return
        var dir = stateDir()
        toggleFile.blockLoading = true
        toggleFile.path = dir + "/toggle"
        var current = parseInt(String(toggleFile.text() || "").trim(), 10)
        if (!isFinite(current)) {
            toggleFile.setText("0\n")
            current = 0
        }
        toggleGeneration = current
        acceptToggle = true
        Quickshell.execDetached(["bash", "-c", "mkdir -p " + dir + " && date +%s%N > " + dir + "/ready"])
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

    WlrLayershell.namespace: "commandspace"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenedChanged: {
        if (opened)
            Qt.callLater(function() { filterInput.forceActiveFocus() })
    }

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root.markReady()
    }

    FileView {
        id: menuFile
        path: Quickshell.shellPath("menu.json")
        watchChanges: true
        onLoaded: root.loadMenu(text())
        onFileChanged: root.loadMenu(text())
    }

    FileView {
        id: toggleFile
        watchChanges: true
        onFileChanged: root.onToggleChanged()
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.rebuildIndex()
        }
    }

    Timer {
        id: launchTimer
        interval: 80
        repeat: false
        property string shellCommand: ""
        property var desktopArgv: []
        onTriggered: {
            if (shellCommand)
                Quickshell.execDetached(["bash", "-c", shellCommand])
            else if (desktopArgv && desktopArgv.length)
                Quickshell.execDetached(desktopArgv)
        }
    }

    IpcHandler {
        target: "commandspace"

        function ping(): string {
            return "ok"
        }

        function toggle(): string {
            if (root.opened)
                root.closeMenu()
            else
                root.openMenu()
            return root.opened ? "open" : "closed"
        }

        function query(text: string): string {
            if (!root.opened)
                root.openMenu()
            root.syncing = true
            root.filterText = text
            filterInput.text = text
            root.syncing = false
            root.freeze()
            root.selectedIndex = 0
            root.cursorActive = true
            root.rebuild()
            return "ok"
        }
    }

    ListModel { id: displayModel }

    MouseArea {
        id: scrim
        anchors.fill: parent
        enabled: root.opened
        hoverEnabled: true
        onPositionChanged: (mouse) => root.notePointer(mouse.x, mouse.y)
        onClicked: root.closeMenu()

        Rectangle {
            anchors.fill: parent
            color: "#801a1b26"
        }

        Item {
            id: card
            width: root.cardWidth
            height: root.cardHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cardY

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
                onClicked: {}
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.inset
                spacing: root.contentSpacing

                Item {
                    width: parent.width
                    height: root.headerHeight

                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        clip: true
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: {
                            if (root.syncing || text === root.filterText)
                                return
                            root.freeze()
                            root.filterText = text
                            root.selectedIndex = 0
                            root.cursorActive = true
                            root.disarmPointer()
                            root.rebuild()
                        }
                        Keys.onPressed: (event) => root.handleKey(event)
                    }

                    Text {
                        anchors.fill: filterInput
                        visible: !root.filterText && !filterInput.preeditText
                        text: root.placeholder
                        color: root.foreground
                        opacity: 0.58
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: parent.width
                    height: root.rowsViewport

                    ListView {
                        id: resultList
                        anchors.fill: parent
                        model: displayModel
                        clip: true
                        spacing: root.rowSpacing
                        boundsBehavior: Flickable.StopAtBounds
                        keyNavigationEnabled: false

                        delegate: Item {
                            id: row
                            required property int index
                            required property string itemId
                            required property string kind
                            required property string icon
                            required property string appIcon
                            required property string appId
                            required property string label
                            required property string detail
                            required property string path
                            required property string exec

                            readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                            readonly property bool isApp: kind === "app"
                            readonly property bool isDivider: kind === "divider"
                            readonly property string glyph: isApp ? "" : icon

                            width: ListView.view.width
                            height: root.rowHeightFor(row, root.filterText)

                            Rectangle {
                                anchors.fill: parent
                                visible: !row.isDivider
                                color: row.hasCursor ? root.selectedBackground : "transparent"
                                border.width: row.hasCursor ? 1 : 0
                                border.color: root.selectedBorder
                            }

                            Rectangle {
                                visible: row.isDivider
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1
                                color: Qt.rgba(0.894, 0.882, 0.906, 0.2)
                            }

                            Text {
                                id: iconText
                                visible: !row.isDivider && !row.isApp && glyph.length > 0
                                text: glyph
                                color: row.hasCursor ? root.accent : root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 18
                                width: 36
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Image {
                                id: appIconImage
                                visible: row.isApp && status !== Image.Error && source.toString().length > 0
                                width: 18
                                height: 18
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: row.isApp ? root.iconSource(appIcon) : ""
                                anchors.left: parent.left
                                anchors.leftMargin: 8 + (36 - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                visible: row.isApp && !appIconImage.visible
                                text: "󰀻"
                                color: row.hasCursor ? root.accent : root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: 18
                                width: 36
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                visible: !row.isDivider
                                anchors.left: parent.left
                                anchors.leftMargin: 8 + 36 + 6
                                anchors.right: chevron.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: row.label
                                    color: row.hasCursor ? root.accent : root.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: root.filterText.length > 0 && row.detail.length > 0
                                    text: row.detail
                                    color: root.foreground
                                    opacity: 0.52
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: chevron
                                visible: !row.isDivider
                                text: row.kind === "menu" ? "›" : ""
                                color: row.hasCursor ? root.accent : root.foreground
                                opacity: row.kind === "menu" ? 0.36 : 0
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                width: 14
                                horizontalAlignment: Text.AlignRight
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !row.isDivider
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    if (!root.pointerArmed)
                                        return
                                    root.cursorActive = true
                                    root.selectedIndex = row.index
                                }
                                onPositionChanged: (mouse) => {
                                    var pos = mapToItem(scrim, mouse.x, mouse.y)
                                    root.notePointer(pos.x, pos.y)
                                    if (!root.pointerArmed)
                                        return
                                    root.cursorActive = true
                                    root.selectedIndex = row.index
                                }
                                onClicked: {
                                    root.cursorActive = true
                                    root.selectedIndex = row.index
                                    root.activate(row.index)
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: displayModel.count === 0
                        spacing: 8

                        Text {
                            text: "󰈉"
                            color: root.accent
                            opacity: 0.8
                            font.family: root.fontFamily
                            font.pixelSize: 28
                            horizontalAlignment: Text.AlignHCenter
                            width: root.cardWidth - 48
                        }

                        Text {
                            text: root.filterText ? "No matches for " + root.filterText : "Nothing here"
                            color: root.foreground
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            width: root.cardWidth - 48
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
