import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// One panel for everything that connects: wired, Wi-Fi and bluetooth share a
// single orbit, and the tabs along the bottom swap which one it is showing.
//
// After the layout in ilyamiro's config, minus the animated lines running
// from each node back to the core — the ring is legible without them.
Item {
    id: card

    required property var theme
    required property var net
    required property var bt

    property bool active: true

    // "eth" | "wifi" | "bt"
    property string mode: "wifi"

    readonly property color accent: card.theme.accent
    readonly property int padding: 14

    // Wi-Fi only: the network waiting on a passphrase. While this is set the
    // core turns into the input, which is where the original put it too.
    property var pending: null
    property string failure: ""

    implicitWidth: 660
    implicitHeight: 560

    readonly property bool hasWired: card.net.wiredDevice !== null

    function modeAvailable(name) {
        if (name === "eth")
            return card.hasWired;
        if (name === "bt")
            return card.bt.present;
        return card.net.wifiDevice !== null;
    }

    // Whatever the current tab puts on the ring. Wired has nothing to pick
    // between, so it orbits its own connection details instead.
    readonly property var nodes: {
        if (card.mode === "bt")
            return card.bt.devices;
        if (card.mode === "wifi")
            return card.net.wifiNetworks;

        const device = card.net.wiredDevice;
        if (!device)
            return [];
        const address = card.net.addresses[device.name] ?? {};
        const facts = [
            {
                glyph: "󰩠",
                // Without the prefix length: the pill is too narrow for
                // "192.168.0.51/24" and the subtitle already says what it is.
                title: (address.ip ?? "").split("/")[0] || "No address",
                subtitle: "Address"
            },
            {
                glyph: "󰑩",
                title: address.gateway ?? "None",
                subtitle: "Gateway"
            },
            {
                glyph: "󰓅",
                title: device.linkSpeed >= 1000 ? `${device.linkSpeed / 1000} Gbps` : `${device.linkSpeed} Mbps`,
                subtitle: "Link"
            },
            {
                glyph: "󰾰",
                title: device.address,
                subtitle: "MAC"
            }
        ];
        return facts;
    }

    readonly property int shownCount: orbit.capacity(Math.min(card.nodes.length, 20))
    readonly property int overflow: card.nodes.length - card.shownCount
    readonly property real pillScale: orbit.fit(card.shownCount)

    // ── Per-mode presentation ──────────────────────────────────────────

    function nodeGlyph(node) {
        if (card.mode === "bt")
            return card.bt.deviceGlyph(node);
        if (card.mode === "wifi")
            return card.net.wifiGlyph(node.signalStrength);
        return node.glyph;
    }

    function nodeTitle(node) {
        if (card.mode === "bt")
            return card.bt.deviceLabel(node);
        if (card.mode === "wifi")
            return node.name;
        return node.title;
    }

    function nodeSubtitle(node) {
        if (card.mode === "bt") {
            const action = card.bt.primaryAction(node);
            if (node.connected && node.batteryAvailable)
                return `${Math.round(node.battery * 100)}%  ·  ${action}`;
            return action;
        }
        if (card.mode === "wifi") {
            if (node.stateChanging)
                return "…";
            if (node.connected)
                return "Connected";
            if (node.known)
                return "Saved";
            return card.net.securityLabel(node.security);
        }
        return node.subtitle;
    }

    function nodeActive(node) {
        return card.mode === "eth" ? false : node.connected;
    }

    // Left click.
    function activate(node) {
        card.failure = "";
        if (card.mode === "bt") {
            card.bt.activate(node);
        } else if (card.mode === "wifi") {
            if (node.connected)
                node.disconnect();
            else if (node.known || card.net.isOpen(node.security))
                node.connect();
            else if (card.net.needsPassphrase(node.security))
                card.pending = node;
            else
                card.failure = "This network needs a profile — use Advanced.";
        }
    }

    // Right click.
    function forget(node) {
        if (card.mode === "bt") {
            if (node.paired || node.bonded)
                card.bt.forget(node);
        } else if (card.mode === "wifi" && node.known) {
            node.forget();
        }
    }

    function submitPassphrase(text) {
        if (!card.pending || text.length === 0)
            return;
        card.pending.connectWithPsk(text);
        card.pending = null;
    }

    // Failures arrive asynchronously; bound here so it survives whatever the
    // ring is doing.
    Connections {
        target: card.mode === "wifi" ? card.pending : null

        function onConnectionFailed(reason) {
            card.failure = "Failed: " + ConnectionFailReason.toString(reason);
        }
    }

    onModeChanged: card.pending = null

    // No automatic fallback here on purpose. Both services report nothing for
    // the first seconds after start, so anything that "corrects" an
    // unavailable mode during that window lands on whichever service happened
    // to answer first — which had this opening on Bluetooth while a perfectly
    // good Wi-Fi device was still being enumerated. The widget picks the mode
    // when it opens the panel, by which point the services have answered, and
    // tabs for things that do not exist stay hidden.

    component Tab: Rectangle {
        id: tab

        property string glyph
        property string label
        property string target

        readonly property bool current: card.mode === tab.target

        visible: card.modeAvailable(tab.target)
        implicitWidth: tabRow.implicitWidth + 22
        implicitHeight: 28
        radius: 8
        color: tab.current ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.28) : (tabHover.containsMouse ? Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.12) : Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.06))

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            id: tabRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                text: tab.glyph
                font.family: card.theme.fontFamily
                font.pixelSize: 13
                color: tab.current ? card.accent : card.theme.fg
            }

            Text {
                text: tab.label
                font.family: card.theme.fontFamily
                font.pixelSize: 11
                font.bold: tab.current
                color: tab.current ? card.accent : card.theme.fg
            }
        }

        MouseArea {
            id: tabHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.mode = tab.target
        }
    }

    // ── Surface ────────────────────────────────────────────────────────
    // The same glass construction the bar islands use: a gradient rectangle
    // standing in for the lit edge, with the fill inset one pixel inside it,
    // because Rectangle only carries a single border colour.
    Rectangle {
        anchors.fill: parent
        radius: 16

        gradient: Gradient {
            GradientStop {
                position: 0
                color: card.theme.edgeTop
            }

            GradientStop {
                position: 0.5
                color: card.theme.edgeSide
            }

            GradientStop {
                position: 1
                color: card.theme.edgeBottom
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 15
            color: card.theme.cardSurface
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 0

        Orbit {
            id: orbit

            Layout.fillWidth: true
            Layout.fillHeight: true

            count: card.shownCount

            // Decorative rings.
            Repeater {
                model: 3

                delegate: Rectangle {
                    required property int index

                    readonly property real span: (index + 1) / 3

                    width: orbit.radiusX * 2 * span
                    height: orbit.radiusY * 2 * span
                    x: orbit.centreX - width / 2
                    y: orbit.centreY - height / 2
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, card.scanning ? 0.2 : 0.09)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 300
                        }
                    }

                    SequentialAnimation on scale {
                        running: card.scanning
                        loops: Animation.Infinite

                        PauseAnimation {
                            duration: index * 320
                        }

                        NumberAnimation {
                            to: 1.03
                            duration: 900
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 900
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            // ── Core ───────────────────────────────────────────────────
            Rectangle {
                id: core

                width: orbit.coreRadius * 2
                height: width
                x: orbit.centreX - width / 2
                y: orbit.centreY - height / 2
                radius: width / 2
                color: card.powered ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, coreHover.containsMouse && card.canToggle ? 0.3 : 0.2) : Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, coreHover.containsMouse && card.canToggle ? 0.14 : 0.08)
                border.width: 1
                border.color: card.powered ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.5) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    visible: card.pending === null

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: card.coreGlyph
                        font.family: card.theme.fontFamily
                        font.pixelSize: 32
                        color: card.powered ? card.accent : card.theme.dim

                        SequentialAnimation on opacity {
                            running: card.scanning
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.45
                                duration: 850
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 1
                                duration: 850
                                easing.type: Easing.InOutSine
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: core.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        text: card.coreLabel
                        font.family: card.theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: card.powered ? card.theme.fg : card.theme.dim
                        elide: Text.ElideRight
                    }
                }

                // Passphrase entry, in place of the core's label.
                ColumnLayout {
                    anchors.centerIn: parent
                    width: core.width - 16
                    spacing: 4
                    visible: card.pending !== null

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: card.pending?.name ?? ""
                        font.family: card.theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: card.theme.fg
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(card.theme.bg.r, card.theme.bg.g, card.theme.bg.b, 0.85)

                        TextInput {
                            id: passphrase

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            font.family: card.theme.fontFamily
                            font.pixelSize: 11
                            color: card.theme.fg
                            echoMode: TextInput.Password
                            selectByMouse: true
                            selectionColor: card.accent
                            clip: true

                            onAccepted: card.submitPassphrase(text)
                            Keys.onEscapePressed: card.pending = null

                            Text {
                                anchors.centerIn: parent
                                text: "passphrase"
                                font.family: card.theme.fontFamily
                                font.pixelSize: 10
                                color: card.theme.dim
                                visible: passphrase.text.length === 0
                            }
                        }
                    }
                }

                // The field only exists while pending is set, so focus it
                // once it has actually been created.
                onVisibleChanged: if (!visible)
                    card.pending = null

                MouseArea {
                    id: coreHover

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: card.canToggle && card.pending === null
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.togglePower()
                }
            }

            // ── Pills ──────────────────────────────────────────────────
            Repeater {
                model: card.shownCount

                delegate: Rectangle {
                    id: pill

                    required property int index

                    readonly property var node: card.nodes[pill.index] ?? null
                    readonly property var placement: orbit.centreOf(pill.index, card.shownCount)
                    readonly property bool interactive: card.mode !== "eth"

                    width: orbit.pillWidth * card.pillScale
                    height: orbit.pillHeight * card.pillScale
                    x: orbit.centreX + placement.x - width / 2
                    y: orbit.centreY + placement.y - height / 2
                    radius: 10 * card.pillScale
                    visible: pill.node !== null
                    color: pillHover.containsMouse && pill.interactive ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.26) : Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.08)
                    border.width: 1
                    border.color: pill.node && card.nodeActive(pill.node) ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.7) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9 * card.pillScale
                        anchors.rightMargin: 9 * card.pillScale
                        spacing: 7 * card.pillScale

                        Text {
                            text: pill.node ? card.nodeGlyph(pill.node) : ""
                            font.family: card.theme.fontFamily
                            font.pixelSize: 15 * card.pillScale
                            color: pill.node && card.nodeActive(pill.node) ? card.accent : card.theme.fg
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: pill.node ? card.nodeTitle(pill.node) : ""
                                font.family: card.theme.fontFamily
                                font.pixelSize: 11 * card.pillScale
                                font.bold: true
                                color: card.theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: pill.node ? card.nodeSubtitle(pill.node) : ""
                                font.family: card.theme.fontFamily
                                font.pixelSize: 9 * card.pillScale
                                color: pill.node && card.nodeActive(pill.node) ? card.accent : card.theme.dim
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: pillHover

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: pill.interactive
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: function (mouse) {
                            if (!pill.node)
                                return;
                            if (mouse.button === Qt.RightButton)
                                card.forget(pill.node);
                            else
                                card.activate(pill.node);
                        }
                    }
                }
            }

            // Empty states, so a bare ring is never left unexplained.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: core.bottom
                anchors.topMargin: 22
                width: parent.width - 80
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: card.emptyText
                font.family: card.theme.fontFamily
                font.pixelSize: 10
                color: card.theme.dim
                visible: text !== "" && card.pending === null
            }

            // ── VPN ────────────────────────────────────────────────────
            // A tunnel is machine-wide rather than a property of whichever
            // tab you are on, so it does not belong on the ring or in the
            // core. The corner is the one place a pill never reaches: pills
            // are centred on the ellipse, so the extreme corner stays clear
            // at every count and scale the solver produces.
            //
            // Declared last so it draws over the ring, and outside the
            // ColumnLayout's flow so it cannot shrink the orbit — the ring's
            // capacity is tuned against the current height.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top

                // Nothing to say on the bluetooth tab, where it would read as
                // a claim about the adapter.
                visible: card.net.vpnActive && card.mode !== "bt"

                implicitWidth: vpnRow.implicitWidth + 18
                implicitHeight: 26
                radius: 8
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.35)

                RowLayout {
                    id: vpnRow

                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰖂"
                        font.family: card.theme.fontFamily
                        font.pixelSize: 13
                        color: card.accent
                    }

                    Text {
                        Layout.maximumWidth: 160
                        text: card.net.vpnLabel
                        font.family: card.theme.fontFamily
                        font.pixelSize: 11
                        color: card.accent
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            implicitHeight: 1
            color: Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.1)
        }

        // ── Tabs ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Tab {
                glyph: "󰈀"
                label: "Ethernet"
                target: "eth"
            }

            Tab {
                glyph: "󰤨"
                label: "Wi-Fi"
                target: "wifi"
            }

            Tab {
                glyph: "󰂯"
                label: "Bluetooth"
                target: "bt"
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: card.hint
                font.family: card.theme.fontFamily
                font.pixelSize: 9
                color: card.failure !== "" ? "#f7768e" : card.theme.dim
                elide: Text.ElideRight
            }

            Rectangle {
                id: advanced

                implicitWidth: advancedLabel.implicitWidth + 20
                implicitHeight: 28
                radius: 8
                color: advancedHover.containsMouse ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.22) : Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.06)

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    id: advancedLabel

                    anchors.centerIn: parent
                    text: "󰒓  Advanced"
                    font.family: card.theme.fontFamily
                    font.pixelSize: 11
                    color: card.theme.fg
                }

                MouseArea {
                    id: advancedHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // The same managers the waybar modules open, so both bars
                    // land in the same place for whatever this panel does not
                    // cover: enterprise auth, static addressing, PIN pairing.
                    onClicked: Quickshell.execDetached(card.mode === "bt" ? ["blueman-manager"] : ["kitty", "--class", "gazelle-network", "gazelle"])
                }
            }
        }
    }

    // ── Mode-dependent core state ──────────────────────────────────────

    readonly property bool powered: {
        if (card.mode === "bt")
            return card.bt.enabled;
        if (card.mode === "wifi")
            return Networking.wifiEnabled;
        return card.net.wiredDevice?.connected ?? false;
    }

    // Wired has no switch — it is up or it is not.
    readonly property bool canToggle: card.mode !== "eth" && (card.mode === "bt" ? card.bt.present : true)

    readonly property bool scanning: card.mode === "bt" ? card.bt.discovering : (card.mode === "wifi" && Networking.wifiEnabled && card.active)

    readonly property string coreGlyph: {
        if (card.mode === "bt")
            return card.bt.glyph;
        if (card.mode === "wifi")
            return Networking.wifiEnabled ? (card.net.activeWifi ? card.net.wifiGlyph(card.net.activeWifi.signalStrength) : "󰤩") : "󰤮";
        return card.powered ? "󰈀" : "󰌙";
    }

    readonly property string coreLabel: {
        if (card.mode === "bt") {
            if (!card.bt.present)
                return "No adapter";
            if (!card.bt.enabled)
                return "Off";
            const count = card.bt.connectedDevices.length;
            return count === 0 ? "On" : `${count} connected`;
        }
        if (card.mode === "wifi") {
            if (!Networking.wifiEnabled)
                return "Off";
            return card.net.activeWifi?.name ?? "On";
        }
        return card.net.wiredDevice?.name ?? "No link";
    }

    readonly property string emptyText: {
        if (card.mode === "eth")
            return card.powered ? "" : "Cable not connected";
        if (card.mode === "bt") {
            if (!card.bt.present)
                return "No bluetooth adapter found";
            if (!card.bt.enabled)
                return "Turn bluetooth on to see devices";
            return card.nodes.length === 0 ? "Scanning for devices…" : "";
        }
        if (!Networking.wifiEnabled)
            return "Turn Wi-Fi on to see networks";
        return card.nodes.length === 0 ? "Scanning for networks…" : "";
    }

    readonly property string hint: {
        if (card.failure !== "")
            return card.failure;
        if (card.bt.status !== "" && card.mode === "bt")
            return card.bt.status;
        if (card.overflow > 0)
            return `+${card.overflow} more — use Advanced`;
        if (card.mode === "eth")
            return "";
        return "Click to connect · right-click to forget";
    }

    function togglePower() {
        if (card.mode === "bt")
            card.bt.adapter.enabled = !card.bt.adapter.enabled;
        else if (card.mode === "wifi")
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
