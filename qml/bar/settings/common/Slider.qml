import QtQuick

// A slider in the bar's glass. Same reasoning as Select.qml and Toggle.qml:
// restyling QtQuick.Controls' Slider into this palette costs more code than
// drawing one, and leaves a stock Qt widget sitting in the middle of
// everything else here whenever the style misses a state.
//
// `value` is not written by the drag. The handle reports where it was let go
// and the owner decides what to store, which is what keeps a slider bound to
// a persisted setting from fighting its own binding mid-drag.
Item {
    id: slider

    required property var theme

    property real value: 0
    property real from: 0
    property real to: 1
    // 0 means continuous. Anything else snaps, which is what makes a duration
    // land on 1.5 rather than 1.4732.
    property real stepSize: 0

    // Drawn to the right of the groove. The owner formats it, because only
    // the owner knows whether this is seconds, a percentage or a count.
    property string display: ""

    // Emitted continuously while dragging, so a caller that wants a live
    // preview can have one.
    signal moved(real value)
    // Emitted once, on release. This is the one to persist on.
    signal committed(real value)

    implicitWidth: 168
    implicitHeight: 32

    readonly property real span: Math.max(1e-9, slider.to - slider.from)
    readonly property real position: Math.max(0, Math.min(1, (slider.value - slider.from) / slider.span))

    function quantise(raw) {
        const clamped = Math.max(slider.from, Math.min(slider.to, raw));
        if (slider.stepSize <= 0)
            return clamped;
        const steps = Math.round((clamped - slider.from) / slider.stepSize);
        // Rounded again at the end because from + steps * stepSize
        // accumulates float error, and a "1.5" that is really
        // 1.4999999999999998 shows up in a JSON file forever.
        return Math.round((slider.from + steps * slider.stepSize) * 1e6) / 1e6;
    }

    Text {
        id: readout

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: slider.display
        color: slider.enabled ? slider.theme.fg : slider.theme.dim
        font.family: slider.theme.fontFamily
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        // Reserved rather than hugged, so the groove does not twitch shorter
        // every time the number gains a digit.
        width: 44
    }

    // ── Groove ─────────────────────────────────────────────────────────
    Item {
        id: track

        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        Rectangle {
            id: groove

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(slider.theme.fg.r, slider.theme.fg.g, slider.theme.fg.b, 0.12)

            Rectangle {
                width: groove.width * slider.position
                height: parent.height
                radius: parent.radius
                color: slider.enabled ? Qt.rgba(slider.theme.accent.r, slider.theme.accent.g, slider.theme.accent.b, 0.85) : Qt.rgba(slider.theme.fg.r, slider.theme.fg.g, slider.theme.fg.b, 0.2)
            }
        }

        Rectangle {
            id: handle

            x: groove.width * slider.position - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: slider.enabled ? slider.theme.accent : slider.theme.dim
            scale: pointer.containsMouse || pointer.pressed ? 1.2 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function valueAt(x) {
                return slider.quantise(slider.from + (x / Math.max(1, groove.width)) * slider.span);
            }

            // A click anywhere on the groove jumps there and starts a drag, so
            // the handle never has to be hit exactly.
            onPressed: mouse => slider.moved(pointer.valueAt(mouse.x))
            onPositionChanged: mouse => {
                if (pointer.pressed)
                    slider.moved(pointer.valueAt(mouse.x));
            }
            onReleased: mouse => slider.committed(pointer.valueAt(mouse.x))
        }
    }
}
