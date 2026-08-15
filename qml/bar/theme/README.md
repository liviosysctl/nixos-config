# Theme

Everything visual the widgets read — colours, the glass they are made of,
metrics, fonts — and the machinery that derives the colours from the wallpaper.

Used from `../shell.qml`, which builds two of each:

```qml
Palette { id: livePalette
          enabled: wallpaperState.settings.dynamicColours
          source: wallpaperState.currentPath }
Palette { id: basePalette; enabled: false }

Theme { id: barTheme;  palette: livePalette }
Theme { id: baseTheme; palette: basePalette }
```

Every widget takes one of these as `theme`. All of them get `barTheme` except
the media widget, which gets `baseTheme`.

| File | What it does |
| --- | --- |
| `Palette.qml` | Seven colours, either fixed or quantized out of the wallpaper |
| `Theme.qml` | Those plus the semantic three, the glass, the metrics and the fonts |
| `PulseText.qml` | A bar label that answers the pointer with colour and a glow |
| `Shine.qml` | An accent bloom marking the item whose panel is open |

## Why two of everything

The media widget already derives an accent from the current track's cover art
(`../media/Media.qml`). Putting a wallpaper-derived palette underneath it would
mean two unrelated generated colours in the same two hundred pixels — the
album's and the desktop's — with no relationship between them and no way for a
reader to tell which was which. That does not read as a theme, it reads as a
bug. So the media widget keeps the fixed palette and the rest of the bar
follows the wallpaper.

The island *around* it still tints, because that glass is shared with the audio
pills. Only the widget's own content is held out.

## How a wallpaper becomes a palette

`ColorQuantizer` buckets the image down to 2⁴ colours. One of those becomes the
seed, and everything else is built from its hue.

The seed is the most saturated bucket, **discounted for being very dark or very
light**:

```
score = saturation × (1 − |lightness − 0.5| × 1.2)
```

Straight "most saturated" picks the blown-out corner of a sky, or the one lit
pixel in a night shot. Both are technically the most saturated thing in the
image and both are useless as an accent, because there is no room left to move
their lightness into a legible band without losing the hue they were chosen
for.

From that one hue:

| | Hue | Saturation | Lightness |
| --- | --- | --- | --- |
| `accent` | seed | 0.45–0.8 | 0.66 |
| `hover` | seed + 0.06 | 0.55–0.9 | 0.80 |
| `fg` | seed | 0.22 | 0.88 |
| `dim` | seed | 0.14 | 0.62 |
| `bg` | seed | 0.22 | 0.085 |
| `bgAlt` | seed | 0.18 | 0.16 |

Everything hangs off one hue on purpose. A palette that takes a different
colour from the image for each role reads as a wallpaper smeared across a bar;
one hue with the variation in saturation and lightness reads as a theme. The
small hue nudge on `hover` is so it is distinguishable from the accent it sits
next to.

`accent`'s lightness floor is not cosmetic. It is used as a *fill* under
`bg`-coloured text — the focused workspace pill — and below about 0.6 the label
stops reading.

`bg` carries the hue at low saturation and very low lightness because the glass
fills are half-transparent over a compositor blur: they are seen mostly as a
tint on the wallpaper itself, so anything more saturated fights the thing
showing through it.

## The glass

`Theme` also carries what an island is made of: `surface` for the fill, and
`edgeTop`/`edgeSide`/`edgeBottom` for the one-pixel bevel `GlassSurface` in
`../shell.qml` draws around it. Two layers, matching the four `border-*`
colours the waybar CSS fakes a bevel with.

**The 0.5 alpha floor on `surface` is not a style choice**, and it binds
anything added here later. It is the `ignore_alpha` on the `qs-bar` layer in
`modules/home/hyprland/windowrules.nix`: anything the compositor sees below it
is left unblurred, so a fill that varies must vary in *lightness* and never dip
in alpha. Nothing here touches the compositor blur rules, and nothing here
should.

## The second accent

`accentAlt` exists for exactly one thing: the nix logo. waybar paints that
`#7ebae4`, a fixed brand colour, to set it apart from the row of white glyphs
next to it. Copying that here would leave it the single pill on the bar visibly
ignoring the wallpaper — so instead it gets a second accent out of the same
image.

The candidate is the most saturated bucket whose hue is **at least a twelfth of
the circle** away from the seed. Nearer than that and it does not read as a
different colour, it reads as the accent rendered slightly wrong. When the
wallpaper is genuinely one hue — a sunset, a forest — there is no such bucket,
and the fallback rotates the seed by 0.45: still derived, still unmistakably
not the accent.

It gets the same saturation clamp and the same lightness as `accent`, so the
two read as siblings from one palette rather than as one themed colour and one
stray.

Hues live on a circle, so anything comparing two of them goes through
`hueGap()` — 0.02 and 0.98 are neighbours, not opposites.

## Workspace switching

The focused workspace pill used to stretch, the way waybar's
`button.active { min-width: 40px }` does, and the stretch was animated.
Switching workspace moves `active` on *two* pills at once, so one grew while
the other shrank and the whole row slid sideways — every label landed somewhere
new for a change that concerned two of them.

Every pill is now one width, and each draws its own focus marker underneath its
label so the marker can be scaled independently of the text on top of it.

The two halves of a switch are deliberately **not** the same animation played
backwards:

| | duration | easing |
| --- | --- | --- |
| arriving | 300ms scale, 140ms opacity | `OutBack`, overshoot 2.2 |
| leaving | 200ms | `InQuad` |

Symmetric, it reads as one blob sliding along the row. Asymmetric, it reads as
somewhere being left and somewhere being arrived at. The overshoot belongs only
on the way in — on the way out it would look like the marker was trying to come
back.

`scale` is a render transform, so neither half disturbs the row's layout.

