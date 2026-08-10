import QtQuick

// A small integer field, for the positions that are easier typed than dragged.
//
// The text is only pushed back out to `value` once it parses, so half-typed
// input like "-" or "" cannot momentarily move a monitor to zero.
Rectangle {
    id: field

    required property var theme

    property int value: 0
    property string label: ""

    signal edited(int value)

    implicitWidth: 84
    implicitHeight: 32
    radius: 9

    color: input.activeFocus ? Qt.rgba(field.theme.fg.r, field.theme.fg.g, field.theme.fg.b, 0.16) : Qt.rgba(field.theme.fg.r, field.theme.fg.g, field.theme.fg.b, 0.07)
    border.width: 1
    border.color: input.activeFocus ? Qt.rgba(field.theme.accent.r, field.theme.accent.g, field.theme.accent.b, 0.55) : Qt.rgba(1, 1, 1, 0.08)

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Text {
        id: prefix

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        text: field.label
        color: field.theme.dim
        font.family: field.theme.fontFamily
        font.pixelSize: 12
    }

    TextInput {
        id: input

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: prefix.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 10

        text: field.value.toString()
        color: field.theme.fg
        font.family: field.theme.fontFamily
        font.pixelSize: 12
        selectByMouse: true
        selectionColor: Qt.rgba(field.theme.accent.r, field.theme.accent.g, field.theme.accent.b, 0.4)
        validator: IntValidator {
            bottom: -32768
            top: 32767
        }

        onTextEdited: {
            const parsed = parseInt(input.text, 10);
            if (isFinite(parsed))
                field.edited(parsed);
        }

        // Whatever the field settled on, shown back cleanly — "007" and "" both
        // become the number they meant.
        onEditingFinished: input.text = field.value.toString()
    }
}
