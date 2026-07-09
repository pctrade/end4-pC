import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    spacing: 10

    property string icon: "palette"
    property string text: "Color"
    property string currentValue: ""
    property var options: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"]
    signal selected(string newValue)

    MaterialSymbol {
        text: root.icon
        iconSize: Appearance.font.pixelSize.normal + 5
        color: Appearance.colors.colOnLayer1
    }

    StyledText {
        text: root.text
        font.pixelSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colOnLayer1
    }

    Item { Layout.fillWidth: true }

    RowLayout {
        spacing: 10

        Repeater {
            model: root.options
            delegate: Item {
                id: slot
                required property string modelData
                readonly property bool isSelected: root.currentValue === modelData

                implicitWidth: 40
                implicitHeight: 40

                Rectangle {
                    id: ring
                    anchors.centerIn: parent
                    width: slot.isSelected ? parent.width : parent.width - 8
                    height: slot.isSelected ? parent.height : parent.height - 8
                    radius: slot.isSelected ? Appearance.rounding.normal : width / 2
                    color: "transparent"
                    border.width: slot.isSelected ? 2 : 0
                    border.color: Appearance.colors.colOnLayer0

                    Behavior on radius {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on width {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on height {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                Rectangle {
                    id: swatch
                    anchors.centerIn: parent
                    width: slot.isSelected ? parent.width - 8 : parent.width - 8
                    height: slot.isSelected ? parent.height - 8 : parent.height - 8
                    radius: slot.isSelected ? Appearance.rounding.normal - 4 : width / 2 
                    color: Appearance.colors["col" + slot.modelData.charAt(0).toUpperCase() + slot.modelData.slice(1)]

                    Behavior on radius {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(slot.modelData)
                }
            }
        }
    }
}