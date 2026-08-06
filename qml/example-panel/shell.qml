import Quickshell
import QtQuick

// Minimal shell used to prove the toolchain works. Run it with `qs-dev
// example-panel` while editing, or `qs-example-panel` for the built copy.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 28
            color: "#1a1b26"

            // Reserve no space, so this floats over waybar instead of
            // shoving the whole layout down while you are testing.
            exclusiveZone: 0

            Text {
                id: clock
                anchors.centerIn: parent
                color: "#c0caf5"
                font.pixelSize: 14
                text: Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm:ss")
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm:ss")
            }
        }
    }
}
