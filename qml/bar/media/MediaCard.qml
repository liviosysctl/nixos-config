import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// The expanded view behind the bar pill: cover art, track details, a seek
// bar and transport controls. Sized by its content so the PopupWindow
// hosting it can just take its implicit size.
Item {
    id: card

    required property var theme
    required property var media
    required property var cava

    // False while the popup window is down. Used to park the position poll
    // instead of ticking against a card nobody can see.
    property bool active: true

    // True across a resync, to stop the seek fill animating towards a value
    // it should simply already be at. See onActiveChanged.
    property bool snapping: false

    // The poll parks while the popup is down, so position is as stale as the
    // card has been closed. Ask for it again on the way in and land on the
    // answer, rather than waiting a poll interval and then crawling to it.
    onActiveChanged: {
        if (!card.active || !card.player)
            return;
        card.snapping = true;
        card.player.positionChanged();
        Qt.callLater(() => card.snapping = false);
    }

    readonly property var player: card.media.player
    readonly property color accent: card.media.accent
    readonly property int padding: 16

    implicitWidth: 372
    implicitHeight: content.implicitHeight + card.padding * 2

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "--:--";
        const total = Math.floor(seconds);
        const secs = total % 60;
        const mins = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);
        const mm = hours > 0 && mins < 10 ? "0" + mins : "" + mins;
        const ss = secs < 10 ? "0" + secs : "" + secs;
        return hours > 0 ? `${hours}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    // A round icon button. Inline so it can read the card's palette
    // directly instead of taking six colour properties.
    component IconButton: Rectangle {
        id: button

        property string glyph
        property bool highlighted: false
        property int diameter: 30
        property int glyphSize: 15
        // Resting fill. `color` itself is spoken for by the hover binding.
        property color baseColor: "transparent"

        signal triggered

        // Item.enabled rather than a property of our own: it already gates
        // the MouseArea below for free.
        implicitWidth: diameter
        implicitHeight: diameter
        radius: diameter / 2
        color: hover.containsMouse ? Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.2) : baseColor

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: card.theme.fontFamily
            font.pixelSize: button.glyphSize
            color: !button.enabled ? card.theme.dim : (button.highlighted ? card.accent : card.theme.fg)
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }

    // ── Surface ────────────────────────────────────────────────────────
    // The same glass construction the bar islands use: a gradient rectangle
    // standing in for the lit edge, with the fill inset one pixel inside it,
    // because Rectangle only carries a single border colour. The top of the
    // edge picks up the artwork accent — the card has one to spend, and the
    // bar does not.
    Rectangle {
        anchors.fill: parent
        radius: 16

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.45)
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

    // Cover art, blown up and blurred, as a faint backdrop. Ties the card to
    // the artwork without costing text contrast.
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 15
        color: "transparent"

        Image {
            id: backdrop

            anchors.fill: parent
            source: card.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Hidden because MultiEffect consumes it as a texture rather
            // than as a drawn item.
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: backdrop
            visible: backdrop.status === Image.Ready
            opacity: 0.16
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.3
        }
    }

    // ── Content ────────────────────────────────────────────────────────
    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: card.padding
        spacing: 14

        // Cover + track details + spectrum.
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ClippingRectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 10
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.14)

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: card.theme.fontFamily
                    font.pixelSize: 34
                    color: card.accent
                    visible: cover.status !== Image.Ready
                }

                Image {
                    id: cover

                    anchors.fill: parent
                    source: card.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(192, 192)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: card.player?.trackTitle || "Nothing playing"
                    color: card.theme.fg
                    font.family: card.theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: card.player?.trackArtist ?? ""
                    color: card.theme.fg
                    opacity: 0.75
                    font.family: card.theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    Layout.fillWidth: true
                    text: card.player?.trackAlbum ?? ""
                    color: card.theme.dim
                    font.family: card.theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Item {
                    Layout.fillHeight: true
                }

                // Fixed bar geometry rather than a width-derived spacing:
                // implicitWidth feeds the layout, so deriving it back from
                // width would close a binding loop.
                Spectrum {
                    Layout.preferredHeight: 26
                    values: card.cava.values
                    color: card.accent
                    barWidth: 8
                    barSpacing: 6
                    minHeight: 3
                }
            }
        }

        // Seek bar. Reading `length` of 0 means the player never reported
        // one, in which case there is nothing sensible to scrub against.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Rectangle {
                id: track

                readonly property real length: card.player?.length ?? 0
                readonly property real progress: length > 0 ? Math.min(1, (card.player?.position ?? 0) / length) : 0

                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Qt.rgba(card.theme.fg.r, card.theme.fg.g, card.theme.fg.b, 0.16)

                Rectangle {
                    id: fill

                    // Animated as a fraction rather than as a width, because
                    // the popup only lays its contents out the first time it
                    // is shown. A width binding would see track.width go
                    // 0 → real at that moment and animate the whole bar open
                    // like a seek, once, on the first open of the session.
                    property real fraction: track.progress

                    // Position only arrives once per poll, so the fill would
                    // otherwise step. Interpolating across exactly one poll
                    // interval lands on the next sample just as it arrives,
                    // which turns the steps into a continuous crawl.
                    Behavior on fraction {
                        enabled: !card.snapping

                        NumberAnimation {
                            duration: poll.interval
                            easing.type: Easing.Linear
                        }
                    }

                    width: track.width * fill.fraction
                    height: parent.height
                    radius: parent.radius
                    color: card.accent
                }

                Rectangle {
                    // Driven off the fill rather than off progress, so the
                    // handle and the fill edge cannot drift apart mid-slide.
                    x: fill.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: card.accent
                    visible: seek.containsMouse && seek.enabled
                }

                MouseArea {
                    id: seek

                    anchors.fill: parent
                    // Widen the hit area without making the bar itself thick.
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    hoverEnabled: true
                    enabled: (card.player?.canSeek ?? false) && track.length > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => card.player.position = Math.max(0, Math.min(1, mouse.x / width)) * track.length
                }

                // MPRIS does not push position updates, so a visible seek bar
                // has to ask for them. quickshell re-reads the property when
                // the change signal is raised by hand.
                Timer {
                    id: poll

                    interval: 500
                    repeat: true
                    running: card.active && (card.player?.isPlaying ?? false) && track.length > 0
                    onTriggered: card.player.positionChanged()
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.formatTime(card.player?.position ?? 0)
                    color: card.theme.dim
                    font.family: card.theme.fontFamily
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: card.player?.identity ?? ""
                    color: card.theme.dim
                    opacity: 0.7
                    font.family: card.theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: card.formatTime(track.length)
                    color: card.theme.dim
                    font.family: card.theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        // Transport.
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            IconButton {
                glyph: (card.player?.shuffle ?? false) ? "󰒝" : "󰒞"
                enabled: card.player?.shuffleSupported ?? false
                highlighted: card.player?.shuffle ?? false
                diameter: 26
                glyphSize: 14
                onTriggered: card.player.shuffle = !card.player.shuffle
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                glyph: "󰒮"
                glyphSize: 17
                enabled: card.player?.canGoPrevious ?? false
                onTriggered: card.player.previous()
            }

            IconButton {
                glyph: (card.player?.isPlaying ?? false) ? "󰏤" : "󰐊"
                enabled: card.player?.canTogglePlaying ?? false
                diameter: 40
                glyphSize: 20
                baseColor: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.22)
                onTriggered: card.player.togglePlaying()
            }

            IconButton {
                glyph: "󰒭"
                glyphSize: 17
                enabled: card.player?.canGoNext ?? false
                onTriggered: card.player.next()
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                readonly property int loop: card.player?.loopState ?? MprisLoopState.None

                glyph: loop === MprisLoopState.Track ? "󰑘" : (loop === MprisLoopState.Playlist ? "󰑖" : "󰑗")
                enabled: card.player?.loopSupported ?? false
                highlighted: loop !== MprisLoopState.None
                diameter: 26
                glyphSize: 14
                // None → Playlist → Track → None.
                onTriggered: card.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist : (loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
            }
        }
    }
}
