import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

// Shared bluetooth state: the adapter, its devices in a stable order, and the
// two actions the service does not expose. One instance feeds every bar.
Scope {
    id: root

    // True while a card is open. Gates discovery, which is the only
    // expensive thing here.
    property bool active: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: root.adapter !== null
    readonly property bool enabled: root.adapter?.enabled ?? false
    readonly property bool discovering: root.adapter?.discovering ?? false

    // Connected first, then paired, then whatever discovery turned up.
    // Alphabetical within each group so pills do not swap places on refresh —
    // a ring of moving targets is unusable.
    readonly property var devices: {
        const list = (root.adapter?.devices?.values ?? []).slice();
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return root.deviceLabel(a).localeCompare(root.deviceLabel(b));
        });
        return list;
    }

    readonly property var connectedDevices: root.devices.filter(device => device.connected)

    function deviceLabel(device) {
        return device.deviceName || device.name || device.address;
    }

    // ── Presentation ───────────────────────────────────────────────────

    readonly property string glyph: {
        if (!root.present || !root.enabled)
            return "󰂲";
        if (root.connectedDevices.length > 0)
            return "󰂱";
        return "󰂯";
    }

    // BlueZ reports a freedesktop icon name; map the ones that matter onto
    // the same Nerd Font set the rest of the bar uses.
    function deviceGlyph(device) {
        const icon = (device.icon ?? "").toLowerCase();
        const name = root.deviceLabel(device).toLowerCase();
        const says = fragment => icon.includes(fragment) || name.includes(fragment);

        if (says("headset") || says("headphone") || says("buds") || says("pods"))
            return "󰋋";
        if (says("speaker") || icon.includes("audio"))
            return "󰓃";
        if (says("mouse"))
            return "󰍽";
        if (says("keyboard"))
            return "󰌌";
        if (says("gaming") || says("controller") || says("gamepad"))
            return "󰊴";
        if (says("phone"))
            return "󰄡";
        if (says("tv") || says("television") || says("video") || says("qled") || says("oled"))
            return "󰔂";
        if (says("display") || says("monitor"))
            return "󰍹";
        if (says("car") || says("auto"))
            return "󰄋";
        if (says("watch"))
            return "󰖉";
        if (says("tablet"))
            return "󰓷";
        if (says("computer") || says("laptop"))
            return "󰌢";
        if (says("printer"))
            return "󰐪";
        return "󰂯";
    }

    // What clicking the device's pill will do.
    function primaryAction(device) {
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (device.pairing)
            return "Pairing…";
        if (device.connected)
            return "Disconnect";
        if (device.paired || device.bonded)
            return "Connect";
        return "Pair";
    }

    function busy(device) {
        return device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }

    // Connect and disconnect are writable properties; pairing is not, so it
    // goes out to bluetoothctl.
    function activate(device) {
        if (root.busy(device))
            return;
        if (device.connected)
            device.connected = false;
        else if (device.paired || device.bonded)
            device.connected = true;
        else
            root.pair(device);
    }

    // ── Actions the service does not expose ────────────────────────────

    readonly property string scriptPath: Qt.resolvedUrl("btctl.sh").toString().replace("file://", "")

    // Surfaced on the card so a failed pair says something instead of
    // silently doing nothing.
    property string status: ""

    function pair(device) {
        root.status = `Pairing ${root.deviceLabel(device)}…`;
        btctl.exec(["bash", root.scriptPath, "pair", device.address]);
    }

    function forget(device) {
        root.status = `Removed ${root.deviceLabel(device)}`;
        btctl.exec(["bash", root.scriptPath, "forget", device.address]);
    }

    Process {
        id: btctl

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                root.status = text.trim().split("\n").pop()
        }

        onExited: function (exitCode) {
            if (exitCode === 0)
                root.status = "";
        }
    }

    // discovering lives on the adapter object, which appears asynchronously,
    // and BlueZ rejects it while the adapter is powered down.
    //
    // Three handlers feed this, and the writes are D-Bus calls that take a
    // moment to land — so it latches what was asked for rather than
    // re-reading `discovering`, which still reads false while the first
    // StartDiscovery is in flight and earns an "Operation already in
    // progress" for the second.
    property bool discoveryRequested: false

    function syncDiscovery() {
        if (!root.adapter || !root.adapter.enabled) {
            root.discoveryRequested = false;
            return;
        }
        if (root.discoveryRequested === root.active)
            return;
        root.discoveryRequested = root.active;
        root.adapter.discovering = root.active;
    }

    onActiveChanged: root.syncDiscovery()
    onAdapterChanged: root.syncDiscovery()
    onEnabledChanged: root.syncDiscovery()
}
