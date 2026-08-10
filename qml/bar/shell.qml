import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Each bar section lives in its own folder — see the README in each.
import "connectivity"
import "media"
import "settings"
import "tray"

ShellRoot {
    id: root

    // ── Palette ────────────────────────────────────────────────────────
    // Ported from modules/home/waybar/colors.nix, so the two bars read as
    // one system rather than as two themes fighting over the same screen.
    // Everything visual lives in this block: restyling means touching one
    // place instead of hunting through the widgets.
    readonly property color bg: "#1d2021"       // @background
    readonly property color bgAlt: "#282828"    // @second-background
    readonly property color fg: "#bfd7ea"       // @color6
    readonly property color dim: "#848598"      // @color7
    readonly property color accent: "#bfd7ea"   // @color6 — active/selected
    readonly property color hover: "#ffc8d8"    // @color4 — waybar's hover
    readonly property color good: "#8ec07c"     // @color2
    readonly property color warn: "#d2b48c"     // @color1
    readonly property color bad: "#c53f67"      // @color0

    // ── Glass ──────────────────────────────────────────────────────────
    // Half-transparent fills over a compositor blur, lit along the top
    // edge and fading towards the bottom, so each island reads as a pane
    // of glass rather than a flat panel. Hyprland does the actual
    // blurring — `waybarBlur` for the qs-bar layer in
    // modules/home/hyprland/windowrules.nix, the same rules waybar runs.
    // Nothing here blurs anything itself; without that rule this still
    // renders, just transparent instead of frosted.
    //
    // 0.5 is waybar's module fill (`alpha(@background, .5)` in
    // modules/home/waybar/styles.nix) and it has to stay at or above the
    // layer's ignore_alpha, or the compositor leaves the islands sharp.
    readonly property color surface: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.5)
    // Popups sit over arbitrary windows rather than over the wallpaper, so
    // they carry more fill than the bar does.
    readonly property color cardSurface: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.72)
    // Menus and dropdowns stack on top of a card that is already translucent,
    // and two sheets at 0.72 add up to something you can read the desktop
    // through. This one is nearly solid so the layering stays legible.
    readonly property color menuSurface: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.94)
    readonly property color edgeTop: Qt.rgba(1, 1, 1, 0.25)
    readonly property color edgeSide: Qt.rgba(1, 1, 1, 0.12)
    readonly property color edgeBottom: Qt.rgba(1, 1, 1, 0.05)

    // ── Metrics ────────────────────────────────────────────────────────
    readonly property int barHeight: 38
    // The bar floats rather than sitting on the screen edge, so the
    // wallpaper shows through above and beside the islands.
    readonly property int barMargin: 8
    readonly property int islandRadius: 14
    readonly property int islandPadding: 12
    readonly property int pillRadius: 10
    readonly property int gap: 12

    // Kept in step with modules/home/waybar/styles.nix so the two bars read
    // as one system. Sizes are not shared: waybar's 15pt would not fit a
    // 38px bar, so only the family and weight carry over.
    readonly property string fontFamily: "CodeNewRoman Nerd Font Propo"
    readonly property bool fontBold: true

    // A pane of glass. Rectangle carries a single border colour, so the lit
    // edge is a gradient rectangle with the fill inset one pixel inside it.
    // That is what reproduces the four separate border-* colours the waybar
    // CSS uses to fake a bevel.
    component GlassSurface: Rectangle {
        id: glass

        radius: root.islandRadius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.edgeTop
            }

            GradientStop {
                position: 0.5
                color: root.edgeSide
            }

            GradientStop {
                position: 1
                color: root.edgeBottom
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: glass.radius - 1
            color: root.surface
        }
    }

    // The bar's inner buttons: transparent until pointed at, which is how
    // the waybar workspace buttons and module labels behave. `active` is the
    // waybar `.active` state — a filled pill with the background colour
    // showing through the label.
    component Pill: Rectangle {
        id: pill

        property bool active: false
        readonly property bool hovered: pointer.containsMouse

        // Set false on the inner edge of a pair that should read as one
        // control. This is what the waybar CSS does by hand when it welds
        // #wireplumber.sink to #wireplumber.mic.
        property bool roundLeft: true
        property bool roundRight: true

        // Half of a welded pair cannot light up on its own: the fill stops
        // dead against a square inner edge, and the seam reads as a rendering
        // fault rather than as a hover. waybar has the same problem and
        // answers it the same way — #wireplumber:hover only moves `color`,
        // never the background — so a pill that shares an edge says "hover"
        // through its label instead.
        readonly property bool hoverFill: pill.roundLeft && pill.roundRight

        signal clicked(int button)
        signal scrolled(var event)

        implicitHeight: 26
        radius: root.pillRadius
        topLeftRadius: pill.roundLeft ? pill.radius : 0
        bottomLeftRadius: pill.roundLeft ? pill.radius : 0
        topRightRadius: pill.roundRight ? pill.radius : 0
        bottomRightRadius: pill.roundRight ? pill.radius : 0
        color: pill.active ? root.accent : (pill.hovered && pill.hoverFill ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => pill.clicked(mouse.button)
            onWheel: wheel => pill.scrolled(wheel)
        }
    }

    // A sink or source readout: glyph, percentage, click to mute, scroll to
    // change volume. Both audio controls are this same widget pointed at a
    // different pipewire node, which is exactly how waybar runs its two
    // #wireplumber modules.
    component AudioPill: Pill {
        id: audio

        property var node: null
        // Set to the same glyphs modules/home/waybar/settings.nix uses, and
        // named in a comment at the point of use — an invisible codepoint in
        // the source is otherwise unreviewable.
        property string glyph
        property string mutedGlyph

        readonly property bool muted: audio.node?.audio?.muted ?? false
        readonly property int pct: Math.round((audio.node?.audio?.volume ?? 0) * 100)

        // A machine with no microphone should not carry a dead pill.
        visible: audio.node !== null
        implicitWidth: audioLabel.implicitWidth + 16

        // waybar mutes on right-click. Left does it here too: nothing else is
        // bound to left, and reaching for the right button to mute is a
        // surprise nobody asked for.
        onClicked: {
            const sound = audio.node?.audio;
            if (sound)
                sound.muted = !sound.muted;
        }

        onScrolled: wheel => {
            const sound = audio.node?.audio;
            if (!sound)
                return;
            // 5% a notch, matching the wpctl calls waybar is configured with.
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            sound.volume = Math.max(0, Math.min(1, sound.volume + step));
        }

        Text {
            id: audioLabel

            anchors.centerIn: parent
            color: audio.muted ? root.dim : (audio.hovered ? root.hover : root.fg)
            font.family: root.fontFamily
            font.bold: root.fontBold
            font.pixelSize: 13
            text: audio.muted ? audio.mutedGlyph : audio.glyph + " " + audio.pct + "%"

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
        }
    }

    // Pipewire only populates volume/mute on nodes something is tracking.
    // Without this the sink and source read as volume 0, muted false, forever.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Shared by every bar, so all screens agree on the current player and
    // cava runs once no matter how many monitors are plugged in. The ids
    // deliberately differ from the MediaWidget properties they feed:
    // `media: media` would resolve to the widget's own property and bind to
    // undefined.
    Media {
        id: mediaState

        fallbackAccent: root.accent
    }

    Net {
        id: netState
    }

    Bt {
        id: btState
    }

    // Shared by every bar so the panels on both screens agree on what has
    // been edited and what has been applied.
    Displays {
        id: displayState
    }

    Cava {
        id: cavaSource

        // Nothing to visualise while playback is stopped, and cava polls its
        // source for as long as it is up.
        active: mediaState.player?.isPlaying ?? false

        // Follow the player's own pipewire stream rather than the default
        // sink's monitor, so the spectrum shows the track and not every other
        // sound the machine makes. Falls back to the monitor when the player
        // cannot be matched to a stream.
        source: mediaState.streamName || "auto"
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            // What the Hyprland layer_rule matches on to blur us. Quickshell
            // would otherwise name every one of its surfaces "quickshell",
            // which would drag any other shell along with the rule.
            WlrLayershell.namespace: "qs-bar"

            anchors {
                top: true
                left: true
                right: true
            }

            // The window itself draws nothing: the islands inside it carry
            // every visible pixel, so the wallpaper shows through the gaps
            // between them.
            margins {
                top: root.barMargin
                left: root.barMargin
                right: root.barMargin
            }

            implicitHeight: root.barHeight
            // Auto mode derives the zone from the anchors alone and ignores
            // whatever exclusiveZone says, so it has to be turned off before
            // the top margin can be reserved as well. Without that, maximised
            // windows tuck up underneath the float.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.barHeight + root.barMargin
            color: "transparent"

            // ── Left: audio, media ─────────────────────────────────────
            Item {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: leftRow.implicitWidth + root.islandPadding * 2
                implicitHeight: parent.height

                GlassSurface {
                    anchors.fill: parent
                }

                RowLayout {
                    id: leftRow

                    anchors.centerIn: parent
                    spacing: root.gap

                    // Speaker and microphone, welded into one capsule the way
                    // the waybar CSS joins #wireplumber.sink to
                    // #wireplumber.mic by dropping the borders between them.
                    RowLayout {
                        spacing: 0

                        AudioPill {
                            node: Pipewire.defaultAudioSink
                            glyph: ""       // fa-volume-up
                            mutedGlyph: ""  // codicon-mute
                            roundRight: false
                        }

                        AudioPill {
                            node: Pipewire.defaultAudioSource
                            glyph: ""       // fa-microphone
                            mutedGlyph: ""  // fa-microphone-slash
                            roundLeft: false
                        }
                    }

                    MediaWidget {
                        theme: root
                        media: mediaState
                        cava: cavaSource
                    }
                }
            }

            // ── Center: workspaces ─────────────────────────────────────
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: workspaceRow.implicitWidth + root.islandPadding * 2
                implicitHeight: parent.height

                GlassSurface {
                    anchors.fill: parent
                }

                RowLayout {
                    id: workspaceRow

                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Pill {
                            id: workspace

                            required property var modelData

                            active: workspace.modelData.focused
                            // The focused pill stretches, the way waybar's
                            // `button.active { min-width: 40px }` does.
                            implicitWidth: workspace.active ? 36 : 26
                            implicitHeight: 24

                            onClicked: {
                                // Dispatcher syntax differs between the lua and
                                // legacy backends, and Hyprland tells us which
                                // one is live.
                                if (Hyprland.usingLua)
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.modelData.id} })`);
                                else
                                    Hyprland.dispatch(`workspace ${workspace.modelData.id}`);
                            }

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: workspace.modelData.name
                                font.family: root.fontFamily
                                font.bold: root.fontBold
                                font.pixelSize: 12
                                color: workspace.active ? root.bg : (workspace.modelData.urgent ? root.bad : (workspace.hovered ? root.hover : root.dim))

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 160
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Right: connectivity, tray, clock ───────────────────────
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: rightRow.implicitWidth + root.islandPadding * 2
                implicitHeight: parent.height

                GlassSurface {
                    anchors.fill: parent
                }

                RowLayout {
                    id: rightRow

                    anchors.centerIn: parent
                    spacing: root.gap

                    ConnectivityWidget {
                        theme: root
                        net: netState
                        bt: btState
                    }

                    TrayWidget {
                        theme: root
                    }

                    Pill {
                        id: clock

                        property string label: Qt.formatDateTime(new Date(), "HH:mm ddd")

                        Layout.preferredWidth: clockLabel.implicitWidth + 16

                        Text {
                            id: clockLabel

                            anchors.centerIn: parent
                            text: clock.label
                            color: clock.hovered ? root.hover : root.fg
                            font.family: root.fontFamily
                            font.bold: root.fontBold
                            font.pixelSize: 13

                            Behavior on color {
                                ColorAnimation {
                                    duration: 250
                                }
                            }
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clock.label = Qt.formatDateTime(new Date(), "HH:mm ddd")
                        }
                    }

                    SettingsWidget {
                        theme: root
                        displays: displayState
                    }
                }
            }
        }
    }
}
