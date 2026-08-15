import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

// Picks the one MPRIS player the widget acts on, and derives an accent
// colour from its cover art. Instantiated once and shared by every bar, so
// all screens agree on which player is "the" player.
Scope {
    id: root

    // Used when there is no art, or when the art has nothing saturated
    // enough to give a legible accent.
    property color fallbackAccent: "#7aa2f7"

    readonly property var players: Mpris.players.values

    // Whichever player is currently producing sound. Reading isPlaying here
    // is what registers the dependency, so this re-evaluates when any player
    // starts or stops.
    readonly property var playing: {
        for (const player of root.players) {
            if (player.isPlaying)
                return player;
        }
        return null;
    }

    // The player being controlled. Assigned rather than bound, so that it
    // sticks to the last player that produced sound: pausing must not make
    // the widget hop to whatever else happens to be registered.
    property var player: null

    Component.onCompleted: root.player = root.playing ?? root.players[0] ?? null

    onPlayingChanged: if (root.playing)
        root.player = root.playing

    onPlayersChanged: if (!root.player || root.players.indexOf(root.player) === -1)
        root.player = root.playing ?? root.players[0] ?? null

    // ── The player's own audio stream ──────────────────────────────────
    // The pipewire node the chosen player is feeding, so the visualiser can
    // watch that rather than the default sink's monitor. The monitor carries
    // everything the machine is playing, which is why a Discord hover blip
    // used to jump the spectrum mid-track.
    //
    // MPRIS and pipewire name the same application differently and neither is
    // authoritative — MPRIS has "Supersonic" and a bus name ending in
    // ".Supersonic", pipewire has a node called "supersonic" — so the match is
    // done on normalised names, and accepts containment because a browser
    // reports an identity like "Mozilla zen" against a node called "zen".
    function normalise(text) {
        return (text ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function alike(left, right) {
        if (left === "" || right === "")
            return false;
        return left === right || left.includes(right) || right.includes(left);
    }

    readonly property var stream: {
        const player = root.player;
        if (!player)
            return null;

        // The bus name's tail is the most reliable of the two: an identity is
        // free text, while the tail is what the application chose to register
        // as. `.instance_1_2` suffixes that browsers append come off first.
        const bus = root.normalise((player.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance.*$/, ""));
        const identity = root.normalise(player.identity);

        // Exact before approximate. Containment is what lets an identity of
        // "Mozilla zen" find a node called "Zen", and it has to stay — but it
        // is also what would let a short name land on the wrong application
        // entirely, and there is no fallback behind this any more to make that
        // survivable. So an exact match anywhere in the list beats a
        // containment match, whatever order pipewire happens to report them.
        let loose = null;

        for (const node of Pipewire.nodes.values) {
            if (node.type !== PwNodeType.AudioOutStream)
                continue;

            const name = root.normalise(node.name);
            if (name === "")
                continue;

            if (name === bus || name === identity)
                return node;

            if (!loose && (root.alike(name, bus) || root.alike(name, identity)))
                loose = node;
        }

        return loose;
    }

    // What cava is pointed at. `node.name` rather than the object serial:
    // cava only reads its source once at startup, and a name survives the
    // player tearing its stream down and opening a new one.
    readonly property string streamName: root.stream?.name ?? ""

    // ColorQuantizer buckets the cover down to 2^depth colours.
    ColorQuantizer {
        id: quantizer

        source: root.player?.trackArtUrl ?? ""
        depth: 3
        rescaleSize: 64
    }

    // Cover art is frequently near-black or near-grey, which would leave the
    // spectrum invisible. Take the most saturated bucket and force it into a
    // band that stays readable against the dark bar.
    property color accent: {
        let best = null;
        for (const candidate of quantizer.colors) {
            if (candidate.hslSaturation < 0.25)
                continue;
            if (!best || candidate.hslSaturation > best.hslSaturation)
                best = candidate;
        }
        if (!best)
            return root.fallbackAccent;
        return Qt.hsla(best.hslHue, Math.max(0.45, best.hslSaturation), Math.max(0.6, Math.min(0.72, best.hslLightness)), 1);
    }

    // Track changes swing the accent hard; fade rather than cut.
    Behavior on accent {
        ColorAnimation {
            duration: 350
        }
    }
}