`Pill` itself no longer has an `active` property or any fill. Workspaces were
its only user, and the audio pair and clock are transparent in every state.

## Zoom

Every metric in `Theme.qml` is a base value times `zoom`, currently 1.4. The
base values are the sizes the bar was first drawn at and are left visible in
the arithmetic, so it stays obvious what zoom is doing to each one. Resizing
the bar is that one number.

It is called `zoom` and not `scale` deliberately: widgets read it from inside
an `Item`, where `scale` is a `QQuickItem` property that silently means
something else.

`controlSize`, `pillHeight`, `fontSize`, `smallFontSize` and `glyphSize` exist
so widgets stop hardcoding sizes. Before them there were four separate
`implicitWidth: 26`s that all had to be found and changed together for the bar
to resize without going lopsided.

**Popups and the settings window do not zoom.** They are already sized to be
read, and a 1.4× settings dialog is a worse settings dialog. Only bar chrome
and bar text scale.

## Hover

`PulseText` is waybar's `icon-pulse` keyframe, which is a `text-shadow` run
`forwards` on `:hover`:

```css
0%   { text-shadow: 0 0 0px alpha(@color4, 0);   }
50%  { text-shadow: 0 0 6px alpha(@color4, 0.3); }
100% { text-shadow: 0 0 3px alpha(@color4, 0.1); }
```

It overshoots and settles rather than fading in, which is most of why it reads
as a response to the pointer rather than as a state. `strength` is that curve
as one number: 0 at rest, 1 at the peak, 0.35 held.

This replaced the translucent white rectangle that every bar item used to grow
on hover. A filled background inside a pane of glass reads as a second, smaller
pane; a glow reads as the glyph noticing you. Fills now survive only where they
mean *state* — a focused workspace, an open card, an open tray menu.

Two items answer the pointer differently, for reasons rather than by omission.
Tray icons are third-party artwork in every possible colour, so no single glow
colour would read correctly against all of them; they lift instead. The media
spectrum is already coloured from the cover art, so its bars brighten rather
than sitting in a wash of their own accent.

## Open

`Shine` is the same argument one level along. Marking the item whose panel is
open used to be another translucent rectangle, and on a tray icon it read worst
of all — as a button stuck pressed in. It is now a soft accent bloom behind the
item: light spilling out from behind says "this one is showing you something"
without drawing a second shape.

It takes `theme.accent` by default.

**The media pill is the exception and does not bloom at all.** Its bars *are*
the widget, so pushing them towards a colour says "open" more directly than
lighting the empty space around them would. The colour they move towards is
`accentAlt` — the nix logo's — mixed in rather than replacing the track's own,
so the spectrum does not stop being the cover art's.

That colour has to be handed down from `shell.qml` as `openAccent`, because it
cannot be read off the widget's own `theme`: the media widget runs on the fixed
palette, and its `accentAlt` would be the static `#7ebae4` rather than the live
one the logo is actually wearing.

Two things about `RadialGradient` that are easy to get wrong, and both look
like the same bug:

- **`horizontalRadius` and `verticalRadius` must be set to half.** They default
  to the full `width` and `height`, so left alone the entire item sits inside
  the first half of the gradient and the bloom is chopped off square at the
  edges — a flat rectangle with hard sides, which is exactly what this exists
  to avoid.
- **The last stop is the accent at zero alpha, not `"transparent"`.** Qt's
  transparent is *black* with no alpha, so interpolating towards it drags the
  falloff through progressively darker colour and leaves a dirty ring around
  the bloom instead of a clean fade.

The glow needs room: it is drawn into the source item's own bounds, so without
padding it is cut off square at the edge of the glyph, which looks like a
rendering fault. `PulseText` pads the `Text` and takes the padding back off its
implicit size, so callers lay it out as though it were the bare label.

## What is not derived

`good`, `warn` and `bad` are fixed, on `Theme` rather than on `Palette`. They
mean "connected", "degraded" and "failed", and a wallpaper that turned the
battery warning teal would have made the bar prettier and less useful. Meaning
is not a thing to generate.

## Off is a state, not a bypass

`Palette` with `enabled: false` emits the fixed colours through the same six
properties. Nothing anywhere checks whether the feature is on and reads
somewhere else instead.

That is what makes turning it off in the settings panel cross-fade like every
other change rather than cutting. It is also why `basePalette` is a `Palette`
and not a second set of constants — there is one definition of the fixed
colours, in one file.

A greyscale wallpaper produces no seed, and `derived` goes false: inventing a
hue for it would be inventing a theme rather than deriving one.

## The fade

`Behavior on` each of the six, and nowhere else. Every glass fill, border,
hover state and text colour in the bar is derived from those six by binding, so
animating at the source moves all of them together for free.

`fadeDuration` is bound to the wallpaper's own transition length, clamped to
250–1600ms, so the bar and the desktop behind it are one movement. The clamp
matters at the top of the range: the transition setting reaches four seconds,
and a palette still sliding four seconds after the wallpaper has landed reads
as lag rather than as a fade.

The six are plain properties with a binding rather than `readonly` ones,
because a `Behavior` needs a property it can write.

## Gotchas

- **The quantizer is only pointed at a file when the result will be used.**
  With the feature off, `source` is empty. Quantizing a 4K image every time the
  slideshow ticks to throw the answer away is not free.
- **webp needs `qt6.qtimageformats`** on `QT_PLUGIN_PATH`, which
  `lib/quickshell.nix` puts there. Without it a webp wallpaper loads as
  nothing: no error, just a `ColorQuantizer` with no colours in it, and the
  palette silently stays fixed.
- **An empty `currentPath` is "no answer yet", not "no colours".** The
  slideshow has not run. The fixed palette is the right thing to show while
  waiting, rather than something derived from a half-loaded image.
