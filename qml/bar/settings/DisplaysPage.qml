import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// The Displays page, in two halves: the outputs laid out to scale up top, and
// the settings for whichever one is selected underneath.
//
// Nothing is applied as you pick it. A wrong mode can leave a screen dark, and
// a panel that has already committed the change is one you cannot see well
// enough to undo it — so edits stay a draft until Apply, and Revert throws
// them away.
Item {
    id: page

    required property var theme
    required property var displays
    // Where the dropdowns draw their open lists. See Select.qml.
    required property Item popupLayer

    property int selectedIndex: 0

    // The drafts, as a plain array so bindings can depend on it. Instantiator
    // exposes objectAt() rather than a property, and a binding cannot depend
    // on a function call, so the list is rebuilt whenever the set changes.
    property var draftList: []

    readonly property var selected: page.draftList[page.selectedIndex] ?? null

    // Bumped by every draft whenever its dirty flag moves. `anyDirty` reads it
    // purely to take the dependency: the drafts are not visual children, so
    // there is nothing else here for a binding to watch. A counter would work
    // too until it drifted; recomputing cannot drift.
    property int revision: 0

    readonly property bool anyDirty: {
        const _ = page.revision;
        return page.draftList.some(draft => draft.dirty);
    }

    function rebuildDrafts() {
        const list = [];
        for (let i = 0; i < drafts.count; i++)
            list.push(drafts.objectAt(i));
        page.draftList = list;
        if (page.selectedIndex >= list.length)
            page.selectedIndex = 0;
    }

    function applyAll() {
        page.displays.apply(page.draftList.map(draft => draft.entry()));
    }

    function revertAll() {
        for (const draft of page.draftList)
            draft.resync();
    }

    Instantiator {
        id: drafts

        model: Hyprland.monitors

        delegate: MonitorDraft {
            required property var modelData

            monitor: modelData
            displays: page.displays

            onDirtyChanged: page.revision++
        }

        onObjectAdded: page.rebuildDrafts()
        onObjectRemoved: page.rebuildDrafts()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Displays"
            color: page.theme.fg
            font.family: page.theme.fontFamily
            font.bold: true
            font.pixelSize: 17
        }

        // ── Layout ─────────────────────────────────────────────────────
        MonitorCanvas {
            id: layout

            Layout.fillWidth: true
            // Fixed rather than proportional: the detail pane below has a
            // natural height, and letting the canvas take the rest makes it
            // grow every time a section is added down there.
            Layout.preferredHeight: 190

            theme: page.theme
            drafts: page.draftList
            selectedIndex: page.selectedIndex
            onSelected: index => page.selectedIndex = index
        }

        Text {
            Layout.fillWidth: true
            text: "Click to select · drag to arrange · edges snap to neighbours"
            color: page.theme.dim
            font.family: page.theme.fontFamily
            font.pixelSize: 10
        }

        // ── Selected output ────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: detail.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: detail

                width: parent.width
                spacing: 10
                visible: page.selected !== null

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10

                    Text {
                        text: page.selected?.name ?? ""
                        color: page.theme.fg
                        font.family: page.theme.fontFamily
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.selected?.description ?? ""
                        color: page.theme.dim
                        font.family: page.theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "modified"
                        color: page.theme.accent
                        font.family: page.theme.fontFamily
                        font.pixelSize: 10
                        opacity: (page.selected?.dirty ?? false) ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.selected ? `Currently ${page.selected.liveResolution} · ${page.displays.rateLabel(page.selected.liveRate)} · ${page.displays.scaleLabel(page.selected.liveScale)} · at ${page.selected.liveX},${page.selected.liveY}` : ""
                    color: page.theme.dim
                    font.family: page.theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 10

                    // Labels take Layout.fillWidth so the control column lands
                    // against the pane's right edge rather than floating.
                    Text {
                        Layout.fillWidth: true
                        text: "Resolution"
                        color: page.theme.fg
                        font.family: page.theme.fontFamily
                        font.pixelSize: 12
                    }

                    Select {
                        theme: page.theme
                        popupLayer: page.popupLayer
                        model: page.selected?.resolutions ?? []
                        currentIndex: page.selected?.resolutionIndex ?? 0
                        Layout.alignment: Qt.AlignRight

                        onActivated: index => {
                            if (!page.selected)
                                return;
                            page.selected.resolutionIndex = index;
                            // Both the rate and scale lists are derived from
                            // the resolution, so the old indices mean nothing.
                            page.selected.rateIndex = 0;
                            page.selected.scaleIndex = 0;
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Refresh rate"
                            color: (page.selected?.rateFixed ?? true) ? page.theme.fg : page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: "Variable — set by the display, up to the mode's maximum"
                            color: page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 10
                            visible: !(page.selected?.rateFixed ?? true)
                        }
                    }

                    Select {
                        theme: page.theme
                        popupLayer: page.popupLayer
                        model: (page.selected?.rates ?? []).map(rate => page.displays.rateLabel(rate))
                        // Index 0 is the highest rate, which is what VRR runs
                        // up to and what the draft writes while it is on.
                        currentIndex: (page.selected?.rateFixed ?? true) ? (page.selected?.rateIndex ?? 0) : 0
                        // Dead only under "Always", where there is no fixed
                        // rate left to choose. Fullscreen-only VRR leaves the
                        // desktop at a rate you picked, so it stays live.
                        enabled: page.selected?.rateFixed ?? true
                        Layout.alignment: Qt.AlignRight
                        onActivated: index => {
                            if (page.selected)
                                page.selected.rateIndex = index;
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Scale"
                        color: page.theme.fg
                        font.family: page.theme.fontFamily
                        font.pixelSize: 12
                    }

                    Select {
                        theme: page.theme
                        popupLayer: page.popupLayer
                        model: (page.selected?.scales ?? []).map(scale => page.displays.scaleLabel(scale))
                        currentIndex: page.selected?.scaleIndex ?? 0
                        Layout.alignment: Qt.AlignRight
                        onActivated: index => {
                            if (page.selected)
                                page.selected.scaleIndex = index;
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Position"
                            color: page.theme.fg
                            font.family: page.theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: "Top-left corner, in logical pixels"
                            color: page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8

                        // Through the canvas rather than straight onto the
                        // draft, so a typed position is held to the same
                        // bounds a dragged one is.
                        NumberField {
                            theme: page.theme
                            label: "X"
                            value: page.selected?.x ?? 0
                            onEdited: next => {
                                if (page.selected)
                                    layout.place(page.selected, next, page.selected.y);
                            }
                        }

                        NumberField {
                            theme: page.theme
                            label: "Y"
                            value: page.selected?.y ?? 0
                            onEdited: next => {
                                if (page.selected)
                                    layout.place(page.selected, page.selected.x, next);
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Variable refresh rate"
                            color: (page.selected?.vrrSupported ?? true) ? page.theme.fg : page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: (page.selected?.vrrSupported ?? true) ? "FreeSync / G-Sync. Applies the next time Hyprland starts." : "This display does not report adaptive sync support."
                            color: page.theme.dim
                            font.family: page.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    Select {
                        theme: page.theme
                        popupLayer: page.popupLayer
                        model: (page.selected?.vrrModes ?? []).map(mode => mode.label)
                        currentIndex: page.selected?.vrrIndex ?? 0
                        // Greyed for a display whose DRM connector says it
                        // cannot do adaptive sync. See vrrcap.sh — an output
                        // the script has no answer for stays switchable.
                        enabled: page.selected?.vrrSupported ?? true
                        Layout.alignment: Qt.AlignRight
                        onActivated: index => {
                            if (page.selected)
                                page.selected.vrrIndex = index;
                        }
                    }
                }
            }
        }

        // ── Footer ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.displays.status
                color: page.displays.failed ? page.theme.bad : page.theme.dim
                font.family: page.theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Button {
                theme: page.theme
                label: "Revert"
                enabled: page.anyDirty && !page.displays.busy
                onTriggered: page.revertAll()
            }

            Button {
                theme: page.theme
                label: page.displays.busy ? "Applying…" : "Apply"
                primary: true
                enabled: page.anyDirty && !page.displays.busy
                onTriggered: page.applyAll()
            }
        }
    }
}
