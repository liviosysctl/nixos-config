import QtQuick
import Qt5Compat.GraphicalEffects

// A bar label that reacts to the pointer the way waybar's modules do: the
// colour moves, and a very slight glow rises and settles behind it.
//
// This is `icon-pulse`, the keyframe the waybar config this bar replaced ran
// `forwards` on :hover. It was a `text-shadow`:
//
//     0%   { text-shadow: 0 0 0px alpha(@color4, 0);   }
//     50%  { text-shadow: 0 0 6px alpha(@color4, 0.3); }
//     100% { text-shadow: 0 0 3px alpha(@color4, 0.1); }
//
// So it overshoots and settles rather than fading in — which is most of why
// it reads as a response to the pointer rather than as a state. `strength`
// below is that curve as one number: 0 at rest, 1 at the peak, 0.35 held.
//
// Replaces the translucent white rectangle every one of these used to grow on
// hover. A filled background inside a pane of glass reads as a second, smaller
// pane; this reads as the glyph noticing you.
Item {
    id: pulse

    required property var theme

    property alias text: label.text
    // Reached as `font.pixelSize` and so on at the call site, the same way it
    // would be on a plain Text.
    property alias font: label.font

    property color color: pulse.theme.fg
    // What the glow is made of. Usually the colour being hovered *into*, so
    // the halo leads the text rather than trailing it.
    property color glowColor: pulse.color

    // Named `lit` and not `hovered`: some callers light this for a reason
    // other than the pointer being over it.
    property bool lit: false

    // Room for the halo. The glow is drawn into the source item's own bounds,
    // so without padding it is cut off square at the edges of the glyph —
    // which looks like a rendering fault, not a glow. The padding goes on the
    // Text and comes back off the implicit size, so callers still lay this out
    // as though it were the bare label.
    //
    // Has to clear the Glow's radius below, or widening the blur just moves
    // where it gets clipped.
    readonly property int halo: Math.ceil(11 * pulse.theme.zoom)

    property real strength: 0

    implicitWidth: label.implicitWidth - pulse.halo * 2
    implicitHeight: label.implicitHeight - pulse.halo * 2

    onLitChanged: {
        // Both animations drive `strength`, so the other one has to be off
        // the property before this one takes it — otherwise a fast in-out-in
        // leaves two animations fighting and the glow sticks.
        rise.stop();
        fall.stop();
        if (pulse.lit)
            rise.start();
        else
            fall.start();
    }

    // Behind the label, so the crisp glyph sits on top of its own halo. That
    // is what `text-shadow` does, and it is why this is declared first.
    Glow {
        anchors.fill: label
        source: label
        // A Glow with nothing to show still costs a texture and a shader pass
        // per frame, and there are a dozen of these on the bar.
        visible: pulse.strength > 0
        // Wider and fainter than the CSS it came from — waybar's 6px at 0.3
        // is a halo you notice; this is one you only notice the absence of.
        // The two move together on purpose: spreading the same light over a
        // larger radius is what makes it read as soft rather than as a
        // smaller, dimmer version of the same ring.
        radius: 6 * pulse.theme.zoom * pulse.strength
        // Wants roughly 2·radius+1 to stay smooth at the top of the range,
        // and the range now tops out near 14px. Under-sampling a wide blur
        // shows up as concentric banding, which is the opposite of soft.
        samples: 29
        color: pulse.glowColor
        opacity: 0.15 * pulse.strength
    }

    Text {
        id: label

        anchors.centerIn: parent
        padding: pulse.halo
        color: pulse.color
        font.family: pulse.theme.fontFamily
        font.bold: pulse.theme.fontBold
        font.pixelSize: pulse.theme.fontSize

        Behavior on color {
            ColorAnimation {
                duration: 250
            }
        }
    }

    SequentialAnimation {
        id: rise

        NumberAnimation {
            target: pulse
            property: "strength"
            to: 1
            duration: 400
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: pulse
            property: "strength"
            to: 0.35
            duration: 400
            easing.type: Easing.InOutQuad
        }
    }

    NumberAnimation {
        id: fall

        target: pulse
        property: "strength"
        to: 0
        duration: 250
    }
}
