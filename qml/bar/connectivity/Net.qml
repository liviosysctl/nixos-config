import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Shared networking state: which device is actually carrying traffic, the
// glyph that represents it, and the IPv4 details quickshell's service does
// not expose. One instance feeds every bar.
Scope {
    id: root

    // True while a card is open. Gates the two things that are only worth
    // doing when somebody is looking: scanning for access points, and
    // shelling out for address details.
    property bool active: false

    readonly property var devices: Networking.devices.values

    // The service connects to NetworkManager asynchronously and reports an
    // empty device list until it does. Without this the bar would show a
    // "disconnected" icon for the first few seconds of every session.
    readonly property bool ready: root.devices.length > 0

    readonly property var wifiDevice: root.devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: root.devices.find(device => device.type === DeviceType.Wired) ?? null

    // Wired wins when it is up: NetworkManager routes over it by preference,
    // so it is the connection actually carrying traffic.
    readonly property var primary: (root.wiredDevice?.connected ?? false) ? root.wiredDevice : ((root.wifiDevice?.connected ?? false) ? root.wifiDevice : null)

    readonly property bool online: root.primary !== null
    readonly property bool wired: root.online && root.primary.type === DeviceType.Wired

    readonly property var activeWifi: {
        for (const network of (root.wifiDevice?.networks?.values ?? [])) {
            if (network.connected)
                return network;
        }
        return null;
    }

    // Access points: connected first, then saved, then the rest by name.
    //
    // Deliberately not sorted by signal. Strength jitters constantly, and
    // this list drives positions on the orbit — sorting by it would have the
    // pills trading places under the cursor. It would also rebuild the array
    // on every RSSI update, churning the delegates. Strength still decides
    // each pill's glyph; it just does not decide where the pill sits.
    readonly property var wifiNetworks: {
        const networks = (root.wifiDevice?.networks?.values ?? []).slice();
        networks.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return networks;
    }

    // ── Presentation ───────────────────────────────────────────────────

    // Same five-step ramp the waybar config uses, so the two bars agree on
    // what a given signal looks like.
    function wifiGlyph(strength) {
        if (strength >= 0.8)
            return "󰤨";
        if (strength >= 0.6)
            return "󰤥";
        if (strength >= 0.4)
            return "󰤢";
        if (strength >= 0.2)
            return "󰤟";
        return "󰤯";
    }

    readonly property string glyph: {
        if (root.wired)
            return "󰈀";
        if (root.activeWifi)
            return root.wifiGlyph(root.activeWifi.signalStrength);
        if (!Networking.wifiEnabled)
            return "󰤮";
        return "󰤩";
    }

    // What the primary connection is called: the SSID on wifi, the interface
    // name on wired.
    readonly property string label: {
        if (root.wired)
            return root.primary.name;
        return root.activeWifi?.name ?? "Disconnected";
    }

    function connectivityLabel(value) {
        switch (value) {
        case NetworkConnectivity.Full:
            return "Online";
        case NetworkConnectivity.Portal:
            return "Portal";
        case NetworkConnectivity.Limited:
            return "Limited";
        case NetworkConnectivity.None:
            return "No route";
        default:
            return "Unknown";
        }
    }

    function securityLabel(value) {
        switch (value) {
        case WifiSecurityType.Open:
            return "Open";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Sae:
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3";
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap:
            return "WPA";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "";
        }
    }

    // Enterprise and WEP need more than a passphrase, so the card sends
    // those to an external manager instead of pretending it can handle them.
    function needsPassphrase(security) {
        return [WifiSecurityType.Sae, WifiSecurityType.Wpa2Psk, WifiSecurityType.WpaPsk, WifiSecurityType.Wpa3SuiteB192].indexOf(security) !== -1;
    }

    function isOpen(security) {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Owe;
    }

    // ── Address details ────────────────────────────────────────────────

    // Keyed by interface name: { ip: "192.168.0.51/24", gateway: "..." }.
    property var addresses: ({})

    // Tunnels that are up: [{ interface, name, ip }].
    //
    // Deliberately not derived from `primary`: a VPN is machine-wide, and the
    // tunnel is usually not a NetworkManager device at all — tailscale brings
    // up its own tun, so it never appears in Networking.devices. netinfo.sh
    // reads the interface list, which is the one place every kind shows up.
    property var vpns: []

    readonly property bool vpnActive: root.vpns.length > 0

    // One tunnel is the normal case and deserves its name. Several at once is
    // rare enough that a count says more than a truncated list would.
    readonly property string vpnLabel: {
        if (root.vpns.length === 0)
            return "";
        if (root.vpns.length === 1)
            return root.vpns[0].name;
        return `${root.vpns.length} tunnels`;
    }

    readonly property string scriptPath: Qt.resolvedUrl("netinfo.sh").toString().replace("file://", "")

    function primaryAddress() {
        return root.primary ? (root.addresses[root.primary.name]?.ip ?? "") : "";
    }

    function primaryGateway() {
        return root.primary ? (root.addresses[root.primary.name]?.gateway ?? "") : "";
    }

    Process {
        id: netinfo

        command: ["bash", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text);
                    root.addresses = info.interfaces ?? {};
                    root.vpns = info.vpn ?? [];
                } catch (error) {
                    root.addresses = {};
                    root.vpns = [];
                }
            }
        }
    }

    // Addresses change on DHCP renewal and on every connect, and a tunnel can
    // come up or drop at any time — none of which the service signals, so
    // poll, but only while a card is open.
    Timer {
        interval: 5000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!netinfo.running)
            netinfo.running = true
    }

    // scannerEnabled lives on the device object, which appears asynchronously
    // after the service connects, so it is applied rather than bound.
    function syncScanner() {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = root.active;
    }

    onActiveChanged: root.syncScanner()
    onWifiDeviceChanged: root.syncScanner()
}
