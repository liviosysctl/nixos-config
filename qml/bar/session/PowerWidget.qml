import Quickshell
import QtQuick

import "../theme"

// wlogout, behind the nix logo — waybar's #custom-startmenu, which is bound to
// the same command.
//
// The one pill on the bar that is meant not to match. waybar paints it a fixed
// nix blue (#7ebae4) to set it apart from the row of white glyphs; doing that
// here would leave it the single thing visibly ignoring the wallpaper. So it
// gets `accentAlt` instead: a second accent quantized out of the same image,
// picked for being far enough round the hue circle from the first to read as a
// different colour. Set apart, and still part of the theme.
Item {
    id: widget

    required property var theme

    implicitWidth: widget.theme.controlSize
    implicitHeight: widget.theme.controlSize

    PulseText {
        anchors.centerIn: parent

        theme: widget.theme
        text: ""  // linux-nixos
        lit: pointer.containsMouse
        color: pointer.containsMouse ? widget.theme.hover : widget.theme.accentAlt
        // The halo leads the colour change rather than trailing it.
        glowColor: widget.theme.hover
        font.pixelSize: widget.theme.glyphSize

        // The same turn the settings gear does. The nix snowflake is
        // three-fold symmetric, so 120° lands it back on itself — anything
        // else and it settles visibly crooked, which the gear's 60° does not
        // suffer because a gear has far more teeth than three.
        rotation: pointer.containsMouse ? 120 : 0

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

        // `session-menu`, not `wlogout` — the wrapper in
        // modules/home/wlogout.nix pins the button count its stylesheet is
        // drawn for. Calling wlogout directly gets the default 3-per-row grid
        // and a theme built for a single strip.
        //
        // Detached, not a Process: it outlives the click and has no output
        // worth collecting, and tying a modal session menu's lifetime to the
        // bar would take it down with a shell reload.
        onClicked: Quickshell.execDetached(["session-menu"])
    }
}
