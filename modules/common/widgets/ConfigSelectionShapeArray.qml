import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flow {
    id: root
    Layout.fillWidth: true
    spacing: 2

    property list<string> options: []
    property var currentValue: null
    property color shapeColor: Appearance.colors.colPrimaryContainer
    property color backgroundColor: Appearance.colors.colLayer1

    signal selected(var newValue)

    Repeater {
        model: root.options
        delegate: GroupButton {
            id: shapeButton
            required property string modelData
            required property int index

            property bool leftmost: index === 0
            property bool rightmost: index === root.options.length - 1

            bounce: false
            toggled: root.currentValue === modelData
            leftRadius: (toggled || leftmost) ? (height / 2) : Appearance.rounding.unsharpenmore
            rightRadius: (toggled || rightmost) ? (height / 2) : Appearance.rounding.unsharpenmore
            horizontalPadding: 12
            verticalPadding: 8
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colBackgroundActive: Appearance.colors.colSecondaryContainerActive

            onYChanged: {
                if (index === 0) {
                    shapeButton.leftmost = true
                } else {
                    var prev = root.children[index - 1]
                    var thisIsOnNewLine = prev && prev.y !== shapeButton.y
                    shapeButton.leftmost = thisIsOnNewLine
                    prev.rightmost = thisIsOnNewLine
                }
            }

            contentItem: MaterialShape {
                implicitSize: Appearance.font.pixelSize.larger
                shape: ShapeUtils.getShape(shapeButton.modelData)
                color: shapeButton.toggled
                    ? Appearance.colors.colOnPrimary
                    : root.shapeColor
                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }

            onClicked: root.selected(shapeButton.modelData)
        }
    }
}