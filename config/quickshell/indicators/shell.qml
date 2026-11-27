import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

// Static toggles beside the clock. Same 30×24 buttons as the workspace strip.
// Click turns a mode on or off. Nothing opens on hover.
PanelWindow {
    id: root

    property var modes: ({ dnd: false, night: false, awake: false, record: false, elapsed: 0 })
    property int modeEpoch: 0

    readonly property int buttonWidth: 30
    readonly property int barHeight: 24
    readonly property color idleColor: "#c0caf5"
    readonly property color hoverColor: "#ffffff"
    readonly property color activeColor: "#7dcfff"
    readonly property color recordColor: "#ff5555"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property var options: [
        { id: "record", icon: "󰑊" },
        { id: "awake", icon: "" },
        { id: "dnd", icon: "󰂛" },
        { id: "night", icon: "󰖔" }
    ]
    readonly property int screenWidth: {
        var list = Quickshell.screens
        if (list && list.length > 0)
            return list[0].width
        return Screen.width
    }
    readonly property bool fullscreenActive: Hyprland.focusedWorkspace
        ? Hyprland.focusedWorkspace.hasFullscreen
        : false

    function optionAt(index) {
        if (!options || index < 0 || index >= options.length)
            return null
        return options[index]
    }

    function modeOn(id) {
        var _epoch = modeEpoch
        return !!(modes && modes[id] === true)
    }

    function applyStatus(text) {
        var data
        try {
            data = JSON.parse(text)
        } catch (e) {
            return
        }
        if (!data)
            return
        modes = {
            dnd: data.dnd === true,
            night: data.night === true,
            awake: data.awake === true,
            record: data.record === true,
            elapsed: data.elapsed || 0
        }
        modeEpoch = modeEpoch + 1
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.exec(["bash", Quickshell.shellPath("status.sh")])
    }

    function burst() {
        pollBurst.ticks = 0
        if (!pollBurst.running)
            pollBurst.start()
    }

    function toggle(id) {
        Quickshell.execDetached(["bash", Quickshell.shellPath("toggle.sh"), id])
        burst()
    }

    anchors {
        left: true
        top: true
    }

    margins {
        left: Math.round(screenWidth / 2) + 52
        top: 4
    }

    implicitWidth: options.length * buttonWidth + 8
    implicitHeight: barHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    visible: !fullscreenActive

    WlrLayershell.namespace: "changteezy-indicators"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: pollBurst
        interval: 350
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks = ticks + 1
            root.refresh()
            if (ticks >= 8)
                stop()
        }
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            id: statusOut
            waitForEnd: true
            onStreamFinished: root.applyStatus(statusOut.text)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#cc1a1b26"
        radius: 0

        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4

            Repeater {
                model: root.options.length

                Item {
                    id: button
                    required property int index
                    readonly property var option: root.optionAt(index)
                    readonly property bool on: option ? root.modeOn(option.id) : false
                    readonly property bool recording: option && option.id === "record" && on
                    width: root.buttonWidth
                    height: root.barHeight

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: button.option ? button.option.icon : ""
                        color: button.recording
                            ? root.recordColor
                            : button.on
                                ? root.activeColor
                                : clickArea.containsMouse
                                    ? root.hoverColor
                                    : root.idleColor
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        font.weight: button.on ? Font.DemiBold : Font.Normal

                        Behavior on color {
                            ColorAnimation { duration: 80 }
                        }
                    }

                    MouseArea {
                        id: clickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (button.option)
                                root.toggle(button.option.id)
                        }
                    }
                }
            }
        }
    }
}
