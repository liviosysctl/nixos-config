# Settings

The bar's  button, and the panel it opens: a centred glass window over a
dimmed backdrop, with a sidebar of sections.

Used from `../shell.qml`, which imports this directory and each section's
folder, then wires one shared state object per section plus one widget per
bar:

```qml
Displays  { id: displayState }     // shared, once
Wallpaper { id: wallpaperState }   // shared, once
...
SettingsWidget {                   // per bar
    theme: barTheme
    displays: displayState
    wallpaper: wallpaperState
}
```

The state objects sit at `ShellRoot` level so both screens' panels agree on
what has been edited and what has been applied — and, for `Wallpaper`, so
there is one watcher on the state file rather than one per output.
`SettingsWidget` is per bar, which is what makes the panel open on the monitor
whose button you clicked.

## Layout

```
settings/
├── SettingsWidget.qml    the bar pill, and the overlay it owns
├── SettingsWindow.qml    backdrop, window chrome, sidebar, section routing
├── common/               controls every section draws with
├── displays/             the Displays section
└── wallpaper/            the Wallpaper section — see its own README
```

One folder per section, because a section is never one file: it is a page, a
non-visual state object, usually a helper or two, and sometimes a script. Flat,
those interleave with the shared controls and with each other, and the only way
to tell `MonitorDraft.qml` from `NumberField.qml` is to open both.

| File | What it does |
| --- | --- |
| `SettingsWidget.qml` | The  pill in the bar, and the overlay it owns |
| `SettingsWindow.qml` | The overlay: backdrop, window chrome, sidebar, page routing |
| `common/Select.qml` | Glass dropdown |
| `common/Toggle.qml` | Glass switch |
| `common/Slider.qml` | Glass slider — reports on drag and on release separately |
| `common/NumberField.qml` | Integer field, for X/Y positions |
| `common/Button.qml` | Glass push button |
| `displays/DisplaysPage.qml` | The page: layout canvas on top, selected output's settings below |
| `displays/MonitorCanvas.qml` | Outputs drawn to scale — click to select, drag to arrange |
| `displays/MonitorDraft.qml` | One output's live state and pending edits (non-visual) |
| `displays/Displays.qml` | Reads monitors, applies changes, rewrites `monitors.lua` |
| `displays/vrrcap.sh` | Which outputs can do adaptive sync, as `{"DP-2":true}` |
| `wallpaper/*` | See `wallpaper/README.md` |

## Adding a section

One entry in `SettingsWindow.sections`, and nothing else:

```qml
{ id: "network", label: "Network", glyph: "󰤨", page: networkSection }
```

…where `networkSection` is a `Component` declared alongside the others in that
file. The sidebar, the routing and the fallback-to-first all read from that one
list, and the page rides along in it as a `Component` rather than living in a
branch of the content `Loader`. It used to be an entry *and* a branch, which is
exactly the kind of pair that drifts — the sidebar grows a row that routes
nowhere and the panel goes blank.

The `Loader` is inactive while the panel is closed and re-created when the
section changes, so a page cannot keep polling behind a window nobody is
looking at.

## Where draft state lives

On `MonitorDraft`, one per output, created by an `Instantiator` — **not** on the
delegates that draw the controls. The page shows one output's settings at a
time, so a draft living on a visual delegate would be thrown away every time
you clicked a different monitor.

That also fixes the dirty check. `Instantiator` hands out `objectAt()` rather
than a property, and a binding cannot depend on a function call, so
`draftList` is rebuilt on add/remove and `anyDirty` recomputes from it whenever
`revision` moves. Each draft bumps `revision` when its own dirty flag flips.
Recomputing rather than counting is deliberate: a counter drifts the moment an
add and a remove interleave, and a stuck counter means an Apply button that
lies.

## The canvas

Everything on it is in **logical** pixels, which is the space Hyprland lays
outputs out in and the space `position` is written in. A 3840×2160 panel at
scale 1.5 occupies a 2560×1440 slot, and that slot is what its neighbours butt
against — drawing raw resolutions instead would show two displays overlapping
that in fact sit side by side.

Dragging snaps: each axis independently looks for a neighbour's near or far
edge, or an aligned near/far edge, within `snapDistance`. That threshold is
expressed in logical pixels but divided by the view factor, so it stays roughly
a constant distance under the pointer whatever the layout spans.

Positions are also **clamped**, which matters more than it sounds. However many
outputs there are, an arrangement never usefully spans more than all of them
laid end to end, so that is the envelope: an output may reach one full span
left of the others' right edge, or one full span right of their left edge, and
no further. Without it a drag can fling a monitor into empty space, and since
the view scales to fit the bounding box, everything else collapses to an
unclickable dot in the corner. The limit grows with the number of monitors,
which is the behaviour you want — two displays get a smaller envelope than
four.

