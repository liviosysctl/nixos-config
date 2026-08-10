import Quickshell
import QtQuick

// The gear in the bar, and the overlay it opens. Both live here so shell.qml
// only has to place one item.
Item {
    id: widget

    required property var theme
    required property var displays

    readonly property bool open: window.open

    implicitWidth: 26
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: widget.theme.pillRadius
        color: pointer.containsMouse || widget.open ? Qt.rgba(widget.theme.fg.r, widget.theme.fg.g, widget.theme.fg.b, 0.12) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Text {
            anchors.centerIn: parent
            text: ""  // fa-cog
            color: pointer.containsMouse || widget.open ? widget.theme.hover : widget.theme.fg
            font.family: widget.theme.fontFamily
            font.bold: widget.theme.fontBold
            font.pixelSize: 13
            // A gear that turns as you reach for it is the one bit of motion
            // a settings button gets to have.
            rotation: pointer.containsMouse || widget.open ? 60 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 250
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
    }

    SettingsWindow {
        id: window

        theme: widget.theme
        displays: widget.displays
        // Follows the bar it hangs off, so the panel opens on the screen
        // whose gear was clicked.
        screen: widget.QsWindow.window?.screen ?? null
    }
}
