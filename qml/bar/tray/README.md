# Tray

The bar's system tray: one icon per background app that has registered a
StatusNotifierItem, plus the app's own right-click menu.

Used from `../shell.qml`, which imports this directory (`import "tray"`) and
drops it into the right-hand island:

```qml
TrayWidget { theme: root }
```

Nothing here is shared across screens, unlike `media/`. Each bar gets its own
`TrayWidget`, so a menu opens on the monitor you clicked.

## Files

| File | What it does |
| --- | --- |
| `TrayWidget.qml` | The icon row, hover pills, tooltip, and the menu popup |
| `TrayMenu.qml` | Renders a `QsMenuHandle` as a glass sheet; opens submenus beside their row |

## How it works

**Icons.** `SystemTray.items` is a live model of every registered item, so the
`Repeater` rebuilds whenever an app starts or exits. Icons are drawn with
`IconImage` rather than plain `Image` — it is quickshell's icon-shaped
specialisation, and it requests the size it will actually draw at instead of
scaling whatever it is handed. Items reporting `NeedsAttention` get a dot in
the corner; nothing else in the tray is coloured.

**Menus.** DBusMenu is lazy: an item advertises `hasMenu`, but the layout
itself only arrives once someone asks. `QsMenuOpener` is what asks — binding
its `menu` to a handle is what triggers the `AboutToShow` and populates
`children`.

`TrayMenu` renders one level of that. Entries with `hasChildren` are
themselves handles, so a submenu is another `TrayMenu` pointed at the entry —
which is why the file loads *itself* through a `Loader` with a
`source: "TrayMenu.qml"`. QML treats a component naming itself as a cycle and
refuses to load it at all; by URL it is fine. `Loader.active` also does the
cleanup, tearing a submenu down when it closes so none of them can outlive the
menu they hang off.

Which submenu is open is one `openIndex` on the sheet rather than a flag per
row, so opening a second one closes the first for free.

**Dismissal.** Activating any entry at any depth raises `dismissed`, which
each nested sheet forwards up to its parent, and `TrayWidget` turns into
`menuPopup.visible = false`. The whole chain goes down together instead of
leaving parents stranded on screen.

`grabFocus` is what lets the compositor dismiss the menu on an outside click.
Worth knowing when testing: a grabbing popup needs a real input event behind
it, so opening one from a `Timer` gets the grab rejected and the popup never
appears. That is a Wayland rule, not a bug in the widget.

**Re-anchoring.** Both popups lower `visible` before moving `anchor.item`.
Moving a popup that is already up leaves it stranded at the old position.

## Interaction

Matching waybar's `#tray`, plus the menu:

| Action | Result |
| --- | --- |
| Left-click | `activate()` — usually shows or hides the app window |
| Middle-click | `secondaryActivate()` |
| Right-click | The app's menu |
| Scroll | Passed through as `scroll()`, raw `angleDelta` |
| Hover (500ms) | Tooltip, from `tooltipTitle` falling back to `title` |

Items that set `onlyMenu` advertise no activate action at all, so a left click
opens their menu instead — there is nothing else it could usefully do.

## Tweaking

- **Icon size** — `implicitSize` on the `IconImage` in `TrayWidget.qml`.
  waybar asks for 20; 18 leaves the hover pill a visible margin at this bar
  height.
- **Tooltip delay** — `interval` on the `dwell` timer.
- **Menu width** — the `implicitWidth` clamp at the top of `TrayMenu.qml`.
  Tray menus range from a lone "Quit" to a full account list, so it sizes to
  the widest label between 180 and 380.
- **Colours** — all from `theme`, which `shell.qml` passes as its own root.
  There are no hardcoded colours here.

## Menu support

Check and radio entries render their state, disabled entries grey out, and
separators become hairlines. Entry text is shown exactly as the app sends it —
apps that still put GTK mnemonic underscores in their labels (`_Quit`) will
show them, because stripping underscores would also mangle the labels that
legitimately contain one.
