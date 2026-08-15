import QtQuick

// A push button in the bar's glass. `primary` fills it with the accent for
// the one action a panel is actually about; everything else stays an outline
// so a row of buttons has an obvious answer.
Rectangle {
    id: button

    required property var theme

    property string label
    property bool primary: false

    // Item.enabled, not one of our own: it already gates the MouseArea below,
    // and redeclaring it shadows the base member rather than replacing it.

    signal triggered

    implicitWidth: text.implicitWidth + 30
    implicitHeight: 30
    radius: 9

    color: {
        if (!button.enabled)
            return Qt.rgba(button.theme.fg.r, button.theme.fg.g, button.theme.fg.b, 0.05);
        if (button.primary)
            return pointer.containsMouse ? button.theme.accent : Qt.rgba(button.theme.accent.r, button.theme.accent.g, button.theme.accent.b, 0.8);
        return pointer.containsMouse ? Qt.rgba(button.theme.fg.r, button.theme.fg.g, button.theme.fg.b, 0.16) : Qt.rgba(button.theme.fg.r, button.theme.fg.g, button.theme.fg.b, 0.08);
    }

    border.width: 1
    border.color: button.primary || !button.enabled ? "transparent" : Qt.rgba(1, 1, 1, 0.1)

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Text {
        id: text

        anchors.centerIn: parent
        text: button.label
        // The accent is a light colour, so a filled button needs the dark
        // background colour on top of it rather than the usual foreground.
        color: !button.enabled ? button.theme.dim : (button.primary ? button.theme.bg : button.theme.fg)
        font.family: button.theme.fontFamily
        font.bold: button.primary
        font.pixelSize: 12
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: button.triggered()
    }
}
