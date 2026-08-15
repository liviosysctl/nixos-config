import Quickshell
import QtQuick
import QtQuick.Layouts

import "../theme"

// Two glyphs in the bar — network and bluetooth — sharing one panel between
// them. Clicking either opens the same card on that glyph's tab, which is how
// the original ties the two together.
Row {
    id: widget

    required property var theme
    required property var net
    required property var bt

    spacing: Math.round(2 * widget.theme.zoom)

    function show(mode) {
        if (popup.visible && cardItem.mode === mode) {
            popup.visible = false;
            return;
        }
        cardItem.mode = mode;
        popup.visible = true;
    }

    component GlyphButton: Rectangle {
        id: button

        property string glyph
        property string label: ""
        property string target
        property bool lit: false
        property bool shown: true

        readonly property bool current: popup.visible && cardItem.mode === button.target

        visible: button.shown
        implicitWidth: buttonRow.implicitWidth + Math.round(14 * widget.theme.zoom)
        implicitHeight: Math.round(24 * widget.theme.zoom)
        radius: height / 2
        color: "transparent"

        // Open state is a bloom rather than a fill — hover is already
        // answered by the glyphs themselves, and a rectangle here would be a
        // pane inside a pane.
        Shine {
            anchors.fill: parent
            theme: widget.theme
            active: button.current
        }

        RowLayout {
            id: buttonRow

            anchors.centerIn: parent
            spacing: Math.round(5 * widget.theme.zoom)

            PulseText {
                Layout.alignment: Qt.AlignVCenter
                theme: widget.theme
                text: button.glyph
                font.pixelSize: widget.theme.glyphSize
                lit: buttonHover.containsMouse
                color: buttonHover.containsMouse ? widget.theme.hover : (button.lit ? widget.theme.fg : widget.theme.dim)
                glowColor: widget.theme.hover
            }

            PulseText {
                Layout.alignment: Qt.AlignVCenter
                theme: widget.theme
                text: button.label
                font.pixelSize: widget.theme.smallFontSize
                lit: buttonHover.containsMouse
                color: buttonHover.containsMouse ? widget.theme.hover : widget.theme.dim
                glowColor: widget.theme.hover
                visible: button.label !== ""
            }
        }

        MouseArea {
            id: buttonHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: widget.show(button.target)
        }
    }

    GlyphButton {
        glyph: widget.net.glyph
        // Matches the waybar module: the icon carries the state on its own
        // while connected, and only a disconnect earns words.
        label: widget.net.online ? "" : "Disconnected"
        target: widget.net.wired ? "eth" : "wifi"
        lit: widget.net.online
        // The service reports no devices until it finishes connecting to
        // NetworkManager; showing nothing beats flashing a false state.
        shown: widget.net.ready
    }

    GlyphButton {
        glyph: widget.bt.glyph
        label: widget.bt.connectedDevices.length > 1 ? widget.bt.connectedDevices.length : ""
        target: "bt"
        lit: widget.bt.connectedDevices.length > 0
        shown: widget.bt.present
    }

    PopupWindow {
        id: popup

        anchor.item: widget
        // Right-aligned: the pair sits on the right of the bar, so the panel
        // hangs down and to the left of it.
        anchor.rect.x: widget.width
        anchor.rect.y: widget.height + 7
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: cardItem.implicitWidth
        implicitHeight: cardItem.implicitHeight
        color: "transparent"

        // Also what lets the passphrase field receive keystrokes.
        grabFocus: true
        visible: false

        onVisibleChanged: {
            // Both services gate their expensive work on this.
            widget.net.active = popup.visible;
            widget.bt.active = popup.visible;
            if (popup.visible) {
                reveal.restart();
            } else {
                cardItem.pending = null;
                cardItem.failure = "";
                widget.bt.status = "";
            }
        }

        ConnectivityCard {
            id: cardItem

            theme: widget.theme
            net: widget.net
            bt: widget.bt
            active: popup.visible

            focus: true
            Keys.onEscapePressed: popup.visible = false

            transform: Translate {
                id: slide
            }
        }

        ParallelAnimation {
            id: reveal

            NumberAnimation {
                target: cardItem
                property: "opacity"
                from: 0
                to: 1
                duration: 130
            }

            NumberAnimation {
                target: slide
                property: "y"
                from: -10
                to: 0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }
}
