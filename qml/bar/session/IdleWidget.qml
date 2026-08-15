import QtQuick

import "../theme"

// The idle inhibitor, ported from waybar's #idle_inhibitor module.
//
// Same glyph in both states, and only the colour moves — which is what the
// waybar config does too, deliberately: `format-icons` names  for both
// `activated` and `deactivated`, and `#idle_inhibitor.activated` turns it
// @color2. A cup of coffee already says "staying up"; swapping it for a
// different picture would only make the two states harder to tell apart at a
// glance than one colour change does.
Item {
    id: widget

    required property var theme
    required property var idle

    implicitWidth: widget.theme.controlSize
    implicitHeight: widget.theme.controlSize

    PulseText {
        anchors.centerIn: parent

        theme: widget.theme
        text: ""  // fa-mug_saucer
        lit: pointer.containsMouse
        // Held beats hovered, which is the order waybar's cascade lands on:
        // `.activated` is declared after `:hover`, so a lit inhibitor stays
        // green under the pointer instead of flicking back to the hover colour
        // and reading as though the click had missed.
        color: widget.idle.inhibited ? widget.theme.good : (pointer.containsMouse ? widget.theme.hover : widget.theme.fg)
        // Held, the halo is green too — otherwise hovering an active inhibitor
        // throws a pink glow round a green glyph.
        glowColor: widget.idle.inhibited ? widget.theme.good : widget.theme.hover
        font.pixelSize: widget.theme.fontSize
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: widget.idle.toggle()
    }
}
