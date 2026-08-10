import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Monitor configuration: reading what Hyprland reports, and getting changes
// back into it.
//
// Two separate things have to happen for a change to stick.
//
//  1. `hyprctl eval` applies it to the running compositor. Note *eval*, not
//     `keyword` — this config drives Hyprland's lua parser, and `keyword`
//     answers "keyword can't work with non-legacy parsers. Use eval." eval
//     takes the same hl.*() calls the config file is written in.
//  2. Rewriting ~/.config/hypr/monitors.lua is what survives a reload. The
//     generated hyprland.lua requires that file; see the extraConfig block in
//     modules/home/hyprland/default.nix.
//
// Applying without writing would silently revert on the next reload, and
// writing without applying would do nothing until then, so `apply()` does
// both and reports if either half fails.
Scope {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string configPath: root.configHome + "/hypr/monitors.lua"

    // Shown under the buttons. Empty means nothing to say.
    property string status: ""
    property bool failed: false
    property bool busy: false

    // Held across the apply so the verify step can check what was asked for
    // against what Hyprland actually did.
    property var requested: []

    signal applied

    // ── VRR capability ─────────────────────────────────────────────────
    // Connector name -> bool, from vrrcap.sh. Hyprland reports whether VRR is
    // *on*, never whether the display could do it, so the answer has to come
    // from the DRM connector property instead. See the script.
    //
    // An output missing from here is unknown rather than incapable, and the
    // page leaves unknowns switchable: refusing a setting that would have
    // worked is worse than offering one Hyprland then declines, which the
    // post-apply check catches anyway.
    property var vrrCapable: ({})

    function vrrSupported(name) {
        return root.vrrCapable[name] ?? true;
    }

    // Cheap (~60ms) and only on the way in, so the page always opens against
    // the hardware that is plugged in now rather than a startup snapshot.
    function refreshCapabilities() {
        vrrProcess.running = true;
    }

    // Same idiom as connectivity/Net.qml and media/Cava.qml: resolved against
    // this file so it works from the store and from a working tree alike.
    readonly property string scriptPath: Qt.resolvedUrl("vrrcap.sh").toString().replace("file://", "")

    Process {
        id: vrrProcess

        command: ["bash", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vrrCapable = JSON.parse(this.text);
                } catch (error) {
                    // A shell that cannot answer leaves every output unknown,
                    // which leaves every toggle live. Same outcome as the
                    // script's own `{}` fallback.
                    root.vrrCapable = ({});
                }
            }
        }
    }

    // ── Mode parsing ───────────────────────────────────────────────────
    // hyprctl reports availableModes as "3840x2160@144.00Hz" strings, and it
    // repeats itself — this machine lists 32 entries covering rather fewer
    // real modes. Splitting resolution from rate is what lets the two
    // selectors act independently, which is the part of ilyamiro's monitor
    // page worth taking: pick a resolution, then pick from the rates that
    // resolution actually supports.

    function ratesByResolution(modes) {
        const table = {};
        for (const mode of modes ?? []) {
            const at = mode.indexOf("@");
            if (at === -1)
                continue;
            const resolution = mode.substring(0, at);
            const rate = parseFloat(mode.substring(at + 1));
            if (!isFinite(rate))
                continue;
            if (!table[resolution])
                table[resolution] = [];
            // Rates that differ only past two decimals are the same mode
            // reported twice, and offering both would be a coin flip.
            if (!table[resolution].some(known => Math.abs(known - rate) < 0.01))
                table[resolution].push(rate);
        }
        for (const resolution in table)
            table[resolution].sort((a, b) => b - a);
        return table;
    }

    // Biggest first. The native mode is nearly always the one wanted and
    // nearly always the largest, so it lands at the top of the list.
    function resolutionsOf(table) {
        return Object.keys(table).sort((a, b) => {
            const left = a.split("x");
            const right = b.split("x");
            return (right[0] * right[1]) - (left[0] * left[1]);
        });
    }

    // Hyprland wants two decimals in a mode string and reports rates with
    // rather more, so both ends get rounded the same way or a mode that is
    // already set reads as a change.
    function modeString(resolution, rate) {
        return resolution + "@" + rate.toFixed(2);
    }

    function rateLabel(rate) {
        return rate.toFixed(2).replace(/\.?0+$/, "") + " Hz";
    }

    // The entry in `rates` closest to what the monitor is currently running,
    // because hyprctl's reported refreshRate (143.99899) never exactly equals
    // the mode list's (144.00).
    function nearestRate(rates, actual) {
        let best = 0;
        for (let i = 1; i < rates.length; i++) {
            if (Math.abs(rates[i] - actual) < Math.abs(rates[best] - actual))
                best = i;
        }
        return best;
    }

    // ── Scale ──────────────────────────────────────────────────────────
    // Hyprland refuses a scale that does not divide the resolution into whole
    // logical pixels, so offering the full list would mostly be offering
    // errors. Filtering against the chosen resolution means everything shown
    // is something Hyprland will take.
    readonly property var scaleChoices: [1, 1.25, 1.333333, 1.5, 1.75, 2, 2.5, 3]

    function scalesFor(resolution) {
        const parts = resolution.split("x");
        const width = Number(parts[0]);
        const height = Number(parts[1]);
        return root.scaleChoices.filter(scale => {
            const logicalWidth = width / scale;
            const logicalHeight = height / scale;
            return Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.001 && Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.001;
        });
    }

    function scaleLabel(scale) {
        // 1.333333 is the only choice that is not exact, and "1.33x" is what
        // it is called everywhere else.
        return (Math.round(scale * 100) / 100) + "x";
    }

    // ── Applying ───────────────────────────────────────────────────────

    // `entries` is [{ output, mode, position, scale, vrr }]. Positions are
    // carried over from what Hyprland already reports: there is no arrange
    // canvas here, so a resolution change keeps each output's existing
    // top-left.
    //
    // vrr goes in the per-monitor rule rather than the global misc:vrr, so
    // one display can run adaptive while another stays fixed.
    function luaFor(entries) {
        const calls = entries.map(entry => `hl.monitor({
    output = "${entry.output}",
    mode = "${entry.mode}",
    position = "${entry.position}",
    scale = ${entry.scale},
    vrr = ${entry.vrr}
})`);

        return `-- Generated by the quickshell settings panel. Do not edit manually.
-- Rewritten in full every time Displays is applied.

${calls.join("\n")}
`;
    }

    function apply(entries) {
        if (root.busy || entries.length === 0)
            return;

        root.busy = true;
        root.failed = false;
        root.status = "Applying…";
        root.requested = entries;

        // Live first. There is no point writing a file that would fail the
        // same way on the next reload.
        applyProcess.command = ["hyprctl", "eval", root.luaFor(entries).split("\n").filter(line => !line.startsWith("--")).join("\n")];
        applyProcess.running = true;
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            onStreamFinished: {
                // A lua error comes back on stdout rather than as an exit
                // code. Note that a *bad mode* does not: Hyprland accepts the
                // rule and quietly ignores it, which is why apply is followed
                // by a read-back rather than trusted on its own.
                if (this.text.trim().startsWith("error")) {
                    root.busy = false;
                    root.failed = true;
                    root.status = this.text.trim();
                    return;
                }
                config.setText(root.luaFor(root.requested));
            }
        }
    }

    // Written whole rather than patched: this file is generated output, and
    // half-updating it is how you end up with two rules for one output.
    FileView {
        id: config

        path: root.configPath
        // The compositor reads this on reload. A torn write would cost the
        // session its display config.
        atomicWrites: true
        printErrors: false

        onSaved: verify.restart()

        onSaveFailed: {
            root.busy = false;
            root.failed = true;
            root.status = "Applied, but could not write " + root.configPath;
        }
    }

    // Hyprland needs a moment to settle a mode switch before its own IPC
    // reports the new state.
    Timer {
        id: verify

        interval: 700
        onTriggered: {
            Hyprland.refreshMonitors();
            check.restart();
        }
    }

    Timer {
        id: check

        interval: 250
        onTriggered: {
            const missed = [];
            let vrrPending = false;

            for (const entry of root.requested) {
                const monitor = Hyprland.monitors.values.find(candidate => candidate.name === entry.output);
                if (!monitor)
                    continue;

                const actual = `${monitor.width}x${monitor.height}`;
                if (actual !== entry.mode.split("@")[0] || Math.abs(monitor.scale - entry.scale) > 0.01)
                    missed.push(entry.output);

                // VRR is checked separately because it is not a failure when
                // it does not take. Hyprland reads a monitor rule's vrr when
                // it brings the output up and not afterwards: setting the
                // rule on a running session is accepted, reports ok, and
                // changes nothing — confirmed down at the DRM level, where
                // VRR_ENABLED stays 0. The global misc:vrr does apply live,
                // but flipping that would drag every other output along with
                // it. So the file is correct and the session catches up when
                // Hyprland next starts.
                const vrr = (monitor.lastIpcObject?.vrr ?? false) ? 1 : 0;
                if (vrr !== entry.vrr)
                    vrrPending = true;
            }

            root.busy = false;
            root.failed = missed.length > 0;
            // Hyprland takes a monitor rule without complaint and then drops
            // it if the mode will not drive, so the only honest check is what
            // the outputs are actually doing afterwards.
            if (missed.length > 0)
                root.status = "Hyprland did not take: " + missed.join(", ");
            else if (vrrPending)
                root.status = "Saved. VRR applies the next time Hyprland starts.";
            else
                root.status = "Saved to " + root.configPath;
            root.applied();
        }
    }
}
