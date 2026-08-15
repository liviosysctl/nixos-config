import Quickshell
import QtQuick

import "../theme"

// CPU and memory, side by side — waybar's #cpu and #memory, whose `on-click`
// is bound to the same thing.
Row {
    id: widget

    required property var theme
    required property var resources

    spacing: widget.theme.gap

    // waybar opens btop in `${vars.terminal} -e btop`. TERMINAL is exported
    // from that same nix value in modules/home/default.nix, so reading it here
    // keeps one definition of "the terminal" rather than hardcoding a second.
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    function openMonitor() {
        Quickshell.execDetached([widget.terminal, "-e", "btop"]);
    }

    component Readout: Item {
        id: readout

        property string glyph
        property int value

        // Reserved at the width of the longest string this can ever hold,
        // rather than hugging the current one. CPU load moves constantly, and
        // a readout that hugs it changes width on nearly every sample —
        // which shoves the whole island, and everything right of it, a few
        // pixels sideways twice a second.
        implicitWidth: metrics.width
        implicitHeight: widget.theme.controlSize

        TextMetrics {
            id: metrics

            font: label.font
            text: readout.glyph + " 100%"
        }

        PulseText {
            id: label

            anchors.centerIn: parent
            theme: widget.theme
            text: readout.glyph + " " + readout.value + "%"
            lit: pointer.containsMouse
            color: pointer.containsMouse ? widget.theme.hover : widget.theme.fg
            glowColor: widget.theme.hover
            font.pixelSize: widget.theme.fontSize
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: widget.openMonitor()
        }
    }

    Readout {
        glyph: ""  // fa-microchip
        value: widget.resources.cpu
    }

    Readout {
        glyph: ""  // fa-memory
        value: widget.resources.memory
    }
}
