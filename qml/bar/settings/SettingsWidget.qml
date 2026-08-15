import Quickshell
import QtQuick

import "../theme"

// The settings button in the bar, and the overlay it opens. Both live here so
// shell.qml only has to place one item.
Item {
    id: widget

    required property var theme
    required property var displays
    required property var wallpaper

    readonly property bool open: window.open

    implicitWidth: widget.theme.controlSize
    implicitHeight: widget.theme.controlSize

    PulseText {
        anchors.centerIn: parent

        theme: widget.theme
        text: ""  // fa-gear
        lit: pointer.containsMouse || widget.open
        color: pointer.containsMouse || widget.open ? widget.theme.hover : widget.theme.fg
        glowColor: widget.theme.hover
        font.pixelSize: widget.theme.fontSize
        // A gear that turns as you reach for it is the one bit of motion
        // a settings button gets to have.
        rotation: pointer.containsMouse || widget.open ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: window.open = !window.open
    }

    SettingsWindow {
        id: window

        theme: widget.theme
        displays: widget.displays
        wallpaper: widget.wallpaper
        // Follows the bar it hangs off, so the panel opens on the screen
        // whose button was clicked.
        screen: widget.QsWindow.window?.screen ?? null
    }
}
