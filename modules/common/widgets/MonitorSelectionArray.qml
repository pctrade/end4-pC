import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell.Hyprland

Flow {
    id: root
    Layout.fillWidth: true
    spacing: 2
    property var currentValue: null
    signal selected(var newValue)

    property var builtOptions: []

    Component.onCompleted: {
        let arr = [{ displayName: Translation.tr("All"), icon: "tv_displays", value: "all" }]
        for (let i = 0; i < Hyprland.monitors.length; i++)
            arr.push({ displayName: Hyprland.monitors[i].name, icon: "monitor", value: Hyprland.monitors[i].name })
        builtOptions = arr
    }

    Repeater {
        model: root.builtOptions
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index
            onYChanged: {
                if (index === 0) {
                    paletteButton.leftmost = true
                } else {
                    var prev = root.children[index - 1]
                    var thisIsOnNewLine = prev && prev.y !== paletteButton.y
                    paletteButton.leftmost = thisIsOnNewLine
                    prev.rightmost = thisIsOnNewLine
                }
            }
            leftmost: index === 0
            rightmost: index === root.builtOptions.length - 1
            buttonIcon: modelData.icon || ""
            buttonText: modelData.displayName
            toggled: root.currentValue == modelData.value
            onClicked: root.selected(modelData.value)
        }
    }
}