pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

ColumnLayout {
    id: root

    required property var manifest
    spacing: Appearance.spacing.unsharpen

    readonly property var optionRows: [{
        key: "blurEnabled",
        type: "boolean",
        label: "Blur background",
        icon: "blur_on",
        default: manifest.desktopWidget?.blur === true
    }].concat(manifest.options || [])

    Repeater {
        model: root.optionRows

        Loader {
            id: optionLoader
            required property var modelData
            Layout.fillWidth: true
            property var optionData: modelData

            sourceComponent: {
                switch (optionData.type) {
                case "boolean": return booleanOption;
                case "choice": return choiceOption;
                case "number": return numberOption;
                default: return null;
                }
            }

            Component {
                id: booleanOption
                ConfigSwitch {
                    Layout.fillWidth: true
                    leftPadding: 0
                    rightPadding: 0
                    buttonIcon: optionLoader.optionData.icon || "tune"
                    text: optionLoader.optionData.label
                    checked: PluginState.option(root.manifest.id, optionLoader.optionData.key, optionLoader.optionData.default)
                    onCheckedChanged: {
                        if (checked !== PluginState.option(root.manifest.id, optionLoader.optionData.key, optionLoader.optionData.default))
                            PluginState.setOption(root.manifest.id, optionLoader.optionData.key, checked);
                    }
                }
            }

            Component {
                id: choiceOption
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    text: optionLoader.optionData.label
                    icon: optionLoader.optionData.icon || "tune"
                    options: optionLoader.optionData.choices || []
                    currentValue: PluginState.option(root.manifest.id, optionLoader.optionData.key, optionLoader.optionData.default)
                    onSelected: value => PluginState.setOption(root.manifest.id, optionLoader.optionData.key, value)
                }
            }

            Component {
                id: numberOption
                ConfigSlider {
                    Layout.fillWidth: true
                    text: optionLoader.optionData.label
                    buttonIcon: optionLoader.optionData.icon || "tune"
                    usePercentTooltip: false
                    from: optionLoader.optionData.from ?? 0
                    to: optionLoader.optionData.to ?? 100
                    value: PluginState.option(root.manifest.id, optionLoader.optionData.key, optionLoader.optionData.default)
                    onValueChanged: {
                        const step = optionLoader.optionData.step ?? 1;
                        const rounded = Math.round(value / step) * step;
                        if (rounded !== PluginState.option(root.manifest.id, optionLoader.optionData.key, optionLoader.optionData.default))
                            PluginState.setOption(root.manifest.id, optionLoader.optionData.key, rounded);
                    }
                }
            }
        }
    }
}
