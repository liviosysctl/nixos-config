# Wallpaper

The Wallpaper section: what is on screen, where the next one comes from, how it
gets there, and whether the bar takes its colours from it.

| File | What it does |
| --- | --- |
| `Wallpaper.qml` | The settings, and the current wallpaper's path (non-visual) |
| `WallpaperPage.qml` | The page |
| `PathBrowser.qml` | Picking an image, or the folder a slideshow reads |

## What owns what

This section does **not** set the wallpaper. It writes a config file, and a
systemd unit reads it:

```
        ~/.config/quickshell/wallpaper.json
   panel ──────────────── writes ─────────────▶ wallpaper-slideshow.service
                                                          │
                                                          │ awww img
                                                          ▼
        ~/.local/state/quickshell/wallpaper            the screen
   panel ◀──────────────── reads ──────────────┘
```

The unit is `modules/home/hyprland/wallpaper-slideshow.nix`.

**Why not drive awww from here**, which would make the whole state file
unnecessary: the shell is started by hand, not autostarted. A wallpaper that
only existed while quickshell ran would be a wallpaper that usually did not.

**Applying is a `systemctl --user restart`.** The script re-reads its config on
start and displays immediately, so a new image lands in about as long as the
transition takes — and the two sides never have to agree on an IPC, only on the
shape of a JSON file. It is debounced by 500ms, because the obvious way to
drive a slider is to hold it and every notch would otherwise restart the
daemon.

**"Next wallpaper" is SIGUSR1**, not a restart. A restart would re-display the
current image before moving on: two transitions where one was asked for. It
goes to `--kill-whom=main` rather than the default `all` — the script waits out
its interval on a backgrounded `sleep`, and USR1's default disposition is to
terminate, so signalling the whole cgroup would kill that sleep directly
instead of letting the script's trap decide. That happens to produce the right
result, for entirely the wrong reason.

**The colours toggle does not restart anything.** The bar reads it directly and
the script has no opinion about it, so that one control calls `persist()` and
the rest call `apply()`.

## The state file, and why the bar reads it

`../../theme/Palette.qml` quantizes whatever path is in that file. The script
writes it **before** starting the transition rather than after, so the bar's
cross-fade and awww's transition are the same movement rather than one chasing
the other.

Two details of that file are load-bearing:

- **It is truncated in place, never renamed over.** The reader watches the path
  with inotify, and a rename swaps the inode out from under the watch — one
  wallpaper change and the bar would stop hearing about any of them.
- **An empty read is ignored, not stored.** Truncate-then-write is two
  operations and inotify can fire between them. Storing the empty string would
  send the palette all the way back to the fixed colours and all the way
  forward again — at a 700ms fade, a visible flinch on every change.

There is also a 30s reload timer. That is a backstop and not the mechanism: a
file watch is a thing that can quietly stop working, and the failure mode
without it is a bar stuck on the colours of a wallpaper that left the screen an
hour ago.

## Everything applies as you set it

The opposite of the Displays page, for the opposite reason. A wrong monitor
mode can leave a screen you cannot see well enough to fix, so those edits stay
a draft until Apply. A wrong wallpaper is one you can see perfectly and change
again in a click — drafting it would only put a button between someone and the
thing they are trying to look at. There is no Apply here and no Revert.

## The browser

`FolderListModel` from `Qt.labs.folderlistmodel`, which ships with
qtdeclarative. Shelling out to a portal chooser would drag a GTK dialog into
the middle of a panel that draws all of its own chrome, and would look it.

Images get thumbnails rather than a generic glyph, because scrolling a
directory of wallpapers by filename is guesswork. They are decoded at
`sourceSize` and not full size — a folder of 4K wallpapers would otherwise put
a few hundred megabytes through the scene graph on a scroll.

Directory mode still lists the images. Seeing what is in a folder is most of
how you tell whether it is the folder you meant.

The extension filter is kept in step with the script's own `find` expression. A
directory whose images this browser shows but the slideshow skips would be a
confusing thing to hand someone.

## awww, and what else there is

`awww` is `swww` under nixpkgs' new name — same project, same 0.12.1. It stays,
and not for want of looking:

| | Transitions |
| --- | --- |
| **awww / swww** | type, duration, frame rate and a bezier curve, per call |
| hyprpaper | none — it cuts |
| swaybg | none |
| wpaperd | a fade, with no control over it |
| mpvpaper | it is a video player |

There is nothing better to move to. The improvement available was in using what
it already offers rather than replacing it, and the old script was leaving most
of that on the table:

- **`simple` → `fade`.** `simple` *ignores `--transition-duration` entirely* —
  it steps by rgb value per frame instead, so the `--transition-duration 1` the
  old script passed alongside it did nothing at all.
- **A tuned bezier.** awww's default `.54,0,.34,.99` accelerates late and
  finishes abruptly, which is what makes the stock transition read as a wipe
  even when it is a fade. The script uses `.4,0,.2,1`.
- **Frame rate matched to the panel.** awww renders the transition on the CPU
  and defaults to 30fps, which is visibly steppy above 60Hz. The setting
  reaches 240.
- **`Lanczos3` over `CatmullRom`.** awww names both as reasonable for
  photographic content and picks Lanczos3 as its own default, so the old
  script's `CatmullRom` was a choice being made without a reason behind it.
  This just stops overriding the default.

The transition list offered in the page is deliberately not all of awww's:
`simple` is excluded for the reason above, and `left`/`right`/`top`/`bottom`
are all `wipe` with the angle pinned. What is left is the set where the
duration slider means something and the choices differ from each other.

## Gotchas

- **`FileView` creates parent directories.** `~/.config/quickshell/` does not
  need to exist first; the first `writeAdapter()` makes it.
- **jq's `//` cannot be used to default a boolean.** `false // fallback` takes
  the fallback, which would make `"shuffle": false` unsettable. The script uses
  `has($k)` instead.
- **The script re-scans the directory every tick**, so dropping a file in does
  not need a restart. Which is why it tracks the current wallpaper by path
  rather than by index — an index into a list that just changed length means
  nothing.
