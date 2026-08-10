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

    readonly property var player: widget.media.player
    readonly property bool expanded: popup.visible

    visible: widget.player !== null
    implicitWidth: row.implicitWidth + 18
    implicitHeight: 24
    radius: height / 2
    color: pointer.containsMouse || widget.expanded ? Qt.rgba(widget.media.accent.r, widget.media.accent.g, widget.media.accent.b, 0.16) : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 8

        Spectrum {
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter
            values: widget.cava.values
            color: widget.media.accent
            barWidth: 3
            barSpacing: 2
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
