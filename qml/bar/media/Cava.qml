import Quickshell
import Quickshell.Io
import QtQuick

// Runs `cava` in raw-ascii mode and republishes every frame as an array of
// floats in 0..1. One instance feeds every visualiser on screen — cava is
// the expensive part, the renderers are not.
Scope {
    id: root

    // Must match `bars` in cava.conf.
    readonly property int bars: 16

    // Whether anything is worth visualising. Drives both the published
    // values and, via the linger below, the process itself.
    property bool active: false

    // cava polls the sink monitor for as long as it is up, so it does not
    // stay running forever. It does not get killed on the spot either: a
    // cold process needs about a second to connect to pipewire and let
    // autosens settle, which reads as a dead visualiser followed by an
    // overshoot. At ~1% of a core it is cheaper to linger through short
    // pauses and release it only once one turns out to be a long one.
    property int lingerMs: 30000

    // Which pipewire node to listen to: the node.name of one application's
    // output stream — "supersonic", "Zen", "spotify".
    //
    // **Empty means listen to nothing, and cava does not run.** There is no
    // fallback to the default sink's monitor, deliberately. The monitor is
    // every sound the machine makes, so a spectrum pointed at it visualises a
    // Discord call, a notification blip and a video in another window exactly
    // as readily as the track the widget claims to be showing. A visualiser
    // that is honestly blank is better than one that is confidently wrong
    // about what it is drawing.
    //
    // cava.sh still understands "auto" for anything that genuinely wants the
    // whole machine; this component just will not ask for it on its own.
    property string source: ""

    // Nothing to bind to means nothing to draw. Kept separate from `active`
    // so a caller can still express "playing" honestly while this reports
    // that it has no stream to follow.
    readonly property bool bound: root.source !== ""

    // Latest frame. Flat while inactive, so a stopped visualiser reads as
    // silence instead of freezing on whatever cava emitted last.
    property var values: root.silence()

    // Resolved against this file rather than against the shell root, so the
    // folder stays self-contained if it is moved or reused. Both want a
    // filesystem path, hence stripping the URL scheme.
    readonly property string scriptPath: Qt.resolvedUrl("cava.sh").toString().replace("file://", "")

    // cava reads its source once, at startup, and has no flag to change it, so
    // following a new player means a new process. Restarting through a flag
    // rather than by writing `running` directly, because writing it would
    // destroy the binding below and with it the whole linger mechanism.
    property bool restarting: false

    onSourceChanged: {
        // The old application's frames are still in the pipe and would keep
        // drawing for a moment against the new one's name.
        root.values = root.silence();
        root.restarting = true;
        bounce.restart();
    }

    Timer {
        id: bounce

        // Long enough for the old process to actually be gone before the
        // binding brings a new one up on the same stdout.
        interval: 120
        onTriggered: root.restarting = false
    }

    function silence() {
        return new Array(root.bars).fill(0);
    }

    onBoundChanged: if (!root.bound)
        root.values = root.silence()

    onActiveChanged: {
        if (root.active) {
            linger.stop();
            return;
        }
        // The lingering process keeps producing frames, but onRead drops
        // them while inactive, so this sticks until playback resumes.
        root.values = root.silence();
        linger.restart();
    }

    Timer {
        id: linger

        interval: root.lingerMs
    }

    Process {
        // `bound` gates the process outright: without a stream to name there
        // is nothing to start it against, and starting it anyway is precisely
        // how it used to end up on the default monitor.
        running: root.bound && (root.active || linger.running) && !root.restarting
        command: ["bash", root.scriptPath, root.source]

        stdout: SplitParser {
            splitMarker: "\n"

            // "12;40;7;...;" — note the trailing delimiter leaves an empty
            // final field, which is why we index by bar count rather than
            // walking the split result.
            onRead: function (line) {
                // Frames keep coming while the process lingers, and killing
                // it flushes whatever was still buffered in the pipe — both
                // land after the reset in onActiveChanged. Without this
                // guard they overwrite the silence and the visualiser
                // freezes on the last frame before the pause.
                if (!root.active || !root.bound)
                    return;

                const fields = line.split(";");
                const frame = [];
                for (let i = 0; i < root.bars; i++) {
                    const value = parseInt(fields[i], 10);
                    frame.push(isNaN(value) ? 0 : Math.min(1, value / 100));
                }
                root.values = frame;
            }
        }
    }
}
