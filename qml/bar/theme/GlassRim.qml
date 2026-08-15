import QtQuick
import Qt5Compat.GraphicalEffects

// The edge of a pane of glass: brightest and thickest along the top, thinning
// and dimming down the sides, almost gone underneath.
//
// That asymmetry is the whole effect. A uniform hairline reads as an outline
// drawn around a shape; an edge that catches more light where the light is
// reads as a real bevel with a body behind it — which is what sells a pill
// that has nothing inside it at all.
//
// **`Rectangle.border` cannot do this.** `border.width` is a single number for
// all four sides, so a bordered rectangle is the one thing this cannot be
// built from. The ring is a shape instead: a rounded rectangle filled with a
// top-to-bottom gradient, with an inner rounded rectangle masked out of it.
// Because that inner cutout is inset by a *different* amount on each side, the
// ring left behind varies in thickness — thickest wherever its cutout is
// furthest from the edge.
//
// Everything is antialiased by the mask rather than by a border stroke, so the
// sub-pixel widths at the bottom render as a faint line rather than
// disappearing or snapping to a whole pixel.
Item {
    id: rim

    required property var theme

    property real cornerRadius: rim.theme.islandRadius

    // Top-lit, so these run thick to thin. Scaled with the bar, or the edge
    // would get proportionally finer every time the bar grew.
    //
    // The ratio between them is the effect; the absolute size is taste. Keep
    // roughly 3.4 : 2 : 1 when retuning — flatten it and the rim goes back to
    // reading as a uniform outline.
    property real topWidth: 1.0 * rim.theme.zoom
    property real sideWidth: 0.7 * rim.theme.zoom
    property real bottomWidth: 0.35 * rim.theme.zoom

    // The same three edge colours the old bevel used, now actually falling off
    // around the ring instead of being a gradient hidden behind the body.
    property color topColor: rim.theme.edgeTop
    property color sideColor: rim.theme.edgeSide
    property color bottomColor: rim.theme.edgeBottom

    // ── The ring's colour ──────────────────────────────────────────────
    // Hidden: this is only ever read through the mask below. `layer.enabled`
    // is what makes it available as a texture to sample.
    Rectangle {
        id: band

        anchors.fill: parent
        radius: rim.cornerRadius
        visible: false
        layer.enabled: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: rim.topColor
            }

            GradientStop {
                position: 0.5
                color: rim.sideColor
            }

            GradientStop {
                position: 1
                color: rim.bottomColor
            }
        }
    }

    // ── The hole ───────────────────────────────────────────────────────
    Item {
        id: cutout

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: rim.sideWidth
            y: rim.topWidth
            width: Math.max(0, parent.width - rim.sideWidth * 2)
            height: Math.max(0, parent.height - rim.topWidth - rim.bottomWidth)
            // Follows the outer corner minus the edge it sits inside, so the
            // ring keeps an even thickness *around* the corner instead of
            // bunching up in it.
            radius: Math.max(0, rim.cornerRadius - rim.sideWidth)
            // Only the alpha is read. Any opaque colour would do.
            color: "black"
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: band
        maskSource: cutout
        // Keep the gradient where the cutout is *absent* — that leftover is
        // the ring. Without this it would paint the hole and drop the edge,
        // which is the same shape inside out.
        invert: true
    }
}
