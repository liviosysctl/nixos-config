import QtQuick
import QtQuick.Layouts

// A dropdown wearing the bar's glass. QtQuick.Controls' ComboBox would need a
// full style written for it before it stopped looking like a stock Qt widget
// sitting in the middle of everything else here, so this is that style's
// worth of code spent directly instead.
//
// The open list is drawn into `layer` rather than as a child, because a list
// nested in the settings window's ColumnLayout would be clipped by it and
// would push the rows below it down. `layer` is an Item covering the whole
// window that SettingsWindow keeps on top for exactly this.
Item {
    id: select

    required property var theme
    required property Item popupLayer

    property var model: []
    property int currentIndex: 0

    // Item.enabled is the one being read below rather than a property of our
    // own: it already gates every MouseArea underneath for free, and
    // redeclaring it shadows the base member instead of replacing it.

    signal activated(int index)

    readonly property string currentText: select.model[select.currentIndex] ?? ""
    readonly property bool open: list.visible

    implicitWidth: 168
    implicitHeight: 32

    function close() {
        list.visible = false;
    }

    function toggle() {
        if (list.visible) {
            list.visible = false;
            return;
        }
        // Placed once, on the way open, rather than bound. mapToItem is a
        // plain call and not a binding: it would be evaluated once and then
        // never again, leaving the list wherever the field happened to be
        // during startup. Native menus hold still once open anyway, and this
        // list closes on any click outside it.
        list.place();
        list.visible = true;
    }

    // ── Field ──────────────────────────────────────────────────────────
    Rectangle {
        id: field

        anchors.fill: parent
        radius: 9
        color: select.enabled && (pointer.containsMouse || select.open) ? Qt.rgba(select.theme.fg.r, select.theme.fg.g, select.theme.fg.b, 0.14) : Qt.rgba(select.theme.fg.r, select.theme.fg.g, select.theme.fg.b, 0.07)
        border.width: 1
        border.color: select.open ? Qt.rgba(select.theme.accent.r, select.theme.accent.g, select.theme.accent.b, 0.55) : Qt.rgba(1, 1, 1, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 9
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: select.currentText
                color: select.enabled ? select.theme.fg : select.theme.dim
                font.family: select.theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: "⌄"
                color: select.theme.dim
                font.family: select.theme.fontFamily
                font.pixelSize: 13
                // The glyph sits low in its own line box; nudging it up is
                // cheaper than finding a chevron that does not.
                Layout.topMargin: -5
                rotation: select.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: select.toggle()
        }
    }

    // ── List ───────────────────────────────────────────────────────────
    Item {
        id: list

        parent: select.popupLayer
        visible: false
        z: 100

        // Set by place(), which runs just before the list is shown.
        property bool above: false

        width: select.width
        height: sheet.height

        function place() {
            const origin = select.mapToItem(select.popupLayer, 0, select.height + 4);
            // Flipped above the field when there is no room below it, which
            // is what keeps the bottom row's list on screen.
            list.above = origin.y + sheet.height > select.popupLayer.height;
            list.x = origin.x;
            list.y = list.above ? origin.y - select.height - sheet.height - 8 : origin.y;
        }

        onVisibleChanged: if (list.visible)
            reveal.restart()

        // Clicking anywhere else closes the list. It covers the window rather
        // than the list, so it has to sit behind the sheet.
        MouseArea {
            parent: select.popupLayer
            anchors.fill: parent
            visible: list.visible
            z: 99
            onClicked: list.visible = false
        }

        Rectangle {
            id: sheet

            width: parent.width
            height: Math.min(entries.implicitHeight + 8, 260)
            radius: 10

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: select.theme.edgeTop
                }

                GradientStop {
                    position: 1
                    color: select.theme.edgeBottom
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: select.theme.menuSurface
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 4
                contentHeight: entries.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: entries

                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: select.model

                        delegate: Rectangle {
                            id: option

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 7
                            color: option.index === select.currentIndex ? Qt.rgba(select.theme.accent.r, select.theme.accent.g, select.theme.accent.b, 0.22) : (optionHover.containsMouse ? Qt.rgba(select.theme.fg.r, select.theme.fg.g, select.theme.fg.b, 0.12) : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                text: option.modelData
                                color: select.theme.fg
                                font.family: select.theme.fontFamily
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: optionHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    list.visible = false;
                                    // Emitted even when the index is
                                    // unchanged: a resolution reselect still
                                    // has to re-derive the rate list.
                                    select.activated(option.index);
                                }
                            }
                        }
                    }
                }
            }
        }

        ParallelAnimation {
            id: reveal

            NumberAnimation {
                target: sheet
                property: "opacity"
                from: 0
                to: 1
                duration: 110
            }

            NumberAnimation {
                target: sheet
                property: "y"
                from: list.above ? 6 : -6
                to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
}
