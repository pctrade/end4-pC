import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.services

RowLayout {
    id: root
    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    property string text: ""
    property string buttonIcon: ""
    property alias value: slider.value
    property alias stopIndicatorValues: slider.stopIndicatorValues
    property alias sliderPressed: slider.pressed
    property bool usePercentTooltip: true
    property bool animateValue: true
    property bool liveUpdate: true
    signal committed(real value)
    property real from: slider.from
    property real to: slider.to
    property real stepSize: 0
    property real textWidth: 120
    property bool showLabel: true
    property bool showValue: false

    readonly property string valueDisplayText: {
        const v = root.value
        if (Math.abs(v - Math.round(v)) < 1e-4) return String(Math.round(v))
        return String(Math.round(v * 100) / 100)
    }

    RowLayout {
        id: row
        visible: root.showLabel
        spacing: 10

        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
        }
        StyledText {
            id: labelWidget
            Layout.preferredWidth: root.textWidth
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
    StyledSlider {
        id: slider
        configuration: StyledSlider.Configuration.XS
        usePercentTooltip: root.usePercentTooltip
        animateValue: root.animateValue
        stepSizeOverride: root.stepSize
        value: root.value
        from: root.from
        to: root.to
        onPressedChanged: {
            if (!root.liveUpdate && !slider.pressed)
                root.committed(slider.value)
        }
    }

    RowLayout {
        id: valueEdit
        property bool editing: false
        visible: root.showValue
        Layout.preferredWidth: 64
        Layout.preferredHeight: 26
        Layout.leftMargin: 6
        spacing: 0

        function startEditing() {
            valueEdit.editing = true
            valueInput.text = root.valueDisplayText
            valueInput.forceActiveFocus()
            valueInput.selectAll()
        }

        function commit() {
            let n = parseFloat(valueInput.text.replace(/,/g, ".").replace(/%/g, ""))
            if (!isNaN(n)) {
                n = Math.min(root.to, Math.max(root.from, n))
                root.value = n
                if (!root.liveUpdate) root.committed(n)
            }
            valueEdit.editing = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: valueEdit.editing || valueMouse.containsMouse
                ? Appearance.colors.colLayer3
                : Appearance.colors.colLayer2
            border.width: valueEdit.editing ? 1 : 0
            border.color: Appearance.colors.colPrimary
        }

        StyledText {
            id: valueDisplay
            anchors.centerIn: parent
            text: root.valueDisplayText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
            visible: !valueEdit.editing
        }

        TextInput {
            id: valueInput
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
            visible: valueEdit.editing
            clip: true
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            onAccepted: valueEdit.commit()
            onEditingFinished: if (valueEdit.editing) valueEdit.commit()
            Keys.onEscapePressed: valueEdit.editing = false
        }

        MouseArea {
            id: valueMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !valueEdit.editing
            cursorShape: Qt.PointingHandCursor
            onClicked: valueEdit.startEditing()
        }
    }
}