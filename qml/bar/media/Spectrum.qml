import QtQuick

// cava-style bar spectrum. Purely a renderer — it draws whatever array of
// 0..1 floats it is handed, so the same component works in the bar and in
// the expanded card at different sizes.
Item {
    id: root

    property var values: []
    property color color: "#7aa2f7"
    property real barWidth: 3
    property real barSpacing: 2
    // Bars never fully collapse: an idle visualiser should read as a
    // baseline, not as a hole in the bar.
    property real minHeight: 2

    readonly property int count: root.values.length

    implicitWidth: count > 0 ? count * barWidth + (count - 1) * barSpacing : 0
    implicitHeight: 16

    Repeater {
        model: root.count

        // Placed by hand instead of with a Row: a Row would only set x
        // anyway, and this keeps the bottom alignment explicit.
        delegate: Rectangle {
            required property int index

            x: index * (root.barWidth + root.barSpacing)
            y: root.height - height
            width: root.barWidth
            height: Math.max(root.minHeight, (root.values[index] ?? 0) * root.height)
            radius: root.barWidth / 2

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(root.color, 1.4)
                }
                GradientStop {
                    position: 1
                    color: root.color
                }
            }

            // cava emits 30 frames a second; easing between them turns the
            // steps into a slide without adding perceptible lag.
            Behavior on height {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
