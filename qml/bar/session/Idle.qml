import Quickshell
import Quickshell.Io
import QtQuick

// Holds an idle inhibitor for as long as it is asked to, so a film or a long
// build is not interrupted by hypridle dimming the screen and then locking it.
//
// Instantiated once at ShellRoot level and shared by every bar: the inhibitor
// is a property of the session, not of a monitor, and one per screen would
// mean the button on one output disagreeing with the button on the other.
Scope {
    id: root

    // What the widget binds to. Not derived from the process, so the button
    // responds to the click rather than to a subprocess starting — but see
    // `held` below for what actually reports the truth.
    property bool inhibited: false

    // Whether the lock is genuinely up. `inhibited` is the request; this is
    // the state. They differ for the few milliseconds it takes to spawn, and
    // they differ permanently if systemd-inhibit is missing — in which case
    // the button must not sit there claiming to be holding something.
    readonly property bool held: lock.running

    function toggle() {
        root.inhibited = !root.inhibited;
    }

    // ── The lock ───────────────────────────────────────────────────────
    // A logind inhibitor rather than the wayland idle-inhibit protocol
    // waybar uses, because quickshell exposes no way to attach one to a
    // surface. hypridle honours all three of dbus, systemd and wayland
    // inhibits unless told otherwise (`general:ignore_systemd_inhibit`,
    // which modules/home/hyprland/hypridle.nix leaves at its default), and
    // the logind one is the only one reachable from here.
    //
    // `--mode=block` is what sets logind's BlockInhibited property, which is
    // the property hypridle actually reads. `--mode=delay` would only defer
    // sleep and would not touch idling at all.
    //
    // `systemd-inhibit` holds the lock for exactly as long as the command it
    // is given runs, so the payload's only job is to stay alive — and, much
    // more importantly, to *stop* being alive the moment this shell does.
    //
    // Hence `cat` reading a pipe, and not `sleep infinity`. Quickshell does
    // not reap this on exit: kill the bar with `sleep infinity` as the
    // payload and systemd-inhibit is reparented to init, still holding an
    // idle lock that nothing on the system now has a handle on. The session
    // cannot idle again until someone finds the pid. That was not a
    // hypothetical — it is what the first version of this file did.
    //
    // With `stdinEnabled`, quickshell owns the write end of a pipe on the
    // child's stdin. Whatever takes this process down — a clean quit, a
    // SIGTERM, a SIGKILL, a segfault — the kernel closes that end, `cat`
    // reads EOF and exits, systemd-inhibit sees its command finish and
    // releases the lock. It relies on fd teardown rather than on any cleanup
    // code running, which is the only kind of cleanup a crash cannot skip.
    Process {
        id: lock

        running: root.inhibited
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Idle inhibitor held from the bar", "--mode=block", "cat"]

        // Nothing sensible to do with the output, and letting it collect
        // would be holding a buffer open for however many hours this runs.
        onExited: exitCode => {
            // A non-zero exit while we still want the lock means it could not
            // be taken — systemd-inhibit missing, or logind refusing. Drop the
            // request so the button goes back to off instead of showing a
            // state nothing is backing.
            if (root.inhibited && exitCode !== 0)
                root.inhibited = false;
        }
    }
}