`place()` is the only way a position changes: it clamps, then snaps. The typed
X/Y fields go through it too, so they cannot escape bounds a drag respects.
Dragging gets you flush, typing gets you exact.

A lone output is pinned to the origin — there is nothing to position it
relative to, and Hyprland normalises the layout anyway.

## How monitor changes are applied

Two things have to happen, and `Displays.apply()` does both because either
alone is a silent no-op:

1. **`hyprctl eval`** applies to the running compositor. Note *eval*, not
   `keyword` — this config drives Hyprland's lua parser, and `keyword` answers
   `keyword can't work with non-legacy parsers. Use eval.` eval takes the same
   `hl.*()` calls the config is written in, and several statements at once.
2. **Rewriting `~/.config/hypr/monitors.lua`** is what survives a reload. The
   generated `hyprland.lua` loads that file — see the `extraConfig` block in
   `modules/home/hyprland/default.nix`.

   That block uses `dofile`, not `require`, and it matters: Hyprland reuses a
   single Lua state across `hyprctl reload`, so `require` finds `monitors` in
   `package.loaded` and returns without re-reading the file. Every reload after
   the first would silently keep the layout from session start, however many
   times this panel had rewritten it since. `package.loaded["monitors"]` was
   `true` and `package.path` had the hypr dir in it twice, which is how that
   was pinned down.

The file is written whole, never patched: it is generated output, and
half-updating it is how you get two rules for one output. `atomicWrites` is on
because a torn write costs the session its display config.

**Applying is not trusted.** `hyprctl eval` returns `ok` for a mode Hyprland
will not actually drive — it accepts the rule and quietly ignores it, and only
a lua *syntax* error comes back as an error. So `apply()` waits, calls
`Hyprland.refreshMonitors()`, and compares what the outputs are really doing
against what was asked for. Anything that did not take is named in the status
line.

**VRR is the exception, and is reported separately.** Hyprland reads a monitor
rule's `vrr` when it brings the output up and not afterwards: setting the rule
on a running session is accepted, reports `ok`, and changes nothing. That was
confirmed down at the DRM level — `VRR_ENABLED` on the CRTC stays 0. The global
`misc:vrr` *does* apply live, but flipping that would drag every other output
along with it, which defeats the point of a per-monitor toggle. So the file is
written correctly and the status line says the session catches up the next time
Hyprland starts. Treating that as a failure would be wrong; the setting is
right, it is just a restart away.

Nothing is applied as you pick it. A wrong mode can leave a screen dark, and a
panel that has already committed the change is one you cannot see well enough
to undo — so edits stay a draft until Apply, and Revert throws them away.

## What the page offers

**Resolution and refresh rate** are split into two selectors, because
`availableModes` is a flat list of `3840x2160@144.00Hz` strings with heavy
duplication — 32 entries covering rather fewer real modes here. Pick a
resolution, then pick from the rates that resolution actually supports.

**Scale** is filtered against the chosen resolution. Hyprland refuses a scale
that does not divide the mode into whole logical pixels, so offering the full
list would mostly be offering errors.

**VRR** is written into the per-monitor rule rather than the global
`misc:vrr`, so one display can run adaptive while another stays fixed. It is
Hyprland's three values rather than a switch:

| Shown | `vrr` | Meaning |
| --- | --- | --- |
| Off | 0 | Fixed refresh rate |
| Fullscreen only | 2 | Adaptive only for a fullscreen window |
| Always | 1 | Adaptive on the desktop too |

Three rather than two because "always on" is *not* the free win it looks like.
A desktop is mostly static content with occasional small repaints, which is
exactly the workload that makes a panel's refresh rate swing over a wide range
— and on plenty of panels, VA ones especially, that swing shows up as visible
brightness flicker. Hyprland ships `cursor:no_break_fs_vrr` specifically
because pointer movement drags a fullscreen window out of its VRR window, which
is a fair sign of how much friction there is between adaptive sync and a
compositor. Mode 2 is what most desktops actually want: the benefit lands where
it matters, and the desktop keeps a steady rate.

Only **Always** disables the refresh-rate selector, and that is deliberate.
With it on there is no fixed rate left to choose — the display swings up to the
mode's ceiling, so the draft writes that ceiling (`rates` is sorted descending,
so index 0). Under **Fullscreen only** the desktop still runs at a rate you
picked, so the selector stays live.

