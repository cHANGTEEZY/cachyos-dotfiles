import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    readonly property int workspaceCount: 5
    readonly property int buttonWidth: 30
    readonly property int activeWorkspace: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0
        ? Hyprland.focusedWorkspace.id
        : 1
    readonly property int firstWorkspace: Math.max(1, activeWorkspace - workspaceCount + 1)
    readonly property int activeIndex: activeWorkspace - firstWorkspace
    readonly property bool fullscreenActive: Hyprland.focusedWorkspace
        ? Hyprland.focusedWorkspace.hasFullscreen
        : false

    function focusWorkspace(target) {
        if (Hyprland.usingLua) {
            const value = typeof target === "number" ? String(target) : "'" + target + "'"
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + value + " })")
        } else {
            Hyprland.dispatch("workspace " + target)
        }
    }

    function cycleWorkspace(delta) {
        if (delta < 0)
            root.focusWorkspace("m-1")
        else
            root.focusWorkspace("m+1")
    }

    anchors {
        left: true
        top: true
    }

    margins {
        left: 6
        top: 4
    }

    implicitWidth: workspaceCount * buttonWidth + 8
    implicitHeight: 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    visible: !root.fullscreenActive

    // Overlay sits above waybar. Fullscreen hides this window so games still cover it.
    WlrLayershell.namespace: "changteezy-workspaces"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "#cc1a1b26"
        radius: 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                root.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
                event.accepted = true
            }
        }

        Item {
            anchors {
                fill: parent
                leftMargin: 4
                rightMargin: 4
            }

            Rectangle {
                id: activeUnderline
                z: 1
                x: root.activeIndex * root.buttonWidth + 5
                y: parent.height - 2
                width: 20
                height: 2
                radius: 1
                color: "#7aa2f7"

                Behavior on x {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors.fill: parent
                z: 2

                Repeater {
                    model: root.workspaceCount

                    Item {
                        required property int index
                        readonly property int workspaceId: root.firstWorkspace + index
                        width: root.buttonWidth
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: parent.workspaceId
                            color: parent.workspaceId === root.activeWorkspace
                                ? "#7dcfff"
                                : clickArea.containsMouse
                                    ? "#ffffff"
                                    : "#c0caf5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.weight: parent.workspaceId === root.activeWorkspace
                                ? Font.DemiBold
                                : Font.Normal

                            Behavior on color {
                                ColorAnimation { duration: 80 }
                            }
                        }

                        MouseArea {
                            id: clickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusWorkspace(parent.workspaceId)
                            onWheel: event => {
                                root.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
