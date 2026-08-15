import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

import "../common"

// A file browser for picking a wallpaper, or the directory a slideshow reads.
//
// Shelling out to a portal chooser would drag a GTK dialog into the middle of
// a panel that draws all of its own chrome, and would look it. FolderListModel
// ships with qtdeclarative and gives the listing directly, so this is a couple
// of hundred lines and no new dependency.
//
// Drawn into `popupLayer` rather than as a child of the page, for the same
// reason Select's list is: nested in the page's layout it would be clipped by
// the Flickable and would shove every row below it down.
Item {
    id: browser

    required property var theme
    required property Item popupLayer

    // "image" picks a file, "directory" picks the folder being looked at.
    property string mode: "image"

    property bool open: false

    signal accepted(string path)

    // What a wallpaper can be. Kept in step with the script's own find(1)
    // filter in modules/home/hyprland/wallpaper-slideshow.nix — a directory
    // whose images this browser shows but the slideshow skips would be a
    // confusing thing to hand someone.
    //
    // webp needs qt6.qtimageformats on QT_PLUGIN_PATH, which lib/quickshell.nix
    // puts there; without it these list fine and render as blank thumbnails.
    readonly property var extensions: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]

    parent: browser.popupLayer
    anchors.fill: parent
    visible: browser.open
    z: 200

    function show(startPath) {
        // A path that no longer exists would leave FolderListModel showing an
        // empty folder with no way back, so fall back to home.
        folders.folder = "file://" + (startPath || "");
        browser.open = true;
    }

    function accept(path) {
        browser.accepted(path);
        browser.open = false;
    }

    // ── Model ──────────────────────────────────────────────────────────
    FolderListModel {
        id: folders

        showDirsFirst: true
        // Directory mode still lists images: seeing what is in a folder is
        // most of how you tell whether it is the folder you meant.
        showFiles: true
        showHidden: false
        sortField: FolderListModel.Name
        nameFilters: browser.extensions
    }

    readonly property string currentPath: folders.folder.toString().replace("file://", "")

    // ── Scrim ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)

        MouseArea {
            anchors.fill: parent
            onClicked: browser.open = false
        }
    }

    // ── Sheet ──────────────────────────────────────────────────────────
    Rectangle {
        id: sheet

        anchors.centerIn: parent
        width: Math.min(560, parent.width - 60)
        height: Math.min(440, parent.height - 60)
        radius: 14

        gradient: Gradient {
            GradientStop {
                position: 0
                color: browser.theme.edgeTop
            }

            GradientStop {
                position: 1
                color: browser.theme.edgeBottom
            }
        }

        // Swallows scrim clicks that land on the sheet.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 13
            color: browser.theme.menuSurface
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Where we are ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 9
                    color: upHover.containsMouse ? Qt.rgba(browser.theme.fg.r, browser.theme.fg.g, browser.theme.fg.b, 0.14) : Qt.rgba(browser.theme.fg.r, browser.theme.fg.g, browser.theme.fg.b, 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁞"  // md-arrow_up_thick
                        color: browser.theme.fg
                        font.family: browser.theme.fontFamily
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: upHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: folders.folder = folders.parentFolder
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: browser.currentPath
                    color: browser.theme.fg
                    font.family: browser.theme.fontFamily
                    font.pixelSize: 12
                    // From the left: the tail of a path is what tells you
                    // where you are, and the head is nearly always $HOME.
                    elide: Text.ElideLeft
                }
            }

            // ── Listing ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.18)
                clip: true

                ListView {
                    id: entries

                    anchors.fill: parent
                    anchors.margins: 4
                    model: folders
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row

                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir

                        width: entries.width
                        height: 40
                        radius: 8
                        color: rowHover.containsMouse ? Qt.rgba(browser.theme.fg.r, browser.theme.fg.g, browser.theme.fg.b, 0.1) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 110
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 10
                            spacing: 10

                            // A folder gets a glyph; an image gets itself.
                            // Scrolling a directory of wallpapers by filename
                            // alone is guesswork.
                            Item {
                                implicitWidth: 44
                                implicitHeight: 28

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.fileIsDir
                                    text: "󰉋"  // md-folder
                                    color: browser.theme.accent
                                    font.family: browser.theme.fontFamily
                                    font.pixelSize: 15
                                }

                                Image {
                                    anchors.fill: parent
                                    visible: !row.fileIsDir
                                    source: row.fileIsDir ? "" : "file://" + row.filePath
                                    fillMode: Image.PreserveAspectCrop
                                    // Decoded at thumbnail size rather than
                                    // full: a folder of 4K wallpapers would
                                    // otherwise put a few hundred megabytes
                                    // through the scene graph on scroll.
                                    sourceSize.width: 88
                                    sourceSize.height: 56
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.fileName
                                color: browser.theme.fg
                                font.family: browser.theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: rowHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (row.fileIsDir)
                                    folders.folder = "file://" + row.filePath;
                                else if (browser.mode === "image")
                                    browser.accept(row.filePath);
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: entries.count === 0
                        text: "Nothing here"
                        color: browser.theme.dim
                        font.family: browser.theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            // ── Buttons ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: browser.mode === "image" ? "Click an image to use it" : "Pick the folder to shuffle through"
                    color: browser.theme.dim
                    font.family: browser.theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Button {
                    theme: browser.theme
                    label: "Cancel"
                    onTriggered: browser.open = false
                }

                Button {
                    theme: browser.theme
                    label: "Use this folder"
                    primary: true
                    visible: browser.mode === "directory"
                    onTriggered: browser.accept(browser.currentPath)
                }
            }
        }
    }
}