One asymmetry worth knowing: `hyprctl monitors -j` reports `vrr` as a plain
bool, so a session running in fullscreen-only mode reads back as "Always" after
a resync. The file keeps the distinction; the IPC cannot express it.

The toggle is only offered on displays that can actually do it. Hyprland
reports whether VRR is *on* and never whether it *could* be, so `vrrcap.sh`
answers that separately, and `SettingsWindow` runs it each time the panel
opens — it costs about 60ms, and running it on the way in means unplugging a
monitor between two visits cannot leave the page describing one that is gone.

The answer is the DRM connector property `vrr_capable`, which the driver fills
in from the display's own capabilities. Getting at it takes some work:

- It is **not in sysfs**. A connector directory carries `connector_id`,
  `status`, `edid` and `modes`, and nothing else useful — reading the property
  table needs libdrm, hence `drm_info`.
- `drm_info` reports connectors by **numeric id**, not as `DP-3`. The join
  back to a name is `/sys/class/drm/card*-*/connector_id`, which is why the
  script reads both.
- Writeback connectors report `connected` but carry no `vrr_capable`, so they
  are filtered out rather than reported as incapable.

A missing answer means *unknown*, not *incapable*: some drivers never expose
the property, and `drm_info` is not always able to open the card. Those
outputs are left out of the object and the page leaves their toggle live —
refusing a setting that would have worked is worse than offering one Hyprland
then declines, which the post-apply check catches anyway. The same reasoning
covers the script's `{}` fallback when `drm_info` is missing entirely.

`drm_info` needs `/dev/dri/card*`, which is `root:video` — so this depends on
the user being in the `video` group.

**Position** is carried straight over from what Hyprland reports. There is no
arrange canvas, so an output keeps the top-left it already had — which means a
resolution change can leave a gap or an overlap between outputs that only
`hyprctl` or a rewrite of `monitors.lua` will close.

## Ownership of monitors.lua

This panel owns the file. It used to be nwg-displays, which wrote
`monitors.conf` alongside for its own read-back; that second file is no longer
seeded. nwg-displays still runs, but it and the panel now overwrite each other
rather than sharing state — pick one.

## Blur

The frosting is Hyprland's own `decoration:blur`, switched on for the
`qs-settings` layer by `frostedLayer` in
`modules/home/hyprland/windowrules.nix` — the same `blur on` +
`ignore_alpha 0.5` every translucent surface here runs. There is no QML blur
effect here, and no threshold of this panel's own.

Only the panel frosts; the desktop behind it is dimmed but stays sharp,
because the two surfaces the overlay draws fall on opposite sides of that one
threshold:

| Surface | Alpha the compositor sees | Result |
| --- | --- | --- |
| backdrop alone | 0.45 | below 0.5 — dims, no blur |
| panel over backdrop | 0.85 | above it — blurred |

The panel fill is `cardSurface` at 0.72, but it is drawn *over* the backdrop,
so the composited alpha there is `0.72 + 0.45 × 0.28`. Doing it this way costs
nothing at render time — the compositor was already blurring the layer.

## Gotchas

- **A grabbing popup needs a real input event behind it.** `keyboardFocus:
  Exclusive` is only set while the panel is open, and opening the panel from a
  timer rather than a click can get the grab refused. Same rule that bites the
  tray menu — see `../tray/README.md`.
- **`mapToItem` is a function, not a binding.** `Select` places its list once,
  on the way open, rather than binding the position: a bound `mapToItem` is
  evaluated during startup and then never again, leaving every list wherever
  its field happened to be before the layout settled.
- **Dropdown lists draw into `popupLayer`**, an Item covering the whole window
  that `SettingsWindow` keeps as its last child. A list nested in the page's
  layout would be clipped by the `Flickable` and would shove the rows below it
  down. It is called `popupLayer` and not `layer` because `QQuickItem.layer`
  is a final property — shadowing it breaks at runtime.

## Tweaking

- **Panel size** — `width`/`height` of `frame` in `SettingsWindow.qml`. Capped
  so it does not sprawl on a 4K output, bounded so it still fits a small one.
- **Backdrop dimming** — the backdrop `Rectangle`'s alpha. Keep it under 0.5:
  past the blur threshold the whole desktop starts frosting, and that
  threshold is shared by every frosted layer, so it is not this panel's to
  move.
- **Scale choices** — `scaleChoices` in `displays/Displays.qml`.
- **Colours** — all from `theme`, which is the live `Theme` object `shell.qml`
  hands down. That means the panel follows the wallpaper along with the rest of
  the bar; see `../theme/README.md`.
