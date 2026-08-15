import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

// Each bar section lives in its own folder — see the README in each.
import "connectivity"
import "media"
import "session"
import "settings"
// The two sections' shared state objects, which live with their sections
// rather than at the top of settings/. They are instantiated here so both
// screens' panels read the same one.
import "settings/displays"
import "settings/wallpaper"
import "system"
import "theme"
import "tray"

ShellRoot {
    id: root

    // ── Theme ──────────────────────────────────────────────────────────
    // Two palettes and two themes, which is one more of each than it looks
    // like it should be.
    //
    // `livePalette` follows the wallpaper when the Wallpaper section says to,
    // and holds the fixed colours when it does not. `basePalette` is the same
    // object with that switch wired off, so it is *always* the fixed colours.
    //
    // The media widget gets the fixed one. It already derives an accent from
    // the cover art, and a wallpaper-derived palette underneath it would put
    // two unrelated generated colours in the same 200 pixels — the album's
    // and the desktop's — which reads as a bug rather than as a theme.
    // Everything else on the bar follows the wallpaper.
    Palette {
        id: livePalette

        enabled: wallpaperState.settings.dynamicColours
        source: wallpaperState.currentPath
        // Matched to awww's own transition so the bar and the desktop behind
        // it are one movement. Clamped because the setting reaches 4s, and a
        // palette still sliding four seconds after the wallpaper landed reads
        // as lag rather than as a fade.
        fadeDuration: Math.max(250, Math.min(1600, wallpaperState.settings.transitionDuration * 1000))
    }

    Palette {
        id: basePalette

        enabled: false
    }

    Theme {
        id: barTheme

        palette: livePalette
    }

    Theme {
        id: baseTheme

        palette: basePalette
    }

    // A pane of glass: a fill, and an edge.
    //
    // The fill is whatever `barTheme.surface` says and is currently nothing at
    // all, so the edge is doing all the work of saying where the pill is. That
    // is why it is a GlassRim and not a `border`: `border.width` is one number
    // for all four sides, and a uniform hairline around an empty shape reads
    // as an outline drawn on the wallpaper rather than as glass. The rim is
    // thickest and brightest along the top, thinning down the sides, nearly
    // gone underneath — see ../theme/GlassRim.qml.
    component GlassSurface: Item {
        id: glass

        Rectangle {
            anchors.fill: parent
            radius: barTheme.islandRadius
            color: barTheme.surface
        }

        GlassRim {
            anchors.fill: parent
            theme: barTheme
        }
    }

    // One module's pane. waybar gives every module its own background, border
    // and radius — `#cpu`, `#memory`, `#network` and the rest all shared one
    // rule — and welds a group into a single capsule by zeroing the borders
    // and corners between its members. This is the first half of that: a pane
    // with things in it. The welding is done by putting those things in the
    // *same* island.
    // An island whose only occupant has nothing to show must not sit there as
    // an empty blister of glass, so some of these are given a `visible`. Note
    // what that condition has to be bound to: the *state*, as in
    // `mediaState.player !== null`, and never the occupant's own `visible`.
    //
    // Deriving it from the content deadlocks, and does it silently. Setting
    // `visible: false` on an item forces `visible: false` onto its children,
    // and a Row skips children that are not visible — so an island that hides
    // itself because its content measured zero wide has just made its content
    // measure zero wide. It can never come back. The media pill did exactly
    // this: `player` is assigned in Component.onCompleted, so the island was
    // briefly empty during startup, hid, and stayed hidden for the rest of the
    // session with a player quite happily running.
    component Island: Item {
        id: island

        default property alias content: body.data

        // Islands are all one height unless a caller says otherwise. Named
        // rather than left to an `implicitHeight` override at the call site:
        // that works, but it silently replaces the binding to
        // `barTheme.islandHeight`, so the odd one out would stop following the
        // bar's zoom while every other island kept up.
        property real heightScale: 1

        implicitWidth: body.implicitWidth + barTheme.islandPadding * 2
        implicitHeight: Math.round(barTheme.islandHeight * island.heightScale)

        GlassSurface {
            anchors.fill: parent
        }

        Row {
            id: body

            anchors.centerIn: parent
            spacing: barTheme.gap
        }
    }

    // The bar's inner buttons: a hit target and a shape, and no fill of their
    // own in any state.
    //
    // Nothing here reacts to hover. A pill that grows a translucent white
    // rectangle inside a pane of glass reads as a second, smaller pane rather
    // than as a response, and waybar does not do it either: `:hover` there
    // only ever moves `color` and runs the icon-pulse glow. The labels handle
    // that themselves — see ../theme/PulseText.qml.
    //
    // There is no `active` here either. Workspaces were the only caller that
    // ever used it, and they now draw their own highlight so that it can be
    // animated separately from the label sitting on top of it.
    component Pill: Rectangle {
        id: pill

        readonly property bool hovered: pointer.containsMouse

        // Set false on the inner edge of a pair that should read as one
        // control. This is what the waybar CSS does by hand when it welds
        // #wireplumber.sink to #wireplumber.mic.
        property bool roundLeft: true
        property bool roundRight: true

        signal clicked(int button)
        signal scrolled(var event)

        implicitHeight: barTheme.controlSize
        radius: barTheme.pillRadius
        topLeftRadius: pill.roundLeft ? pill.radius : 0
        bottomLeftRadius: pill.roundLeft ? pill.radius : 0
        topRightRadius: pill.roundRight ? pill.radius : 0
        bottomRightRadius: pill.roundRight ? pill.radius : 0
        color: "transparent"

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
        // The same glyphs the waybar config used, each named in a comment at
        // the point of use — an invisible codepoint in the source is
        // otherwise unreviewable.
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

        PulseText {
            id: audioLabel

            anchors.centerIn: parent
            theme: barTheme
            lit: audio.hovered
            color: audio.muted ? barTheme.dim : (audio.hovered ? barTheme.hover : barTheme.fg)
            glowColor: barTheme.hover
            font.pixelSize: barTheme.fontSize
            text: audio.muted ? audio.mutedGlyph : audio.glyph + " " + audio.pct + "%"
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

        // The fixed accent, not the live one: a cover with nothing saturated
        // in it should fall back to the media widget's own resting colour,
        // not to whatever the desktop happens to be showing.
        fallbackAccent: baseTheme.accent
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

    // Shared for the same reason, and because `livePalette` above reads its
    // `currentPath`: one watcher on the state file rather than one per screen.
    Wallpaper {
        id: wallpaperState
    }

    // Shared for the same reason the others are: an idle inhibitor is a
    // property of the session and not of a monitor, and one per screen would
    // mean the button on one output disagreeing with the button on the other.
    Idle {
        id: idleState
    }

    // Shared, and here it matters more than usual: CPU load is a *delta*
    // between two reads of /proc/stat, so a second sampler would not just
    // duplicate the work, it would interleave with this one and leave both
    // computing their deltas against the other's baseline.
    Resources {
        id: resourceState
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
                top: barTheme.barMargin
                left: barTheme.barMargin
                right: barTheme.barMargin
            }

            implicitHeight: barTheme.barHeight
            // Auto mode derives the zone from the anchors alone and ignores
            // whatever exclusiveZone says, so it has to be turned off before
            // the top margin can be reserved as well. Without that, maximised
            // windows tuck up underneath the float.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: barTheme.barHeight + barTheme.barMargin
            color: "transparent"

            // ── Left: audio, media ─────────────────────────────────────
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: barTheme.islandGap

                // First thing on the bar, in a pane of its own — waybar puts
                // #custom-startmenu at the head of modules-left for the same
                // reason. It is the only control here that leaves the session,
                // so it does not belong welded to anything that does not.
                Island {
                    PowerWidget {
                        theme: barTheme
                    }
                }

                // Speaker and microphone share a pane. That is the same
                // capsule the waybar CSS assembles by hand when it drops the
                // borders and inner corners between #wireplumber.sink and
                // #wireplumber.mic — except here the weld is structural.
                // Things are welded because they are in the same island, so
                // there is no pair of radius rules to keep in agreement.
                Island {
                    // A machine with neither a sink nor a source would
                    // otherwise carry an island holding two hidden pills.
                    visible: Pipewire.defaultAudioSink !== null || Pipewire.defaultAudioSource !== null

                    Row {
                        spacing: 0

                        AudioPill {
                            node: Pipewire.defaultAudioSink
                            glyph: ""       // fa-volume-up
                            mutedGlyph: ""  // codicon-mute
                            roundRight: false
                        }

                        AudioPill {
                            node: Pipewire.defaultAudioSource
                            glyph: ""       // fa-microphone
                            mutedGlyph: ""  // fa-microphone-slash
                            roundLeft: false
                        }
                    }
                }

                // Its own pane, so it leaves cleanly with the player instead
                // of leaving a hole in a shared one. Bound to the player and
                // not to the widget's visibility — see the note on Island.
                Island {
                    visible: mediaState.player !== null

                    // The one widget on the bar held out of the wallpaper
                    // palette — see the Theme block at the top of this file.
                    MediaWidget {
                        theme: baseTheme
                        media: mediaState
                        cava: cavaSource
                        // The live alt accent, so an open player and the nix
                        // logo agree. Everything else about this widget stays
                        // on the fixed palette.
                        openAccent: barTheme.accentAlt
                    }
                }

                
            }

            // ── Center: workspaces ─────────────────────────────────────
            // One pane, like waybar's #workspaces, which is also a single
            // background with buttons drawn inside it rather than a pill per
            // workspace.
            Island {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // Taller than the rest. It is the one island that is a control
                // rather than a readout, and the extra height is what stops
                // the centre of the bar reading as just more of the same row.
                heightScale: 1.2

                Row {
                    spacing: Math.round(4 * barTheme.zoom)

                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Pill {
                            id: workspace

                            required property var modelData

                            readonly property bool active: workspace.modelData.focused
                            // One width for every workspace, focused or not.
                            // waybar stretches the active one — `button.active
                            // { min-width: 40px }` — and this used to animate
                            // that stretch, but switching workspace moves
                            // `active` on two pills at once: one grows while
                            // the other shrinks, so the whole row slides
                            // sideways and every label lands somewhere new.
                            // Holding the width still means the only thing
                            // that changes is the thing that changed.
                            implicitWidth: Math.round(30 * barTheme.zoom)
                            implicitHeight: barTheme.pillHeight

                            // The focus marker, drawn under the label and
                            // scaled independently of it.
                            //
                            // Switching workspace is two things happening at
                            // once, and they are deliberately not the same
                            // thing played backwards: the workspace being left
                            // shrinks away, and the one being landed on grows
                            // in past its own size and settles. A symmetric
                            // cross-fade reads as one blob sliding along the
                            // row; this reads as somewhere being left and
                            // somewhere being arrived at.
                            //
                            // `scale` is a render transform, so neither half
                            // of it disturbs the row's layout.
                            Rectangle {
                                id: highlight

                                anchors.fill: parent
                                radius: parent.radius
                                topLeftRadius: parent.topLeftRadius
                                bottomLeftRadius: parent.bottomLeftRadius
                                topRightRadius: parent.topRightRadius
                                bottomRightRadius: parent.bottomRightRadius
                                color: barTheme.accent
                                opacity: 0
                                scale: 0.55

                                states: State {
                                    name: "focused"
                                    when: workspace.active

                                    PropertyChanges {
                                        highlight.opacity: 1
                                        highlight.scale: 1
                                    }
                                }

                                transitions: [
                                    // Arriving. OutBack overshoots slightly
                                    // and settles, which is what makes it read
                                    // as landing rather than as fading up.
                                    Transition {
                                        to: "focused"

                                        NumberAnimation {
                                            property: "opacity"
                                            duration: 140
                                        }

                                        NumberAnimation {
                                            property: "scale"
                                            duration: 300
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 2.2
                                        }
                                    },
                                    // Leaving. Shorter, and accelerating
                                    // away — an overshoot on the way out
                                    // would look like it was trying to come
                                    // back.
                                    Transition {
                                        from: "focused"

                                        NumberAnimation {
                                            properties: "opacity,scale"
                                            duration: 200
                                            easing.type: Easing.InQuad
                                        }
                                    }
                                ]
                            }

                            onClicked: {
                                // Dispatcher syntax differs between the lua and
                                // legacy backends, and Hyprland tells us which
                                // one is live.
                                if (Hyprland.usingLua)
                                    Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.modelData.id} })`);
                                else
                                    Hyprland.dispatch(`workspace ${workspace.modelData.id}`);
                            }

                            PulseText {
                                anchors.centerIn: parent
                                theme: barTheme
                                text: workspace.modelData.name
                                font.pixelSize: barTheme.smallFontSize
                                // The focused workspace does not glow. It is
                                // already a filled pill; a halo on top of that
                                // is a second answer to a question the fill
                                // has answered.
                                lit: workspace.hovered && !workspace.active
                                color: workspace.active ? barTheme.bg : (workspace.modelData.urgent ? barTheme.bad : (workspace.hovered ? barTheme.hover : barTheme.dim))
                                glowColor: barTheme.hover
                            }
                        }
                    }
                }
            }

            // ── Right: idle, connectivity, tray, clock, session ────────
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: barTheme.islandGap

                // waybar keeps #cpu and #memory next to each other and welds
                // neither, but they are two readings of the same thing — how
                // hard the machine is working — and they open the same
                // program, so here they share a pane.
                Island {
                    ResourcesWidget {
                        theme: barTheme
                        resources: resourceState
                    }
                }

                // Idle inhibitor, bluetooth and network in one capsule —
                // the same three waybar welds together, in the same order.
                // They have nothing to do with each other; they are grouped
                // because each is one glyph, and five separate one-glyph
                // panes in a row would read as noise.
                Island {
                    IdleWidget {
                        theme: barTheme
                        idle: idleState
                    }

                    ConnectivityWidget {
                        theme: barTheme
                        net: netState
                        bt: btState
                    }
                }

                // Nothing has registered a StatusNotifierItem on a fresh
                // session for a good few seconds, and an empty pane sitting
                // there in the meantime is worse than one that arrives.
                Island {
                    visible: SystemTray.items.values.length > 0

                    TrayWidget {
                        theme: barTheme
                    }
                }

                Island {
                    Pill {
                        id: clock

                        property string label: Qt.formatDateTime(new Date(), "HH:mm ddd")

                        implicitWidth: clockLabel.implicitWidth + Math.round(12 * barTheme.zoom)
                        implicitHeight: barTheme.pillHeight

                        PulseText {
                            id: clockLabel

                            anchors.centerIn: parent
                            theme: barTheme
                            text: clock.label
                            lit: clock.hovered
                            color: clock.hovered ? barTheme.hover : barTheme.fg
                            glowColor: barTheme.hover
                            font.pixelSize: barTheme.fontSize
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clock.label = Qt.formatDateTime(new Date(), "HH:mm ddd")
                        }
                    }
                }

                Island {
                    SettingsWidget {
                        theme: barTheme
                        displays: displayState
                        wallpaper: wallpaperState
                    }
                }
            }
        }
    }
}
