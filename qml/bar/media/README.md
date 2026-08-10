# Media player

The bar's media widget: a cava-style spectrum pill that expands into a card
with cover art and transport controls.

Used from `../shell.qml`, which imports this directory (`import "media"`) and
wires three things together:

```qml
Media  { id: mediaState; fallbackAccent: root.accent }        // shared, once
Cava   { id: cavaSource; active: mediaState.player?.isPlaying ?? false }
...
MediaWidget { theme: root; media: mediaState; cava: cavaSource }  // per bar
```

`Media` and `Cava` sit at `ShellRoot` level so every screen agrees on the
current player and cava runs once regardless of monitor count. `MediaWidget`
is per bar, which is what makes the card open only on the monitor you
clicked.

## Files

| File | What it does |
| --- | --- |
| `cava.conf` | cava in raw-ascii mode — 16 bars, 30 fps, pipewire input, one frame per line |
| `cava.sh` | Rewrites `cava.conf`'s source line and execs cava against the copy |
| `Cava.qml` | Runs the cava process, republishes each frame as 16 floats in `0..1` |
| `Spectrum.qml` | Draws a float array as gradient bars; used at both the pill and card sizes |
| `Media.qml` | Picks the active MPRIS player, derives an accent colour from its cover art |
| `MediaWidget.qml` | The bar pill and the `PopupWindow` that holds the card |
| `MediaCard.qml` | The expanded card: art, metadata, seek bar, transport |

## How it works

**Spectrum.** `Cava` spawns `cava -p cava.conf`, which writes one line per
frame (`12;40;7;…;`) to stdout. A `SplitParser` turns each line into an array
of 16 floats, and `Spectrum` draws them as bars.

Pausing resets the values to silence so the bars fall to their baseline
rather than freezing on the last frame. Two details make that work:

- Killing cava flushes whatever was still buffered in the pipe, and those
  frames arrive *after* the reset. `onRead` drops any frame that arrives
  while inactive, otherwise they overwrite the silence and the visualiser
  freezes on the last frame before the pause.
- The process is not killed immediately. cava polls the sink monitor
  continuously, but it only costs ~1% of a core, and a cold process needs
  about a second to connect to pipewire and let `autosens` settle — which
  reads as a dead visualiser followed by an overshoot. So it lingers through
  short pauses (`lingerMs`, 30s) and is released only once a pause turns out
  to be a long one. Resuming inside that window picks up instantly and at the
  right scale.

The bar count lives in **two** places: `bars` in `cava.conf` and `bars` in
`Cava.qml`. cava reads its own value from the config; the QML property only
mirrors it so renderers can size themselves before the first frame lands.
Change one without the other and the tail of every frame is dropped.

**What cava listens to.** Not the default sink's monitor — that carries every
sound the machine makes, so a Discord notification blip would jump the spectrum
in the middle of a track. `Media` resolves the pipewire node the chosen player
is actually feeding and `Cava` points at that instead.

Matching the two is fuzzier than it should be, because MPRIS and pipewire name
the same application differently and neither is authoritative: MPRIS has an
identity of `Supersonic` and a bus name ending `.Supersonic`, pipewire has a
node called `supersonic`. So both sides are normalised (lowercased, stripped to
alphanumerics) and compared for equality *or containment* — containment because
a browser reports an identity like `Mozilla zen` against a node named `zen`.
The bus-name tail is tried first, being what the application registered itself
as rather than free text.

cava takes its source from the config file and has no flag for it, so following
a player means writing a config and restarting. That is what `cava.sh` is for —
it rewrites the one line and execs cava, leaving `cava.conf` the source of
truth for everything else. `Cava` restarts through a `restarting` flag rather
than by writing `running` directly, because assigning to `running` would
destroy its binding and take the whole linger mechanism with it.

Two things worth knowing if this ever looks dead:

- **cava does not complain about a source it cannot find.** A name that matches
  nothing produces a steady stream of zeroes and exit code 0, exactly like a
  silent application. It is self-healing here only because `streamName` falls
  back to `auto` when no node matches.
- The node name is used rather than `object.serial`. cava reads the source once
  at startup, and a name survives the player tearing its stream down and
  opening a new one, where a serial does not.

**Player selection.** `Media` walks `Mpris.players` and picks whichever one
is playing. That choice is *assigned*, not bound, so it sticks: pausing does
not make the widget hop to whatever else happens to be registered, and a
browser tab chirping once cannot steal the card.

**Accent colour.** `ColorQuantizer` buckets the cover art down to eight
colours. `Media` takes the most saturated one and clamps it into a fixed
lightness/saturation band, so dark or greyscale covers can't produce an
invisible spectrum. With nothing usable it falls back to the bar's own
accent. Everything tinted — spectrum, progress fill, hover states, card
border — reads from that one property.

**The card.** A `PopupWindow` anchored under the pill. `grabFocus` lets the
compositor dismiss it on an outside click, which is why `popup.visible` is
the source of truth for expansion rather than a bool bound to it — the
dismiss path writes `visible` directly.

MPRIS does not push position updates, so the seek bar raises
`positionChanged()` on a timer to force a re-read, and only while the card is
open (`active`). Position therefore arrives in discrete 500ms jumps, so the
fill interpolates across exactly one poll interval — it lands on the next
sample just as it arrives, which turns the steps into a continuous crawl. The
hover handle is driven off the fill's width rather than off progress, so the
two cannot drift apart mid-slide.

## Interaction

| Where | Action |
| --- | --- |
| Pill | Left-click expands · middle-click play/pause · scroll changes track |
| Card | Click the progress bar to seek · <kbd>Esc</kbd> or click outside to close |

## Requirements

- `cava` on `PATH`. Provided by the bar app's `runtimeInputs` in
  `modules/home/qml.nix`; `qs-dev` gets it from the union of all apps' inputs.
- A player exposing MPRIS. With none registered the pill collapses to zero
  width and the bar closes up around it.

## Player support

Transport buttons follow what the player advertises, and disabled ones grey
out. Shuffle and loop are the usual gaps — both are optional in the MPRIS
spec and plenty of players skip them.

Worth knowing: **Supersonic advertises `Shuffle` but errors on both read and
write**, so quickshell reports `shuffleSupported: false` and the button stays
disabled. That is a player-side bug, not a widget one — verify with:

```sh
busctl --user get-property org.mpris.MediaPlayer2.Supersonic \
  /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Shuffle
```

`LoopStatus` works on the same player, so the loop button cycles normally
(off → playlist → track).

## Tweaking

- **Bar count / responsiveness** — `bars`, `framerate`, `noise_reduction` in
  `cava.conf` (and `bars` in `Cava.qml`, see above).
- **How long cava survives a pause** — `lingerMs` in `Cava.qml`. Set it to
  `0` to tear the process down immediately and trade the warm resume back for
  that ~1% of a core.
- **Pill size** — `barWidth` / `barSpacing` on the `Spectrum` in
  `MediaWidget.qml`.
- **Card size** — `implicitWidth` and `padding` on the root of
  `MediaCard.qml`. The card's spectrum uses fixed bar geometry on purpose:
  `implicitWidth` feeds the layout, so deriving spacing back from `width`
  would close a binding loop.
- **Colours** — all from `theme`, which `shell.qml` passes as its own root.
  There are no hardcoded colours here beyond `Media.fallbackAccent`.
