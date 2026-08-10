import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The settings overlay: a full-screen layer holding a dimmed backdrop and one
// centred glass window, with a sidebar of sections down its left.
//
// One of these lives per bar, so it opens on the screen whose gear was
// clicked rather than always on the primary. It is a layer surface rather
// than a PopupWindow because it has to cover the whole output including the
// bar itself, and because a popup cannot take keyboard focus the way the
// panel needs to.
PanelWindow {
    id: overlay

    required property var theme
    required property var displays

    property bool open: false

    // Sections. Adding one is an entry here plus a case in the Loader below —
    // the sidebar, the routing and the empty state all read from this list.
    readonly property var sections: [
        {
            id: "displays",
            label: "Displays",
            glyph: "󰍹"
        }
    ]

    property string section: "displays"

    // Own namespace so the compositor can blur and animate the overlay
    // separately from the bar; both are matched in
    // modules/home/hyprland/windowrules.nix.
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    // Only while open, or the shell would hold the keyboard hostage for the
    // entire session.
    WlrLayershell.keyboardFocus: overlay.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // The overlay covers the screen but must not push anything around: it is
    // transient, and reserving space for it would resize every tiled window
    // each time it opened.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: overlay.open

    // ── Backdrop ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: overlay.open = false
        }
    }

    // ── Window ─────────────────────────────────────────────────────────
    Item {
        id: frame

        anchors.centerIn: parent
        // Bounded by the screen so the panel still fits on a small output,
        // and capped so it does not sprawl across a 4K one.
        width: Math.min(940, parent.width - 80)
        height: Math.min(660, parent.height - 80)

        focus: true
        Keys.onEscapePressed: overlay.open = false

        // Swallows backdrop clicks that land on the window itself.
        MouseArea {
            anchors.fill: parent
        }

        // The bar's glass at menu opacity: a settings window is something you
        // read, not something you glance past.
        Rectangle {
            anchors.fill: parent
            radius: 18

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: overlay.theme.edgeTop
                }

                GradientStop {
                    position: 0.5
                    color: overlay.theme.edgeSide
                }

                GradientStop {
                    position: 1
                    color: overlay.theme.edgeBottom
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 17
                color: overlay.theme.cardSurface
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ── Title bar ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 52

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "Settings"
                        color: overlay.theme.fg
                        font.family: overlay.theme.fontFamily
                        font.bold: true
                        font.pixelSize: 15
                    }

                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 8
                        color: closeHover.containsMouse ? Qt.rgba(overlay.theme.bad.r, overlay.theme.bad.g, overlay.theme.bad.b, 0.35) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: overlay.theme.fg
                            font.family: overlay.theme.fontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closeHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overlay.open = false
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: 1
                    color: Qt.rgba(overlay.theme.fg.r, overlay.theme.fg.g, overlay.theme.fg.b, 0.1)
                }
            }

            // ── Sidebar + content ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.preferredWidth: 190
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Repeater {
                            model: overlay.sections

                            delegate: Rectangle {
                                id: tab

                                required property var modelData

                                readonly property bool current: overlay.section === tab.modelData.id

                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 9
                                color: tab.current ? Qt.rgba(overlay.theme.accent.r, overlay.theme.accent.g, overlay.theme.accent.b, 0.22) : (tabHover.containsMouse ? Qt.rgba(overlay.theme.fg.r, overlay.theme.fg.g, overlay.theme.fg.b, 0.1) : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 130
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 11
                                    spacing: 9

                                    Text {
                                        text: tab.modelData.glyph
                                        color: tab.current ? overlay.theme.accent : overlay.theme.dim
                                        font.family: overlay.theme.fontFamily
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: tab.modelData.label
                                        color: tab.current ? overlay.theme.fg : overlay.theme.dim
                                        font.family: overlay.theme.fontFamily
                                        font.bold: tab.current
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: tabHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: overlay.section = tab.modelData.id
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        implicitWidth: 1
                        color: Qt.rgba(overlay.theme.fg.r, overlay.theme.fg.g, overlay.theme.fg.b, 0.1)
                    }
                }

                Loader {
                    id: content

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Torn down on close so a page cannot keep polling behind
                    // a window nobody is looking at.
                    active: overlay.open && overlay.section === "displays"

                    sourceComponent: DisplaysPage {
                        theme: overlay.theme
                        displays: overlay.displays
                        popupLayer: dropdowns
                    }
                }
            }
        }

        // Dropdown lists draw here rather than inside the layout, which would
        // clip them to their row and shove everything below them down. Last
        // child, so it sits over the content without needing a z fight.
        Item {
            id: dropdowns

            anchors.fill: parent
        }
    }

    // A panel that materialises instantly reads as a glitch at this size.
    onOpenChanged: if (overlay.open) {
        reveal.restart();
        // Re-read the hardware on the way in, so unplugging a monitor between
        // two visits cannot leave the page describing one that is gone.
        overlay.displays.refreshCapabilities();
    }

    ParallelAnimation {
        id: reveal

        NumberAnimation {
            target: frame
            property: "opacity"
            from: 0
            to: 1
            duration: 140
        }

        NumberAnimation {
            target: frame
            property: "scale"
            from: 0.97
            to: 1
            duration: 190
            easing.type: Easing.OutCubic
        }
    }
}
