import QtQuick

// Places n pills in a ring around the core, and works out how big they can be
// without touching each other.
//
// Positions are computed, never animated: a ring of moving targets is
// miserable to click, so nothing here rotates. The pills also carry no
// connecting lines back to the core — the ring reads perfectly well without
// them, and they only add clutter that has to be drawn on every frame.
Item {
    id: orbit

    property int count: 0

    property real pillWidth: 114
    property real pillHeight: 40
    // Every other pill is pulled slightly inward. Purely cosmetic — it gives
    // the staggered look of the original without changing the spacing rule.
    property real zigzag: 0.86
    property real clearance: 10
    property real coreRadius: 58
    // Below this the labels stop being legible, so it is where the ring stops
    // accepting pills rather than a size it is allowed to reach.
    property real minScale: 0.72

    readonly property real centreX: width / 2
    readonly property real centreY: height / 2
    readonly property real radiusX: width / 2 - pillWidth / 2 - clearance
    readonly property real radiusY: height / 2 - pillHeight / 2 - clearance

    function ringFactor(index) {
        return index % 2 === 0 ? 1 : orbit.zigzag;
    }

    function angleAt(index, total) {
        // Start at the top so a lone pill sits above the core rather than off
        // to one side.
        return -Math.PI / 2 + index * 2 * Math.PI / Math.max(1, total);
    }

    function centreOf(index, total) {
        const angle = orbit.angleAt(index, total);
        const factor = orbit.ringFactor(index);
        return {
            x: Math.cos(angle) * orbit.radiusX * factor,
            y: Math.sin(angle) * orbit.radiusY * factor
        };
    }

    // Does this many pills at this scale touch anything?
    //
    // Closed-form spacing rules were tried first and all of them were wrong
    // somewhere: on an ellipse the arc between neighbours is not uniform, and
    // the zigzag makes the tightest pair depend on parity as well as on n.
    // Testing the actual rectangles is a handful of comparisons and is right
    // by construction.
    function collides(total, scale) {
        const halfWidth = orbit.pillWidth * scale / 2;
        const halfHeight = orbit.pillHeight * scale / 2;
        const points = [];

        for (let i = 0; i < total; i++) {
            const point = orbit.centreOf(i, total);

            // Against the core.
            const dx = Math.max(0, Math.abs(point.x) - halfWidth);
            const dy = Math.max(0, Math.abs(point.y) - halfHeight);
            if (Math.hypot(dx, dy) < orbit.coreRadius + orbit.clearance)
                return true;

            // Against every pill already placed.
            for (const other of points) {
                if (Math.abs(point.x - other.x) < halfWidth * 2 + orbit.clearance && Math.abs(point.y - other.y) < halfHeight * 2 + orbit.clearance)
                    return true;
            }
            points.push(point);
        }
        return false;
    }

    // Largest scale in (minScale, 1] that fits, or 0 when even minScale does
    // not — the card treats that as "this many will not go on the ring".
    function fit(total) {
        if (total <= 1)
            return 1;
        if (!orbit.collides(total, 1))
            return 1;
        if (orbit.collides(total, orbit.minScale))
            return 0;

        let low = orbit.minScale;
        let high = 1;
        for (let step = 0; step < 14; step++) {
            const mid = (low + high) / 2;
            if (orbit.collides(total, mid))
                high = mid;
            else
                low = mid;
        }
        return low;
    }

    // How many of `wanted` will actually go on the ring.
    function capacity(wanted) {
        let total = wanted;
        while (total > 1 && orbit.fit(total) === 0)
            total--;
        return total;
    }
}
