# Session

Two of waybar's modules, ported: the idle inhibitor and the button that opens
wlogout.

| File | What it does |
| --- | --- |
| `Idle.qml` | Holds the idle lock (non-visual) |
| `IdleWidget.qml` | The  pill — waybar's `#idle_inhibitor` |
| `PowerWidget.qml` | The  pill — waybar's `#custom-startmenu` |

Used from `../shell.qml`:

```qml
Idle { id: idleState }                            // shared, once
...
IdleWidget  { theme: barTheme; idle: idleState }  // per bar
PowerWidget { theme: barTheme }                   // per bar
```

`Idle` is shared because an idle inhibitor is a property of the session, not of
a monitor. One per screen would mean the button on one output disagreeing with
the button on the other about whether the machine is allowed to sleep.

## The inhibitor

waybar attaches a `zwp_idle_inhibitor_v1` to its own surface. Quickshell
exposes no way to do that, so this takes a **logind** inhibitor instead, via
`systemd-inhibit --what=idle --mode=block`.

That works because hypridle honours all three kinds of inhibit — dbus, systemd
and wayland — unless told otherwise, and
`modules/home/hyprland/hypridle.nix` leaves `general:ignore_systemd_inhibit` at
its default of false. `--mode=block` is the part that matters: it sets logind's
`BlockInhibited` property, which is what hypridle reads. `--mode=delay` would
only defer sleep and would not touch idling at all.

You can watch it work:

```console
$ busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager BlockInhibited
s "idle"
```

## Why the payload is `cat`

`systemd-inhibit` holds the lock for exactly as long as the command it is given
runs, so the payload's only job is to stay alive — and, far more importantly,
to stop being alive the moment the shell does.

The obvious payload is `sleep infinity`. **Do not use it.** Quickshell does not
reap this process on exit: kill the bar and `systemd-inhibit` is reparented to
init, still holding an idle lock that nothing on the system now has a handle
on. The session cannot idle again until someone goes looking for the pid. That
is not hypothetical — it is what the first version of this file did, and it was
caught by killing the bar and finding `BlockInhibited` still set to `"idle"`.

`cat` with `stdinEnabled: true` fixes it structurally. Quickshell owns the write
end of a pipe on the child's stdin; whatever takes the shell down — a clean
quit, SIGTERM, SIGKILL, a segfault — the kernel closes that end, `cat` reads
EOF and exits, `systemd-inhibit` sees its command finish and releases the lock.
It depends on fd teardown rather than on any cleanup code running, which is the
only kind of cleanup a crash cannot skip. Verified against `kill -9`.

## `inhibited` vs `held`

`inhibited` is the request and is what the button binds to, so the pill
responds to the click rather than to a subprocess finishing its exec. `held`
is `lock.running` — whether a lock is genuinely up.

They differ for the few milliseconds it takes to spawn, and they would differ
permanently if `systemd-inhibit` were missing. That case is handled by resetting
`inhibited` on a non-zero exit, so the button falls back to off instead of
sitting there claiming to hold something it does not.

## Glyphs

The idle inhibitor uses the **same glyph in both states** and moves only the
colour. That is what the waybar config does too, and deliberately:
`format-icons` names  for `activated` and `deactivated` alike, and
`#idle_inhibitor.activated` turns it `@color2`. A cup of coffee already says
"staying up"; a second picture would make the two states harder to tell apart
at a glance than one colour change does.

Green beats hover, matching waybar's cascade — `.activated` is declared after
`:hover`, so a lit inhibitor stays green under the pointer instead of flicking
back to the hover colour and reading as though the click had missed.

The nix logo is the one thing on the bar meant *not* to match, and it wears
`accentAlt` to do it — a second accent quantized out of the same wallpaper,
picked for being far enough round the hue circle from the first to read as a
different colour. waybar gets the same effect by hardcoding `#7ebae4`, which
here would have left it the single pill visibly ignoring the wallpaper. See
`../theme/README.md`.

It also turns on hover, like the settings gear. **120°, not the gear's 60°**:
the snowflake is three-fold symmetric, so 120° lands it back on itself. Any
other angle settles visibly crooked — which a gear does not suffer, having far
more teeth than three.

It sits at the far left, in a pane of its own, which is where waybar puts
`#custom-startmenu` in `modules-left`. It is the only control on the bar that
leaves the session, so it is not welded to anything that does not.

## Hover

Neither pill grows a background on hover any more. The colour moves and a very
slight glow rises and settles behind the glyph — waybar's `icon-pulse`, via
`../theme/PulseText.qml`.

The idle inhibitor's glow follows its *held* colour, not the hover colour:
hovering a lit inhibitor would otherwise throw a pink halo around a green
glyph.

## Gotchas

- **wlogout is launched with `Quickshell.execDetached`**, not a `Process`. It
  outlives the click, has no output worth collecting, and tying a modal session
  menu's lifetime to the bar would take it down with a shell reload.
- **Nerd Font codepoints do not survive every editor.** Both glyphs here landed
  as empty strings once already — the pills rendered, at zero width, with no
  error anywhere. If a glyph vanishes, check the file's actual codepoints
  before looking at anything else.
