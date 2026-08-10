import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// One level of a tray item's DBusMenu, drawn as a glass sheet. Submenus open
// another one of these beside the row that owns them, which is why this file
// loads itself through a Loader further down: QML treats a component that
// names itself as a cycle and refuses it, but it will load one by filename.
//
// Nothing here is a `required property`, unlike the rest of the bar's
// widgets. Loader cannot satisfy those, and the submenu path has no other way
// to hand values to a component it creates by URL.
Item {
    id: sheet

    property var theme: null
    // A QsMenuHandle: a tray item's `menu`, or an entry that `hasChildren`.
    property var handle: null

    // False once the popup hosting this sheet is down. Submenus watch it so
    // they cannot outlive the menu they belong to.
    property bool open: true

    // Which row has its submenu showing, if any. One index rather than a flag
    // per row, so opening a second submenu closes the first for free.
    property int openIndex: -1

    // Raised when an entry is activated, so the whole chain of menus goes down
    // together instead of leaving parents on screen.
    signal dismissed

    readonly property int padding: 6
    readonly property int rowHeight: 28

    // Sized to the widest label, within reason — tray menus range from
    // "Quit" to a full account list.
    implicitWidth: Math.max(180, Math.min(380, rows.implicitWidth + sheet.padding * 2))
    implicitHeight: rows.implicitHeight + sheet.padding * 2

    onOpenChanged: if (!sheet.open)
        sheet.openIndex = -1;

    // Asking for the children is what makes the app populate them: DBusMenu is
    // lazy, and the layout only arrives after an AboutToShow.
    QsMenuOpener {
        id: opener

        menu: sheet.handle
    }

    // ── Surface ────────────────────────────────────────────────────────
    // The bar's glass at the cards' opacity: a gradient rectangle standing in
    // for the lit edge, with the fill inset one pixel inside it.
    Rectangle {
        anchors.fill: parent
        radius: 12

        gradient: Gradient {
            GradientStop {
                position: 0
                color: sheet.theme.edgeTop
            }

            GradientStop {
                position: 0.5
                color: sheet.theme.edgeSide
            }

            GradientStop {
                position: 1
                color: sheet.theme.edgeBottom
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
            color: sheet.theme.cardSurface
        }
    }

    ColumnLayout {
        id: rows

        anchors.fill: parent
        anchors.margins: sheet.padding
        spacing: 0

        Repeater {
            model: opener.children

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool separator: row.modelData?.isSeparator ?? false
                readonly property bool submenu: row.modelData?.hasChildren ?? false
                readonly property bool actionable: !row.separator && (row.modelData?.enabled ?? false)

                Layout.fillWidth: true
                implicitWidth: line.implicitWidth + 16
                implicitHeight: row.separator ? 7 : sheet.rowHeight

                // ── Separator ──────────────────────────────────────────
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 6
                    implicitHeight: 1
                    color: Qt.rgba(sheet.theme.fg.r, sheet.theme.fg.g, sheet.theme.fg.b, 0.14)
                    visible: row.separator
                }

                // ── Entry ──────────────────────────────────────────────
                Rectangle {
                    id: entry

                    anchors.fill: parent
                    radius: 8
                    color: (hover.containsMouse && row.actionable) || sheet.openIndex === row.index ? Qt.rgba(sheet.theme.fg.r, sheet.theme.fg.g, sheet.theme.fg.b, 0.12) : "transparent"
                    visible: !row.separator

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    RowLayout {
                        id: line

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Check and radio state. Plain Unicode rather than
                        // nerd glyphs — these sit next to app-supplied text,
                        // which is rendered in whatever the theme font is.
                        Text {
                            Layout.preferredWidth: 12
                            text: {
                                const type = row.modelData?.buttonType ?? QsMenuButtonType.None;
                                const on = row.modelData?.checkState === Qt.Checked;
                                if (type === QsMenuButtonType.CheckBox)
                                    return on ? "✓" : "";
                                if (type === QsMenuButtonType.RadioButton)
                                    return on ? "●" : "○";
                                return "";
                            }
                            color: sheet.theme.accent
                            font.family: sheet.theme.fontFamily
                            font.pixelSize: 12
                            visible: (row.modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                        }

                        IconImage {
                            id: entryIcon

                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            implicitSize: 16
                            source: row.modelData?.icon ?? ""
                            asynchronous: true
                            // An app can always name an icon no installed
                            // theme carries. Collapsing beats reserving 16px
                            // for nothing and leaving the label indented out
                            // of line with its neighbours.
                            visible: entryIcon.source !== "" && entryIcon.status !== Image.Error
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData?.text ?? ""
                            color: row.actionable ? sheet.theme.fg : sheet.theme.dim
                            font.family: sheet.theme.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "›"
                            color: sheet.theme.dim
                            font.family: sheet.theme.fontFamily
                            font.pixelSize: 14
                            visible: row.submenu
                        }
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.actionable
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (row.submenu) {
                                sheet.openIndex = sheet.openIndex === row.index ? -1 : row.index;
                                return;
                            }
                            row.modelData.triggered();
                            sheet.dismissed();
                        }
                    }
                }

                // A submenu opens beside its row. Loader.active tears the
                // nested sheet down when it closes, which is also what stops
                // a submenu surviving its parent.
                PopupWindow {
                    anchor.item: entry
                    anchor.rect.x: entry.width + 4
                    anchor.gravity: Edges.Right | Edges.Bottom
                    anchor.adjustment: PopupAdjustment.SlideX

                    implicitWidth: nested.item?.implicitWidth ?? 1
                    implicitHeight: nested.item?.implicitHeight ?? 1
                    color: "transparent"
                    visible: sheet.open && sheet.openIndex === row.index

                    Loader {
                        id: nested

                        // By filename, not by type name: naming the enclosing
                        // component here is the cycle QML refuses to load.
                        source: "TrayMenu.qml"
                        active: sheet.openIndex === row.index

                        onLoaded: {
                            nested.item.theme = sheet.theme;
                            nested.item.handle = row.modelData;
                            // Activating anything at any depth closes the lot.
                            nested.item.dismissed.connect(sheet.dismissed);
                        }
                    }
                }
            }
        }
    }
}
