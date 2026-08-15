import QtQuick

// A switch in the bar's glass. Same reasoning as Select.qml: styling
// QtQuick.Controls' Switch into this palette costs more than drawing one.
Rectangle {
    id: toggle

    required property var theme

    property bool checked: false

    // Item.enabled is the one read below, not a property of our own — it
    // already gates the MouseArea, and redeclaring it shadows the base member.

    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2

    color: toggle.checked ? Qt.rgba(toggle.theme.accent.r, toggle.theme.accent.g, toggle.theme.accent.b, toggle.enabled ? 0.85 : 0.3) : Qt.rgba(toggle.theme.fg.r, toggle.theme.fg.g, toggle.theme.fg.b, pointer.containsMouse && toggle.enabled ? 0.18 : 0.1)

    border.width: 1
    border.color: toggle.checked ? "transparent" : Qt.rgba(1, 1, 1, 0.1)

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Rectangle {
        id: knob

        // Travels between the two ends rather than being anchored, so the
        // Behavior below has something to interpolate.
        x: toggle.checked ? toggle.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        // The accent is a light colour, so a knob riding on top of it has to
        // be the dark background colour to stay visible.
        color: toggle.checked ? toggle.theme.bg : toggle.theme.fg
        opacity: toggle.enabled ? 1 : 0.4

        Behavior on x {
            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
