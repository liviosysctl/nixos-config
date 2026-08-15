import Quickshell
import QtQuick

// The bar's colours, optionally derived from the wallpaper.
//
// The fixed values below were ported from the waybar palette this bar
// replaced, and they are what this emits whenever `enabled` is false or the
// wallpaper gives nothing usable. That is on
// purpose: "off" has to be a state this object can be *in*, not a reason to
// bypass it. Routing both cases through the same properties is what lets
// turning the feature off cross-fade like everything else instead of cutting.
//
// One instance is the live palette; a second with `enabled: false` is the
// fixed one the media widget keeps. See ../shell.qml.
QtObject {
    id: palette

    // The wallpaper to read, as an absolute path. Empty means the slideshow
    // has not reported one yet, which is not the same as "no colours" — it is
    // "no answer yet", and the fixed palette is the right thing to show while
    // waiting rather than something derived from a half-loaded image.
    property string source: ""

    property bool enabled: true

    // Matched to the wallpaper's own transition by ../shell.qml, so the bar
    // and the desktop behind it move together rather than the bar arriving
    // late to a change it is meant to be part of.
    property int fadeDuration: 700

    // ── Fixed palette ──────────────────────────────────────────────────
    readonly property color baseBg: "#1d2021"       // @background
    readonly property color baseBgAlt: "#282828"    // @second-background
    readonly property color baseFg: "#bfd7ea"       // @color6
    readonly property color baseDim: "#848598"      // @color7
    readonly property color baseAccent: "#bfd7ea"   // @color6 — active/selected
    readonly property color baseHover: "#ffc8d8"    // @color4 — waybar's hover
    // waybar hardcodes this one on #custom-startmenu, which is the nix logo.
    readonly property color baseAccentAlt: "#7ebae4"

    // ── Derivation ─────────────────────────────────────────────────────
    readonly property ColorQuantizer quantizer: ColorQuantizer {
        // Only read the file when it is going to be used. Quantizing a 4K
        // image every time the slideshow ticks is not free, and with the
        // feature off the answer is thrown away.
        source: palette.enabled && palette.source ? "file://" + palette.source : ""
        // 2^4 buckets. Media.qml gets away with 8 because it needs one accent
        // out of a 300px cover; a wallpaper is asked for a whole palette, and
        // at 8 the second-most-saturated bucket is usually the same colour as
        // the first.
        depth: 4
        rescaleSize: 96
    }

    // The colour everything else is built from: the most saturated bucket,
    // discounted for being very dark or very light.
    //
    // Straight "most saturated" picks the blown-out corner of a sky or the
    // one lit pixel in a night shot — technically saturated, and useless as
    // an accent because there is no room left to move its lightness into a
    // legible band without losing the hue it was chosen for.
    readonly property var seed: {
        let best = null;
        let bestScore = 0;
        for (const candidate of palette.quantizer.colors) {
            if (candidate.hslSaturation < 0.18)
                continue;
            const score = candidate.hslSaturation * (1 - Math.abs(candidate.hslLightness - 0.5) * 1.2);
            if (score > bestScore) {
                bestScore = score;
                best = candidate;
            }
        }
        return best;
    }

    // A greyscale wallpaper has no hue to give, and inventing one would be
    // inventing a theme rather than deriving it.
    readonly property bool derived: palette.enabled && palette.source !== "" && palette.seed !== null

    readonly property real hue: palette.seed?.hslHue ?? 0
    readonly property real saturation: palette.seed?.hslSaturation ?? 0

    function shift(amount) {
        return (palette.hue + amount + 1) % 1;
    }

    // Hues live on a circle, so 0.02 and 0.98 are neighbours rather than
    // opposites. Everything comparing two hues has to go through this.
    function hueGap(left, right) {
        const raw = Math.abs(left - right);
        return Math.min(raw, 1 - raw);
    }

    // ── A second, deliberately different accent ────────────────────────
    // One thing on the bar is meant not to match: the nix logo. So rather
    // than exempting it from the palette and hardcoding a colour — which
    // would be the one pill visibly ignoring the wallpaper — it gets an
    // accent of its own, from the same image.
    //
    // The best candidate is the most saturated bucket that is *far enough
    // away* in hue from the seed to read as a different colour rather than as
    // the accent rendered slightly wrong. A twelfth of the circle is about
    // where that stops being ambiguous.
    readonly property var seedAlt: {
        if (!palette.seed)
            return null;
        let best = null;
        let bestScore = 0;
        for (const candidate of palette.quantizer.colors) {
            if (candidate.hslSaturation < 0.18)
                continue;
            if (palette.hueGap(candidate.hslHue, palette.hue) < 0.083)
                continue;
            const score = candidate.hslSaturation * (1 - Math.abs(candidate.hslLightness - 0.5) * 1.2);
            if (score > bestScore) {
                bestScore = score;
                best = candidate;
            }
        }
        return best;
    }

    // A wallpaper can easily be one hue and nothing else — a sunset, a forest.
    // Rotating most of the way round the circle is the fallback: still derived
    // from the image, still unmistakably a different colour from the accent.
    readonly property real hueAlt: palette.seedAlt ? palette.seedAlt.hslHue : palette.shift(0.45)
    readonly property real saturationAlt: palette.seedAlt ? palette.seedAlt.hslSaturation : palette.saturation

    // ── Output ─────────────────────────────────────────────────────────
    // Everything hangs off one hue, which is what makes a generated palette
    // read as deliberate rather than as a wallpaper smeared across a bar. The
    // variation is in saturation and lightness, plus a small hue nudge on
    // hover so it is distinguishable from the accent it sits next to.

    // Also used as a fill under bg-coloured text — the focused workspace pill
    // — so the lightness floor is not cosmetic. Below about 0.6 the label
    // stops reading.
    property color accent: palette.derived ? Qt.hsla(palette.hue, Math.max(0.45, Math.min(0.8, palette.saturation)), 0.66, 1) : palette.baseAccent

    property color hover: palette.derived ? Qt.hsla(palette.shift(0.06), Math.max(0.55, Math.min(0.9, palette.saturation)), 0.8, 1) : palette.baseHover

    // Treated exactly like `accent` — same saturation clamp, same lightness —
    // so the two read as siblings from one palette rather than as one themed
    // colour and one stray.
    property color accentAlt: palette.derived ? Qt.hsla(palette.hueAlt, Math.max(0.45, Math.min(0.8, palette.saturationAlt)), 0.66, 1) : palette.baseAccentAlt

    // Near-white, washed with the wallpaper rather than tinted by it: at more
    // than about a quarter saturation, body text starts to look like it is
    // trying to be a colour.
    property color fg: palette.derived ? Qt.hsla(palette.hue, 0.22, 0.88, 1) : palette.baseFg

    property color dim: palette.derived ? Qt.hsla(palette.hue, 0.14, 0.62, 1) : palette.baseDim

    // The glass fills. These are half-transparent over a compositor blur, so
    // they are seen mostly as a tint on the wallpaper — which is exactly why
    // they should be near-black and share its hue rather than carry any of
    // its saturation.
    property color bg: palette.derived ? Qt.hsla(palette.hue, 0.22, 0.085, 1) : palette.baseBg

    property color bgAlt: palette.derived ? Qt.hsla(palette.hue, 0.18, 0.16, 1) : palette.baseBgAlt

    // ── The fade ───────────────────────────────────────────────────────
    // On the properties themselves rather than on anything downstream: every
    // glass fill, border and hover state in the bar is derived from these six
    // by binding, so animating here moves all of them together for free.
    //
    // These are plain properties with a binding rather than readonly ones
    // because a Behavior needs a property it can write.
    Behavior on accent {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on hover {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on accentAlt {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on fg {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on dim {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on bg {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }

    Behavior on bgAlt {
        ColorAnimation {
            duration: palette.fadeDuration
        }
    }
}
