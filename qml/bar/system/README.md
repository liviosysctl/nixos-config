# System

CPU and memory load, ported from waybar's `#cpu` and `#memory`.

| File | What it does |
| --- | --- |
| `Resources.qml` | Samples `/proc` (non-visual) |
| `ResourcesWidget.qml` | The two readouts |

Used from `../shell.qml`:

```qml
Resources { id: resourceState }                              // shared, once
...
ResourcesWidget { theme: barTheme; resources: resourceState } // per bar
```

`Resources` is shared, and here that matters more than usual. CPU load is a
*delta* between two reads of `/proc/stat`, so a second sampler would not merely
duplicate the work — it would interleave with the first and leave both
computing their deltas against the other's baseline.

Both readouts open `btop`, which is what waybar's `#memory` `on-click` does.
The terminal comes from `$TERMINAL` rather than being hardcoded — exported
from `vars.terminal` in `modules/home/default.nix`, which is the one definition
of "the terminal" on this machine.

## Reading /proc directly

No helper process and no polling of an external tool. Both numbers are two
small files and a subtraction, and spawning something every few seconds to ask
how busy the machine is has an obvious problem with it.

Quickshell's `FileView` reads `/proc` fine despite those files reporting a size
of zero.

### CPU

`/proc/stat` counts **cumulative jiffies since boot**, so a single read says
nothing about current load — it says what the average has been since the
machine came up. Usage is the change between two reads, which is why the object
keeps the previous sample and why the very first read produces no number.

Two details in the arithmetic:

- **`iowait` counts as idle.** It is time the CPU sat waiting on disk with
  nothing else to run. Counting it as busy makes a machine reading a large file
  look pinned.
- **`guest` and `guest_nice` are left out.** The kernel already counts them
  inside `user` and `nice`, so adding them double-counts a VM's load.

### Memory

`MemAvailable`, not `MemFree`. Free memory on Linux is near zero on any machine
that has been up a while, because the kernel fills it with cache it will hand
straight back when something asks. Reporting that as "in use" is the classic
way to make a healthy machine look like it is out of memory. `MemAvailable` is
the kernel's own estimate of what a fresh allocation could actually get, and it
is what waybar reports too.

## Timing

Polling is every 5s, inherited from waybar's `interval` back when the two bars
ran side by side and a disagreement between them would have been visible.

The first tick is early — 700ms — and only then settles to 5s. CPU needs two
samples before it can report anything, so at a flat 5s the bar would show 0%
for five seconds on every startup, which reads as a broken widget rather than
an idle machine.

## Width

Each readout reserves the width of the longest string it can ever hold
(`TextMetrics` on `" 100%"`) instead of hugging the current one. CPU load
moves constantly, and a readout that hugs it changes width on nearly every
sample — which shoves the island, and everything to the right of it, a few
pixels sideways twice a second.
