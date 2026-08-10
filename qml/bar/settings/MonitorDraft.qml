import QtQuick

// Everything the page knows about one output: what Hyprland reports, and what
// the user has changed but not yet applied.
//
// Non-visual on purpose. The page shows one monitor's controls at a time, so
// draft state cannot live on the delegate that draws them — switching
// selection would throw the edits away. An Instantiator makes one of these per
// output and keeps it for as long as the output exists.
QtObject {
    id: draft

    // A HyprlandMonitor, and the Displays scope holding the shared helpers.
    property var monitor: null
    property var displays: null

    // ── What Hyprland reports ──────────────────────────────────────────
    readonly property var ipc: draft.monitor?.lastIpcObject ?? ({})
    readonly property string name: draft.monitor?.name ?? ""
    readonly property string description: (draft.ipc.description ?? "").replace(/\s+\S+$/, "")

    readonly property var rateTable: draft.displays ? draft.displays.ratesByResolution(draft.ipc.availableModes) : ({})
    readonly property var resolutions: draft.displays ? draft.displays.resolutionsOf(draft.rateTable) : []

    readonly property string liveResolution: `${draft.monitor?.width ?? 0}x${draft.monitor?.height ?? 0}`
    readonly property real liveRate: draft.ipc.refreshRate ?? 0
    readonly property real liveScale: draft.monitor?.scale ?? 1
    readonly property bool liveVrr: draft.ipc.vrr ?? false
    readonly property int liveX: draft.monitor?.x ?? 0
    readonly property int liveY: draft.monitor?.y ?? 0

    readonly property bool vrrSupported: draft.displays ? draft.displays.vrrSupported(draft.name) : true

    // One string to hang the resync off: any of it moving means Hyprland
    // changed the output under us and the draft is stale.
    readonly property string signature: `${draft.liveResolution}@${draft.liveRate}@${draft.liveScale}@${draft.liveVrr}@${draft.liveX},${draft.liveY}`

    // ── The draft ──────────────────────────────────────────────────────
    property int resolutionIndex: 0
    property int rateIndex: 0
    property int scaleIndex: 0
    property int x: 0
    property int y: 0

    // Hyprland's own values, not a bool: 0 off, 2 fullscreen only, 1 always.
    // Ordered that way in the UI because that is the order of increasing
    // consequence, and 2 is the setting most desktops actually want — see the
    // note in the README.
    readonly property var vrrModes: [
        {
            value: 0,
            label: "Off"
        },
        {
            value: 2,
            label: "Fullscreen only"
        },
        {
            value: 1,
            label: "Always"
        }
    ]

    property int vrrIndex: 0

    readonly property int vrr: draft.vrrModes[draft.vrrIndex]?.value ?? 0
    readonly property int liveVrrValue: draft.liveVrr ? 1 : 0

    readonly property var rates: draft.rateTable[draft.resolutions[draft.resolutionIndex]] ?? []
    readonly property var scales: draft.displays && draft.resolutions.length > 0 ? draft.displays.scalesFor(draft.resolutions[draft.resolutionIndex]) : []

    readonly property string resolution: draft.resolutions[draft.resolutionIndex] ?? draft.liveResolution
    readonly property real scale: draft.scales[draft.scaleIndex] ?? draft.liveScale

    // Only "Always" takes the choice away: the display then swings freely and
    // the mode's rate is just the ceiling, so the draft writes that ceiling —
    // `rates` is sorted descending, so it is index 0. Under "Fullscreen only"
    // the desktop still runs at a rate you picked, so the selector stays live.
    readonly property bool rateFixed: draft.vrr !== 1
    readonly property real rate: draft.rateFixed ? (draft.rates[draft.rateIndex] ?? draft.liveRate) : (draft.rates[0] ?? draft.liveRate)

    // Hyprland lays outputs out in logical pixels, which is what the canvas
    // draws and what `position` means — a 3840x2160 panel at 1.5 occupies a
    // 2560x1440 slot.
    readonly property int logicalWidth: Math.round(Number(draft.resolution.split("x")[0]) / draft.scale)
    readonly property int logicalHeight: Math.round(Number(draft.resolution.split("x")[1]) / draft.scale)

    readonly property bool dirty: draft.resolution !== draft.liveResolution || Math.abs(draft.rate - draft.liveRate) > 0.05 || Math.abs(draft.scale - draft.liveScale) > 0.001 || draft.vrr !== draft.liveVrrValue || draft.x !== draft.liveX || draft.y !== draft.liveY

    function entry() {
        return {
            output: draft.name,
            mode: draft.displays.modeString(draft.resolution, draft.rate),
            position: `${draft.x}x${draft.y}`,
            scale: draft.scale,
            vrr: draft.vrr
        };
    }

    function resync() {
        const index = Math.max(0, draft.resolutions.indexOf(draft.liveResolution));
        draft.resolutionIndex = index;
        draft.rateIndex = draft.displays.nearestRate(draft.rateTable[draft.resolutions[index]] ?? [], draft.liveRate);

        const scales = draft.resolutions.length > 0 ? draft.displays.scalesFor(draft.resolutions[index]) : [];
        let best = 0;
        for (let i = 1; i < scales.length; i++) {
            if (Math.abs(scales[i] - draft.liveScale) < Math.abs(scales[best] - draft.liveScale))
                best = i;
        }
        draft.scaleIndex = best;

        // Hyprland reports vrr as a plain bool, so a session running in
        // fullscreen-only mode reads back as "Always". There is nothing finer
        // to resync from; the file keeps the distinction.
        const mode = draft.vrrModes.findIndex(candidate => candidate.value === draft.liveVrrValue);
        draft.vrrIndex = Math.max(0, mode);

        draft.x = draft.liveX;
        draft.y = draft.liveY;
    }

    // Rebuilt whenever the output itself changes, and once on creation.
    property Connections watch: Connections {
        target: draft
        function onSignatureChanged() {
            draft.resync();
        }

        // The capability answer arrives from a script and can land after the
        // draft is built. A display that turns out not to support VRR must not
        // keep a draft that would ask for it.
        function onVrrSupportedChanged() {
            if (!draft.vrrSupported)
                draft.vrrIndex = 0;
        }
    }

    Component.onCompleted: draft.resync()
}
