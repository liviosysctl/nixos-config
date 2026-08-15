import QtQuick
import QtQuick.Layouts

import "../common"

// The Wallpaper page: what is on screen, where the next one comes from, how it
// gets there, and whether the bar takes its colours from it.
//
// Everything here is applied as you set it, which is the opposite of the
// Displays page and for the opposite reason. A wrong monitor mode can leave a
// screen you cannot see well enough to fix; a wrong wallpaper is a wallpaper
// you can see perfectly and change again in one click. Drafting it would only
// put a button between someone and the thing they are trying to look at.
Item {
    id: page

    required property var theme
    required property var wallpaper
    // Where the dropdowns and the file browser draw. See ../common/Select.qml.
    required property Item popupLayer

    readonly property var settings: page.wallpaper.settings
    readonly property bool slideshow: page.settings.mode === "slideshow"

    // The swatches below read straight off `theme`, which for the bar is the
    // live palette — so with the toggle on they show what the current
    // wallpaper actually produced, and with it off they show the fixed
    // palette that is being used instead. Either way it is the truth.
    readonly property var swatches: [
        {
            name: "Accent",
            colour: page.theme.accent
        },
        {
            name: "Hover",
            colour: page.theme.hover
        },
        {
            name: "Text",
            colour: page.theme.fg
        },
        {
            name: "Muted",
            colour: page.theme.dim
        },
        {
            name: "Base",
            colour: page.theme.bg
        }
    ]

    function humanInterval(seconds) {
        if (seconds < 60)
            return seconds + "s";
        if (seconds < 3600)
            return (Math.round(seconds / 6) / 10).toString().replace(/\.0$/, "") + " min";
        return (Math.round(seconds / 360) / 10).toString().replace(/\.0$/, "") + " h";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Wallpaper"
            color: page.theme.fg
            font.family: page.theme.fontFamily
            font.bold: true
            font.pixelSize: 17
        }

        // ── What is on screen ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            // Fixed rather than implicit, for the same reason the Displays
            // page pins its canvas: the settings below have a natural height
            // and this strip does not, so left to itself it takes the slack
            // and squeezes them off the bottom of the window.
            Layout.preferredHeight: 100
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 176
                implicitHeight: 99  // 16:9, which is what the previewed thing is
                radius: 0
                color: Qt.rgba(0, 0, 0, 0.3)
                clip: true

                Image {
                    anchors.fill: parent
                    source: page.wallpaper.currentPath ? "file://" + page.wallpaper.currentPath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 352
                    sourceSize.height: 198
                    asynchronous: true
                    smooth: true

                    // The preview changing under you is the confirmation that
                    // the pick took, so it gets the same courtesy the desktop
                    // does rather than snapping.
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 260
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !page.wallpaper.currentPath
                    text: "No wallpaper set"
                    color: page.theme.dim
                    font.family: page.theme.fontFamily
                    font.pixelSize: 11
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    // Just the filename: the directory is already on screen
                    // in the field below, and the full path never fits.
                    text: page.wallpaper.currentPath.split("/").pop() || "—"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }

                // The palette, as it stands. Five chips is enough to tell at a
                // glance whether a wallpaper gave the bar something legible,
                // which is the question the toggle below actually raises.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 5

                    Repeater {
                        model: page.swatches

                        delegate: Rectangle {
                            required property var modelData

                            implicitWidth: 26
                            implicitHeight: 18
                            radius: 5
                            color: modelData.colour
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.14)

                            // The whole point is that these move when the
                            // wallpaper does, so they move the way the bar
                            // does rather than cutting.
                            Behavior on color {
                                ColorAnimation {
                                    duration: 400
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ── Settings ───────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 2
            contentHeight: detail.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: detail

                // Capped and left-aligned to match the Displays page — the two
                // sections are one click apart, and a form that changes width
                // between them reads as a bug rather than as two pages.
                width: Math.min(560, parent.width)
                columns: 2
                columnSpacing: 12
                rowSpacing: 10

                // Labels take Layout.fillWidth so the control column lands
                // against the pane's right edge rather than floating.

                // ── Colours ────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Colours from wallpaper"
                        color: page.theme.fg
                        font.family: page.theme.fontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "The bar takes its accent, text and base colours from whatever is on screen. Off keeps the fixed palette."
                        color: page.theme.dim
                        font.family: page.theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }

                Toggle {
                    theme: page.theme
                    checked: page.settings.dynamicColours
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop

                    // No restart: the bar reads this itself, and the slideshow
                    // script has no opinion about it.
                    onToggled: value => {
                        page.settings.dynamicColours = value;
                        page.wallpaper.persist();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    implicitHeight: 1
                    color: Qt.rgba(page.theme.fg.r, page.theme.fg.g, page.theme.fg.b, 0.1)
                }

                // ── Source ─────────────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    text: "Source"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                }

                Select {
                    theme: page.theme
                    popupLayer: page.popupLayer
                    model: ["One image", "Slideshow"]
                    currentIndex: page.slideshow ? 1 : 0
                    Layout.alignment: Qt.AlignRight

                    onActivated: index => {
                        page.settings.mode = index === 1 ? "slideshow" : "single";
                        page.wallpaper.apply();
                    }
                }

                // The path row, whichever of the two it is. One control rather
                // than two hidden ones: the field and the button are identical
                // in both modes and only the target differs.
                Text {
                    Layout.fillWidth: true
                    text: page.slideshow ? "Folder" : "Image"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        // Sized so the field and Browse together stay inside
                        // the form's 560 cap with room for a label.
                        implicitWidth: 210
                        implicitHeight: 32
                        radius: 9
                        color: Qt.rgba(page.theme.fg.r, page.theme.fg.g, page.theme.fg.b, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: (page.slideshow ? page.settings.directory : page.settings.image) || "Not set"
                            color: (page.slideshow ? page.settings.directory : page.settings.image) ? page.theme.fg : page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideLeft
                        }
                    }

                    Button {
                        theme: page.theme
                        label: "Browse"
                        onTriggered: {
                            picker.mode = page.slideshow ? "directory" : "image";
                            // Opens where the setting already points, so
                            // changing a pick is a click or two rather than a
                            // walk down from home every time.
                            picker.show(page.slideshow ? page.settings.directory : (page.settings.image.replace(/\/[^\/]*$/, "") || page.settings.directory));
                        }
                    }
                }

                // ── Slideshow ──────────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    text: "Change every"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                    visible: page.slideshow
                }

                Slider {
                    theme: page.theme
                    Layout.alignment: Qt.AlignRight
                    visible: page.slideshow
                    from: 30
                    to: 3600
                    stepSize: 30
                    value: page.settings.intervalSeconds
                    display: page.humanInterval(page.settings.intervalSeconds)

                    // Moved writes the value so the readout tracks the drag;
                    // only the release goes near systemd.
                    onMoved: value => page.settings.intervalSeconds = value
                    onCommitted: value => {
                        page.settings.intervalSeconds = value;
                        page.wallpaper.apply();
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Shuffle"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                    visible: page.slideshow
                }

                Toggle {
                    theme: page.theme
                    Layout.alignment: Qt.AlignRight
                    visible: page.slideshow
                    checked: page.settings.shuffle

                    onToggled: value => {
                        page.settings.shuffle = value;
                        page.wallpaper.apply();
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    implicitHeight: 1
                    color: Qt.rgba(page.theme.fg.r, page.theme.fg.g, page.theme.fg.b, 0.1)
                }

                // ── Transition ─────────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    text: "Transition"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                }

                Select {
                    theme: page.theme
                    popupLayer: page.popupLayer
                    Layout.alignment: Qt.AlignRight
                    model: page.wallpaper.transitions.map(name => page.wallpaper.transitionLabel(name))
                    currentIndex: Math.max(0, page.wallpaper.transitions.indexOf(page.settings.transition))

                    onActivated: index => {
                        page.settings.transition = page.wallpaper.transitions[index];
                        page.wallpaper.apply();
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Transition length"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                }

                Slider {
                    theme: page.theme
                    Layout.alignment: Qt.AlignRight
                    from: 0.3
                    to: 4
                    stepSize: 0.1
                    value: page.settings.transitionDuration
                    display: page.settings.transitionDuration.toFixed(1) + "s"

                    onMoved: value => page.settings.transitionDuration = value
                    onCommitted: value => {
                        page.settings.transitionDuration = value;
                        page.wallpaper.apply();
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    text: "awww renders the transition on the CPU, so the frame rate is worth matching to the panel — the default 30 is visibly steppy above 60Hz."
                    color: page.theme.dim
                    font.family: page.theme.fontFamily
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    text: "Transition frame rate"
                    color: page.theme.fg
                    font.family: page.theme.fontFamily
                    font.pixelSize: 12
                }

                Slider {
                    theme: page.theme
                    Layout.alignment: Qt.AlignRight
                    from: 30
                    to: 240
                    stepSize: 10
                    value: page.settings.transitionFps
                    display: page.settings.transitionFps + " fps"

                    onMoved: value => page.settings.transitionFps = value
                    onCommitted: value => {
                        page.settings.transitionFps = value;
                        page.wallpaper.apply();
                    }
                }
            }
        }

        // ── Footer ─────────────────────────────────────────────────────
        // No Apply here, deliberately — see the note at the top of the file.
        // The one button is "show me a different one now", which is a request
        // and not a commit.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.wallpaper.status
                color: page.wallpaper.failed ? page.theme.bad : page.theme.dim
                font.family: page.theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Button {
                theme: page.theme
                label: "Next wallpaper"
                visible: page.slideshow
                onTriggered: page.wallpaper.skip()
            }
        }
    }

    PathBrowser {
        id: picker

        theme: page.theme
        popupLayer: page.popupLayer

        onAccepted: path => {
            if (picker.mode === "directory")
                page.settings.directory = path;
            else
                page.settings.image = path;
            page.wallpaper.apply();
        }
    }
}
