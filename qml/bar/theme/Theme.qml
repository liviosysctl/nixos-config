import QtQuick

// Everything visual the widgets read: colours, the glass they are made of,
// metrics and fonts. This is the object every widget is handed as `theme`,
// so restyling the bar means touching one file rather than hunting through
// the widgets.
//
// The colours come from a Palette, which may or may not be deriving them from
// the wallpaper. Two of these exist — see ../shell.qml — because the media
// widget has an accent of its own, taken from the cover art, and a second
// generated palette fighting it would leave that widget the only thing on the
// bar wearing two.
QtObject {
    id: theme

    required property var palette

    // ── Palette ────────────────────────────────────────────────────────
    readonly property color bg: theme.palette.bg
    readonly property color bgAlt: theme.palette.bgAlt
    readonly property color fg: theme.palette.fg
    readonly property color dim: theme.palette.dim
    readonly property color accent: theme.palette.accent
    // A second accent, deliberately unlike the first. Exactly one thing wears
    // it — the nix logo — and see ../session/README.md for why that thing is
    // allowed to stand out.
    readonly property color accentAlt: theme.palette.accentAlt
    readonly property color hover: theme.palette.hover

    // Fixed, and deliberately not derived. These three say "connected",
    // "degraded" and "failed", and a wallpaper that turned the battery
    // warning teal would have made the bar prettier and less useful. Meaning
    // is not a thing to generate.
    readonly property color good: "#8ec07c"     // @color2
    readonly property color warn: "#d2b48c"     // @color1
    readonly property color bad: "#c53f67"      // @color0

    // ── Glass ──────────────────────────────────────────────────────────
    // Half-transparent fills over a compositor blur, lit along the top edge
    // and fading towards the bottom, so each island reads as a pane of glass
    // rather than a flat panel. Hyprland does the actual blurring —
    // `frostedLayer` for the qs-bar layer in
    // modules/home/hyprland/windowrules.nix, the same rules waybar runs.
    // Nothing here blurs anything itself; without that rule this still
    // renders, just transparent instead of frosted.
    //
    // How much fill an island carries, and the one number to change to put it
    // back. 0 is fully transparent — the wallpaper, the pill's rim, and the
    // glyphs, with nothing between them.
    //
    // **This is deliberately below Hyprland's `ignore_alpha`, which is 0.5.**
    // That threshold is tested per *pixel*, not per surface, so an island
    // under it is simply not blurred while everything above it still is —
    // which is the point here rather than a side effect. 0.5 is also what the
    // waybar this replaced filled its modules with, so anything from 0.5 up
    // brings the frosting back.
    //
    // The blur's *strength*, if that is what wants adjusting instead, is
    // `decoration.blur.size` and `.passes` in
    // modules/home/hyprland/decorations.nix — currently 3 and 3, and `passes`
    // is the one that dominates.
    readonly property real surfaceAlpha: 0.5
    readonly property color surface: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, theme.surfaceAlpha)
    // Popups sit over arbitrary windows rather than over the wallpaper, so
    // they carry more fill than the bar does.
    readonly property color cardSurface: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.72)
    // Menus and dropdowns stack on top of a card that is already translucent,
    // and two sheets at 0.72 add up to something you can read the desktop
    // through. This one is nearly solid so the layering stays legible.
    readonly property color menuSurface: Qt.rgba(theme.bg.r, theme.bg.g, theme.bg.b, 0.94)
    readonly property color edgeTop: Qt.rgba(1, 1, 1, 0.25)
    readonly property color edgeSide: Qt.rgba(1, 1, 1, 0.12)
    readonly property color edgeBottom: Qt.rgba(1, 1, 1, 0.05)

    // ── Metrics ────────────────────────────────────────────────────────
    // Every number below is a base value times `zoom`, so resizing the bar is
    // one edit rather than a hunt through the widgets. The base values are the
    // ones the bar was originally drawn at, kept visible in the arithmetic so
    // it stays obvious what zoom is doing to each of them.
    //
    // Called `zoom` and not `scale` on purpose: widgets read this from inside
    // an Item, and `scale` there is a QQuickItem property that silently means
    // something else.
    readonly property real zoom: 1.4

    readonly property int barHeight: Math.round(38 * theme.zoom)
    // The bar floats rather than sitting on the screen edge, so the wallpaper
    // shows through above and beside the islands.
    readonly property int barMargin: Math.round(4 * theme.zoom)
    // Each module is its own pane, so an island is a pill rather than a panel:
    // shorter than the bar, with the wallpaper visible above and below it as
    // well as between the modules.
    readonly property int islandHeight: Math.round(30 * theme.zoom)
    readonly property int islandRadius: Math.round(12 * theme.zoom)
    readonly property int islandPadding: Math.round(10 * theme.zoom)
    // Between two islands. Wide enough that they read as separate panes,
    // narrow enough that a row of them still reads as one group.
    readonly property int islandGap: Math.round(6 * theme.zoom)
    readonly property int pillRadius: Math.round(9 * theme.zoom)
    // Inside an island, between welded controls.
    readonly property int gap: Math.round(8 * theme.zoom)

    // A square button holding one glyph — settings, wlogout, idle, a tray
    // icon. Named rather than repeated, because before this there were four
    // separate `implicitWidth: 26`s that all had to be found and changed
    // together for the bar to resize without going lopsided.
    readonly property int controlSize: Math.round(26 * theme.zoom)
    // A text or glyph pill inside an island — the clock, a workspace.
    readonly property int pillHeight: Math.round(22 * theme.zoom)

    // Carried over from the waybar this replaced, back when the two ran side
    // by side and had to look like one system. Only the family and weight came
    // across — its 15pt would not fit the bar at any zoom.
    readonly property string fontFamily: "CodeNewRoman Nerd Font Propo"
    readonly property bool fontBold: true

    // Bar text. Popups and the settings window deliberately do *not* zoom —
    // they are already sized to be read, and a 1.4× settings dialog is a
    // worse settings dialog. So these are the bar's sizes only.
    readonly property int fontSize: Math.round(13 * theme.zoom)
    readonly property int smallFontSize: Math.round(12 * theme.zoom)
    readonly property int glyphSize: Math.round(14 * theme.zoom)
}
