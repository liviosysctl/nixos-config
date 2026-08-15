import QtQuick
import Qt5Compat.GraphicalEffects

// A soft bloom in the accent colour, marking the one item whose panel is
// currently open.
//
// This replaces the translucent rectangle those items used to grow. A flat
// fill inside a pane of glass reads as a second, smaller pane — the same
// reason the hover fills went — and on a tray icon it read worse still, as a
// button that had somehow been pressed in. Light spilling out from behind the
// icon says "this one is showing you something" without drawing another
// shape.
//
// Goes *behind* the content, so it has to be declared before whatever it is
// marking.
Item {
    id: shine

    required property var theme

    property bool active: false
    property color color: shine.theme.accent
    // Alpha at the centre. Low on purpose: this is a hint that something is
    // open, competing with nothing, and the thing it is behind still has to
    // be the readable part.
    property real strength: 0.38

    opacity: shine.active ? 1 : 0
    // A RadialGradient at zero opacity is still a texture and a shader pass,
    // and most of these are inactive most of the time.
    visible: shine.opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    RadialGradient {
        id: bloom

        anchors.fill: parent

        // **Both of these have to be set.** RadialGradient defaults them to
        // the full `width` and `height`, not half — so left alone, the whole
        // item sits inside the first half of the gradient and the bloom gets
        // chopped off square at the edges. It renders as a flat rectangle
        // with hard sides, which is precisely the thing this exists to avoid.
        // At half, the gradient reaches its last stop exactly on the item's
        // boundary and there is nothing left to clip.
        horizontalRadius: bloom.width / 2
        verticalRadius: bloom.height / 2

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(shine.color.r, shine.color.g, shine.color.b, shine.strength)
            }

            // Held up through the middle before falling away, so the bloom
            // has a body rather than being a point that immediately fades.
            GradientStop {
                position: 0.5
                color: Qt.rgba(shine.color.r, shine.color.g, shine.color.b, shine.strength * 0.4)
            }

            // The accent at zero alpha, not `"transparent"`. Qt's transparent
            // is *black* with no alpha, and interpolating towards it drags
            // the falloff through progressively darker colour on the way —
            // a dirty ring around the bloom instead of a clean fade.
            GradientStop {
                position: 1
                color: Qt.rgba(shine.color.r, shine.color.g, shine.color.b, 0)
            }
        }
    }
}
