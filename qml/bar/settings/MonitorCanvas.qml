import QtQuick

// The outputs drawn to scale in Hyprland's own coordinate space, so their
// relative sizes and positions are the ones the compositor uses. Click to
// select, drag to move.
//
// Everything here works in *logical* pixels — a 3840x2160 panel at scale 1.5
// occupies a 2560x1440 slot, and that slot is what neighbouring outputs butt
// up against. Drawing the raw resolution instead would show two displays
// overlapping that in fact sit side by side.
Item {
    id: canvas

    required property var theme
    required property var drafts
    property int selectedIndex: 0

    // How close two edges have to be, in logical pixels, before a drag lands
    // flush against one. Scaled by the view so it stays roughly a constant
    // distance on screen whatever the layout spans.
    readonly property int snapDistance: Math.round(24 / Math.max(canvas.factor, 0.001))

    signal selected(int index)

    // ── Fitting ────────────────────────────────────────────────────────
    // The bounding box of every output, recomputed as they move.
    readonly property var bounds: {
        if (!canvas.drafts || canvas.drafts.length === 0)
            return {
                x: 0,
                y: 0,
                width: 1,
                height: 1
            };

        let left = Infinity;
        let top = Infinity;
        let right = -Infinity;
        let bottom = -Infinity;

        for (const draft of canvas.drafts) {
            left = Math.min(left, draft.x);
            top = Math.min(top, draft.y);
            right = Math.max(right, draft.x + draft.logicalWidth);
            bottom = Math.max(bottom, draft.y + draft.logicalHeight);
        }

        return {
            x: left,
            y: top,
            width: Math.max(1, right - left),
            height: Math.max(1, bottom - top)
        };
    }

    readonly property int inset: 18
    // One factor for both axes, or the monitors would come out stretched.
    readonly property real factor: Math.min((canvas.width - canvas.inset * 2) / canvas.bounds.width, (canvas.height - canvas.inset * 2) / canvas.bounds.height)

    // Centred in whatever space is left over once the layout is fitted.
    readonly property real originX: (canvas.width - canvas.bounds.width * canvas.factor) / 2
    readonly property real originY: (canvas.height - canvas.bounds.height * canvas.factor) / 2

    function toView(logicalX, logicalY) {
        return Qt.point(canvas.originX + (logicalX - canvas.bounds.x) * canvas.factor, canvas.originY + (logicalY - canvas.bounds.y) * canvas.factor);
    }

    // Move an output, clamped and then snapped. The only way positions change,
    // so the typed X/Y fields go through it too and cannot escape the bounds
    // a drag respects.
    function place(draft, wantX, wantY) {
        const bounded = canvas.clamp(draft, wantX, wantY);
        canvas.snap(draft, bounded.x, bounded.y);
    }

    // However many outputs there are, the arrangement never usefully spans
    // more than all of them laid end to end — so that is the envelope a
    // position is allowed to reach, and it grows with the number of monitors
    // exactly as you would expect.
    //
    // Without this a drag can fling an output into empty space, and since the
    // view scales to fit the bounding box, everything else collapses to a dot
    // in the corner and becomes unclickable.
    function clamp(draft, wantX, wantY) {
        let spanX = 0;
        let spanY = 0;
        let left = Infinity;
        let top = Infinity;
        let right = -Infinity;
        let bottom = -Infinity;

        for (const other of canvas.drafts) {
            spanX += other.logicalWidth;
            spanY += other.logicalHeight;
            if (other === draft)
                continue;
            left = Math.min(left, other.x);
            top = Math.min(top, other.y);
            right = Math.max(right, other.x + other.logicalWidth);
            bottom = Math.max(bottom, other.y + other.logicalHeight);
        }

        // A lone output has nothing to be positioned relative to, and Hyprland
        // normalises the layout to the origin anyway.
        if (!isFinite(left))
            return Qt.point(0, 0);

        // Keep the union of this output and the rest inside the envelope: it
        // may reach one full span left of the others' right edge, or one full
        // span right of their left edge, and no further.
        return Qt.point(Math.round(Math.max(right - spanX, Math.min(left + spanX - draft.logicalWidth, wantX))), Math.round(Math.max(bottom - spanY, Math.min(top + spanY - draft.logicalHeight, wantY))));
    }

    // Pull an edge flush with a neighbour's when it lands close enough. Both
    // axes are considered separately, so an output can snap horizontally while
    // staying free vertically.
    function snap(draft, wantX, wantY) {
        let bestX = wantX;
        let bestY = wantY;
        let gapX = canvas.snapDistance;
        let gapY = canvas.snapDistance;

        for (const other of canvas.drafts) {
            if (other === draft)
                continue;

            // Butt against either side, or line the two left/right edges up.
            for (const candidate of [other.x + other.logicalWidth, other.x - draft.logicalWidth, other.x, other.x + other.logicalWidth - draft.logicalWidth]) {
                const gap = Math.abs(wantX - candidate);
                if (gap < gapX) {
                    gapX = gap;
                    bestX = candidate;
                }
            }

            for (const candidate of [other.y + other.logicalHeight, other.y - draft.logicalHeight, other.y, other.y + other.logicalHeight - draft.logicalHeight]) {
                const gap = Math.abs(wantY - candidate);
                if (gap < gapY) {
                    gapY = gap;
                    bestY = candidate;
                }
            }
        }

        draft.x = Math.round(bestX);
        draft.y = Math.round(bestY);
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(canvas.theme.bg.r, canvas.theme.bg.g, canvas.theme.bg.b, 0.35)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    Repeater {
        model: canvas.drafts

        delegate: Rectangle {
            id: screen

            required property var modelData
            required property int index

            readonly property bool current: canvas.selectedIndex === screen.index
            readonly property point origin: canvas.toView(screen.modelData.x, screen.modelData.y)

            x: screen.origin.x
            y: screen.origin.y
            width: screen.modelData.logicalWidth * canvas.factor
            height: screen.modelData.logicalHeight * canvas.factor

            radius: 6
            color: screen.current ? Qt.rgba(canvas.theme.accent.r, canvas.theme.accent.g, canvas.theme.accent.b, 0.3) : Qt.rgba(canvas.theme.fg.r, canvas.theme.fg.g, canvas.theme.fg.b, drag.containsMouse ? 0.16 : 0.09)

            border.width: screen.current ? 2 : 1
            border.color: screen.current ? canvas.theme.accent : Qt.rgba(1, 1, 1, 0.12)

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: screen.modelData.name
                    color: canvas.theme.fg
                    font.family: canvas.theme.fontFamily
                    font.bold: true
                    font.pixelSize: 13
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${screen.modelData.logicalWidth}×${screen.modelData.logicalHeight}`
                    color: canvas.theme.dim
                    font.family: canvas.theme.fontFamily
                    font.pixelSize: 10
                    // Hidden rather than elided on a small tile: the name is
                    // what identifies it, and half a number reads as damage.
                    visible: screen.width > 96
                }
            }

            MouseArea {
                id: drag

                // Position is tracked on the draft rather than through
                // Drag/drag.target, because the draft is the thing that has to
                // end up correct — the tile's own x/y is a binding off it.
                property real grabX: 0
                property real grabY: 0

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onPressed: mouse => {
                    canvas.selected(screen.index);
                    drag.grabX = mouse.x;
                    drag.grabY = mouse.y;
                }

                onPositionChanged: mouse => {
                    if (!drag.pressed)
                        return;
                    // Back out of view pixels into logical ones before asking
                    // for a position, so clamping and snapping think in the
                    // same units the compositor does.
                    const wantX = screen.modelData.x + (mouse.x - drag.grabX) / canvas.factor;
                    const wantY = screen.modelData.y + (mouse.y - drag.grabY) / canvas.factor;
                    canvas.place(screen.modelData, wantX, wantY);
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "No outputs"
        color: canvas.theme.dim
        font.family: canvas.theme.fontFamily
        font.pixelSize: 12
        visible: !canvas.drafts || canvas.drafts.length === 0
    }
}
