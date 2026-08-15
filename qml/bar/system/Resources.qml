import Quickshell
import Quickshell.Io
import QtQuick

// CPU and memory load, read straight out of /proc.
//
// No helper process and no polling of an external tool: both numbers are two
// small files and a subtraction, and spawning something every few seconds to
// tell us how busy the machine is has an obvious problem with it.
//
// Instantiated once at ShellRoot level and shared by every bar. The load is a
// property of the machine, and sampling it once per monitor would mean two
// readings that disagree — and, because CPU is a *delta* between samples, two
// readings that each corrupt the other's baseline.
Scope {
    id: root

    // Percentages, 0–100.
    property int cpu: 0
    property int memory: 0

    // waybar polls both of these every 5s. Matching it keeps the two bars
    // from disagreeing while they are still running side by side.
    property int interval: 5000

    // ── CPU ────────────────────────────────────────────────────────────
    // /proc/stat counts *cumulative jiffies since boot*, so a single read
    // says nothing about current load — it says what the average has been
    // since the machine came up. Usage is the change between two reads, which
    // is why this keeps the previous sample and why the first read produces
    // no number at all.
    property real lastTotal: 0
    property real lastIdle: 0
    property int samples: 0

    function readCpu(text) {
        // The aggregate line is first: "cpu  user nice system idle iowait …"
        const line = text.split("\n")[0];
        if (!line.startsWith("cpu "))
            return;

        const fields = line.trim().split(/\s+/).slice(1).map(Number);
        if (fields.length < 5)
            return;

        // idle + iowait. iowait is time the CPU sat waiting on disk with
        // nothing else to run, which is idle by any definition a bar cares
        // about — counting it as busy makes a machine reading a large file
        // look pinned.
        const idle = fields[3] + fields[4];

        // user, nice, system, idle, iowait, irq, softirq, steal. `guest` and
        // `guest_nice` are deliberately left out: they are already counted
        // inside user and nice, so adding them double-counts a VM's load.
        let total = 0;
        for (let i = 0; i < Math.min(8, fields.length); i++)
            total += fields[i];

        const totalDelta = total - root.lastTotal;
        const idleDelta = idle - root.lastIdle;

        if (root.samples > 0 && totalDelta > 0)
            root.cpu = Math.round(Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100)));

        root.lastTotal = total;
        root.lastIdle = idle;
        root.samples += 1;
    }

    // ── Memory ─────────────────────────────────────────────────────────
    function readMemory(text) {
        const total = Number(text.match(/^MemTotal:\s+(\d+)/m)?.[1] ?? 0);
        if (total <= 0)
            return;

        // MemAvailable, not MemFree. Free memory on Linux is close to zero on
        // any machine that has been up a while, because the kernel fills it
        // with cache it will hand back the moment anything asks. Reporting
        // that as "in use" is the classic way to make a healthy machine look
        // like it is out of memory. MemAvailable is the kernel's own estimate
        // of what a new allocation could actually get.
        const available = Number(text.match(/^MemAvailable:\s+(\d+)/m)?.[1] ?? NaN);
        // Pre-3.14 kernels have no MemAvailable. Nothing here runs on one, but
        // falling back beats showing 100%.
        const usable = isFinite(available) ? available : Number(text.match(/^MemFree:\s+(\d+)/m)?.[1] ?? 0);

        root.memory = Math.round(Math.max(0, Math.min(100, (1 - usable / total) * 100)));
    }

    function sample() {
        cpuFile.reload();
        memFile.reload();
    }

    FileView {
        id: cpuFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: root.readCpu(cpuFile.text())
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.readMemory(memFile.text())
    }

    Component.onCompleted: root.sample()

    Timer {
        // The first tick comes early and the rest settle to `interval`. CPU
        // needs two samples before it can report anything, so at a flat 5s the
        // bar would show 0% for five seconds on every startup — which looks
        // like a broken widget rather than an idle machine.
        interval: root.samples < 2 ? 700 : root.interval
        running: true
        repeat: true
        onTriggered: root.sample()
    }
}
