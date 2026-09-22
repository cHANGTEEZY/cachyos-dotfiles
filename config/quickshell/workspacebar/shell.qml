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
    implicitHeight: 18
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    visible: !root.fullscreenActive

    WlrLayershell.namespace: "changteezy-workspaces"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "#80141414"
        radius: 10

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
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.InOutCubic
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
                                ? "#ffffff"
                                : clickArea.containsMouse
                                    ? "#d0ffffff"
                                    : "#8cffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: parent.workspaceId === root.activeWorkspace
                                ? Font.DemiBold
                                : Font.Normal

                            Behavior on color {
                                ColorAnimation { duration: 180 }
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
