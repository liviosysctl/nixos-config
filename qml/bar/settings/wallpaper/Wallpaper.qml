import Quickshell
import Quickshell.Io
import QtQuick

// The wallpaper's settings, and what is on screen right now.
//
// Deliberately *not* the thing that sets the wallpaper. The shell is started
// by hand rather than autostarted, so a wallpaper that only existed while
// quickshell ran would be a wallpaper that usually did not — the systemd unit
// in modules/home/hyprland/wallpaper-slideshow.nix owns the awww calls, and
// this object owns the config that unit reads:
//
//   ~/.config/quickshell/wallpaper.json   written here, read by the script
//   ~/.local/state/quickshell/wallpaper   written by the script, read here
//
// The second file is what closes the loop. The script writes the path it is
// about to display *before* it starts the transition, so the bar's palette
// begins its cross-fade alongside awww's rather than after it — see
// ../../theme/Palette.qml.
//
// Instantiated once at ShellRoot level and shared by every bar, so both
// screens' panels agree on the settings and the palette has one source.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")

    readonly property string configPath: root.configHome + "/quickshell/wallpaper.json"
    readonly property string statePath: root.stateHome + "/quickshell/wallpaper"

    // The unit that actually drives awww. Named here rather than spelled out
    // at each call site so the nix module and this file have one string
    // between them to keep in step.
    readonly property string unit: "wallpaper-slideshow.service"

    // The image currently on screen, absolute path. Empty until the script
    // has run once — the palette treats that as "no answer yet" and stays on
    // the static colours rather than flashing something derived from nothing.
    property string currentPath: ""

    // Shown under the controls. Empty means nothing to say.
    property string status: ""
    property bool failed: false

    // ── Settings ───────────────────────────────────────────────────────
    // Reached as `wallpaper.settings.mode` and so on. One object rather than
    // a proxy property per field: the adapter already gives every one of them
    // change notification, and re-declaring nine of them here would only add
    // a second place for a name to be wrong.
    readonly property alias settings: config

    // awww's transitions, minus the ones not worth offering. 'simple' ignores
    // --transition-duration entirely (it steps by rgb value instead), and the
    // directional four are all `wipe` with the angle pinned — so this is the
    // set where the duration slider means something and the choices differ
    // from each other.
    readonly property var transitions: ["fade", "wipe", "wave", "grow", "outer", "center", "random"]

    readonly property var transitionLabels: ({
            fade: "Fade",
            wipe: "Wipe",
            wave: "Wave",
            grow: "Grow",
            outer: "Collapse",
            center: "Iris",
            random: "Random"
        })

    function transitionLabel(name) {
        return root.transitionLabels[name] ?? name;
    }

    FileView {
        id: configFile

        path: root.configPath
        // The shell and the script both write nothing but whole files, but a
        // torn config would leave the slideshow with no directory to read.
        atomicWrites: true
        printErrors: false
        // Someone may edit the file by hand, and the script never writes it.
        watchChanges: true

        onFileChanged: configFile.reload()

        onSaveFailed: {
            root.failed = true;
            root.status = "Could not write " + root.configPath;
        }

        // Defaults are the ones the old hardcoded script used, so a machine
        // with no config file behaves exactly as it did before this section
        // existed.
        JsonAdapter {
            id: config

            // Off means the bar keeps the palette in ../../theme/Theme.qml.
            // Someone who has picked their own colours should not have them
            // silently overridden by whatever they set as a background.
            property bool dynamicColours: true

            // "single" | "slideshow"
            property string mode: "slideshow"

            property string image: ""
            property string directory: root.home + "/pictures/wallpaper/slideshow"

            property int intervalSeconds: 600
            property bool shuffle: true

            property string transition: "fade"
            property real transitionDuration: 1.5
            // Worth setting above 60: awww renders the transition itself, and
            // on a 144Hz panel the default 30 is visibly steppy.
            property int transitionFps: 120
        }
    }

    // ── What is on screen ──────────────────────────────────────────────
    FileView {
        id: currentFile

        path: root.statePath
        watchChanges: true
        printErrors: false

        onFileChanged: currentFile.reload()

        onLoaded: {
            const path = currentFile.text().trim();
            // Empty is ignored rather than stored. The script truncates this
            // file in place and writes it again, and inotify can fire between
            // the two — an empty read would send the palette all the way back
            // to the fixed colours and then all the way forward again, which
            // at a 700ms fade is a visible flinch every time the wallpaper
            // changes.
            if (path)
                root.currentPath = path;
        }

        // No state file yet means the slideshow has not run. Not an error,
        // and not something to report at a user.
        onLoadFailed: root.currentPath = ""
    }

    // A backstop, not the mechanism. The watch above is what makes a change
    // land immediately; this exists because a file watch is a thing that can
    // quietly stop working — a directory recreated under it, an inotify
    // budget exhausted — and the failure mode without it is a bar stuck on
    // the colours of a wallpaper that left the screen an hour ago.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: currentFile.reload()
    }

    // ── Applying ───────────────────────────────────────────────────────

    // Persist without disturbing what is on screen. For settings the script
    // does not read — currently just the colours toggle, which the bar acts
    // on directly.
    function persist() {
        configFile.writeAdapter();
    }

    // Persist and hand the change to the slideshow. Restarting the unit is
    // the whole apply path: the script re-reads the config on start and
    // displays straight away, so a new image or directory lands in about as
    // long as the transition takes.
    //
    // Debounced because the obvious way to drive a slider or a stepper is to
    // hold it, and each notch would otherwise restart the daemon.
    function apply() {
        configFile.writeAdapter();
        root.failed = false;
        root.status = "Applying…";
        restart.restart();
    }

    // Advance the slideshow now. SIGUSR1 rather than a restart, because a
    // restart would re-apply the *current* wallpaper before moving on: the
    // script waits on its interval in the background and a trapped signal cuts
    // that wait short, so this is one transition and not two.
    function skip() {
        if (config.mode !== "slideshow")
            return;
        root.failed = false;
        root.status = "";
        skipProcess.running = true;
    }

    Process {
        id: skipProcess

        // --kill-whom=main, not the default `all`: the script waits out its
        // interval on a backgrounded `sleep`, and USR1's default disposition
        // is to terminate. Signalling the whole cgroup would kill that sleep
        // directly instead of letting the script's trap decide, which happens
        // to produce the right result and for entirely the wrong reason.
        command: ["systemctl", "--user", "kill", "--kill-whom=main", "--signal=SIGUSR1", root.unit]

        stderr: StdioCollector {
            id: skipErrors
        }

        onExited: exitCode => {
            if (exitCode === 0)
                return;
            root.failed = true;
            root.status = skipErrors.text.trim() || ("systemctl exited " + exitCode);
        }
    }

    Timer {
        id: restart

        interval: 500
        onTriggered: restartProcess.running = true
    }

    Process {
        id: restartProcess

        command: ["systemctl", "--user", "restart", root.unit]

        stderr: StdioCollector {
            id: restartErrors
        }

        onExited: exitCode => {
            root.failed = exitCode !== 0;
            if (exitCode === 0)
                root.status = "Saved to " + root.configPath;
            else
                root.status = restartErrors.text.trim() || ("systemctl exited " + exitCode);
        }
    }
}
