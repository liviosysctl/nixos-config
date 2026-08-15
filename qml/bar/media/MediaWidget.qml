import Quickshell
import QtQuick
import QtQuick.Layouts

// The bar-resident half of the media player: a spectrum pill that expands
// into MediaCard when clicked. Collapses to nothing when no player exists,
// so an idle desktop keeps a clean bar.
Rectangle {
    id: widget

    required property var theme
    required property var media
    required property var cava

    // The nix logo's accent, handed down from shell.qml. It cannot be read
    // off `theme`: this widget runs on the *fixed* palette so its own colours
    // stay out of the wallpaper's way, and this one colour has to come from
    // the live one to actually match the logo it is echoing.
    required property color openAccent

    readonly property var player: widget.media.player
    readonly property bool expanded: popup.visible

    visible: widget.player !== null
    implicitWidth: row.implicitWidth + Math.round(18 * widget.theme.zoom)
    implicitHeight: Math.round(24 * widget.theme.zoom)
    radius: height / 2
    color: "transparent"

    // The one open-state exception on the bar. Everything else blooms; this
    // recolours instead — the bars themselves are the widget, so pushing them
    // towards a colour says "open" more directly than lighting the empty
    // space around them would.
    //
    // The colour it moves towards is the nix logo's, which is the other thing
    // on the bar wearing a deliberately-not-the-accent accent. Mixed rather
    // than replaced, so the track's own colour is still in there and the
    // spectrum does not stop being the cover art's.
    readonly property color barColor: widget.expanded ? Qt.tint(widget.media.accent, Qt.rgba(widget.openAccent.r, widget.openAccent.g, widget.openAccent.b, 0.55)) : widget.media.accent

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Math.round(8 * widget.theme.zoom)

        Spectrum {
            Layout.preferredHeight: Math.round(14 * widget.theme.zoom)
            Layout.alignment: Qt.AlignVCenter
            values: widget.cava.values
            // The hover cue, in place of a background: the bars lift rather
            // than sitting in a wash of their own colour. Applied on top of
            // `barColor`, so hovering an open player brightens the mixed
            // colour instead of dropping back to the unmixed one.
            color: pointer.containsMouse ? Qt.lighter(widget.barColor, 1.35) : widget.barColor
            barWidth: Math.round(3 * widget.theme.zoom)
            barSpacing: Math.round(2 * widget.theme.zoom)

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton)
                widget.player?.togglePlaying();
            else
                popup.visible = !popup.visible;
        }

        onWheel: function (wheel) {
            if (wheel.angleDelta.y > 0)
                widget.player?.next();
            else
                widget.player?.previous();
        }
    }

    PopupWindow {
        id: popup

        anchor.item: widget
        anchor.rect.y: widget.height + 7
        anchor.gravity: Edges.Bottom | Edges.Right
        // Keep the card on screen when the pill sits near a screen edge.
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: cardItem.implicitWidth
        implicitHeight: cardItem.implicitHeight
        color: "transparent"

        // Lets the compositor dismiss the popup on an outside click. That
        // path writes `visible` directly, which is why `visible` is the
        // source of truth for expansion instead of a bool bound to it.
        grabFocus: true
        visible: false

        onVisibleChanged: if (popup.visible)
            reveal.restart()

        MediaCard {
            id: cardItem

            theme: widget.theme
            media: widget.media
            cava: widget.cava
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
