import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick

// The tray: one icon per background app that has registered a
// StatusNotifierItem. Everything waybar's #tray does — activate, secondary
// activate, scroll and the app's own right-click menu — wearing the same
// glass the rest of the bar wears.
Row {
    id: widget

    required property var theme

    // The item whose menu is up, and the icon it hangs off. Held here rather
    // than on the delegate because the popup has to outlive any one delegate:
    // the Repeater rebuilds them all whenever an app registers or exits.
    property var menuItem: null
    property var tipItem: null

    spacing: 2

    function showMenu(anchorItem, item) {
        if (widget.menuItem === item && menuPopup.visible) {
            menuPopup.visible = false;
            widget.menuItem = null;
            return;
        }
        // Re-anchoring a popup that is already up leaves it stranded at the
        // old position, so it goes down before it moves.
        menuPopup.visible = false;
        widget.menuItem = item;
        menuPopup.anchor.item = anchorItem;
        menuPopup.visible = true;
    }

    function showTip(anchorItem, item) {
        // The menu covers the same ground and says more.
        if (menuPopup.visible)
            return;
        // Same reason as showMenu: moving a popup that is already up leaves
        // it stranded at the old anchor.
        tipPopup.visible = false;
        widget.tipItem = item;
        tipPopup.anchor.item = anchorItem;
        // Plenty of items set neither field, and an empty bubble is worse
        // than none.
        tipPopup.visible = tipLabel.text !== "";
    }

    function hideTip(item) {
        if (widget.tipItem === item)
            tipPopup.visible = false;
    }

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: entry

            required property var modelData

            readonly property bool current: menuPopup.visible && widget.menuItem === entry.modelData

            implicitWidth: 26
            implicitHeight: 26
            radius: widget.theme.pillRadius
            color: pointer.containsMouse || entry.current ? Qt.rgba(widget.theme.fg.r, widget.theme.fg.g, widget.theme.fg.b, 0.12) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            IconImage {
                anchors.centerIn: parent
                // waybar asks for 20; 18 leaves the hover pill a visible
                // margin at this bar height.
                implicitSize: 18
                source: entry.modelData.icon
                asynchronous: true
            }

            // Apps that want attention say so through the SNI status, and it
            // is the only thing in the tray worth colouring.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 3
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: widget.theme.bad
                visible: entry.modelData.status === Status.NeedsAttention
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: mouse => {
                    // An onlyMenu item advertises no activate action at all,
                    // so its menu is the only thing a left click can usefully
                    // reach.
                    if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu)
                        widget.showMenu(entry, entry.modelData);
                    else if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else
                        entry.modelData.activate();
                }

                onWheel: wheel => {
                    // Passed through raw: SNI consumers expect the eighths of
                    // a degree that angleDelta already reports.
                    if (wheel.angleDelta.y !== 0)
                        entry.modelData.scroll(wheel.angleDelta.y, false);
                    if (wheel.angleDelta.x !== 0)
                        entry.modelData.scroll(wheel.angleDelta.x, true);
                }

                onEntered: dwell.restart()

                onExited: {
                    dwell.stop();
                    widget.hideTip(entry.modelData);
                }
            }

            // Pointing at the tray on the way to somewhere else should not
            // flash a tooltip, so it has to be a deliberate hover.
            Timer {
                id: dwell

                interval: 500
                onTriggered: widget.showTip(entry, entry.modelData)
            }
        }
    }

    // ── Tooltip ────────────────────────────────────────────────────────
    PopupWindow {
        id: tipPopup

        anchor.rect.y: 26 + 7
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: tipLabel.implicitWidth + 20
        implicitHeight: tipLabel.implicitHeight + 14
        color: "transparent"
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: 8

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: widget.theme.edgeTop
                }

                GradientStop {
                    position: 1
                    color: widget.theme.edgeBottom
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 7
                color: widget.theme.cardSurface
            }
        }

        Text {
            id: tipLabel

            anchors.centerIn: parent
            // tooltipTitle is what the spec means by a tooltip; plenty of
            // apps leave it empty and only set the window title.
            text: widget.tipItem?.tooltipTitle || widget.tipItem?.title || ""
            color: widget.theme.fg
            font.family: widget.theme.fontFamily
            font.pixelSize: 12
        }
    }

    // ── Menu ───────────────────────────────────────────────────────────
    PopupWindow {
        id: menuPopup

        anchor.rect.y: 26 + 7
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: sheet.implicitWidth
        implicitHeight: sheet.implicitHeight
        color: "transparent"

        // Lets the compositor dismiss the menu on an outside click, the same
        // way the media and connectivity cards are dismissed.
        grabFocus: true
        visible: false

        onVisibleChanged: if (!menuPopup.visible)
            widget.menuItem = null

        TrayMenu {
            id: sheet

            theme: widget.theme
            handle: widget.menuItem?.menu ?? null
            // Submenus watch this so none of them can outlive the root menu.
            open: menuPopup.visible

            focus: true
            Keys.onEscapePressed: menuPopup.visible = false

            onDismissed: menuPopup.visible = false
        }
    }
}
