import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.plugins

ContentPage {
    id: root
    forceWidth: true

    ContentSection {
        title: Translation.tr("Available Plugins")
        Layout.fillWidth: true
        icon: "extension"
        shape: MaterialShape.Shape.Diamond

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: PluginManager.availablePlugins

                ColumnLayout {
                    id: pluginGroup
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: configSwitch.implicitHeight + 16
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.normal

                        ConfigSwitch {
                            id: configSwitch
                            anchors.fill: parent
                            anchors.margins: 8

                            property var modelData: pluginGroup.modelData
                            text: modelData.name
                            description: modelData.description || ""

                            property bool isEnabled: Config.options.plugins.enabled.includes(modelData.id)
                            checked: isEnabled
                            onCheckedChanged: {
                                let newList = [];
                                for (let i = 0; i < Config.options.plugins.enabled.length; i++) {
                                    newList.push(Config.options.plugins.enabled[i]);
                                }
                                if (checked && !isEnabled) {
                                    newList.push(modelData.id);
                                } else if (!checked && isEnabled) {
                                    newList = newList.filter(id => id !== modelData.id);
                                }
                                Config.setNestedValue("plugins.enabled", newList);
                            }
                        }
                    }

                    GroupedList {
                        Layout.fillWidth: true
                        visible: configSwitch.checked

                        PluginOptions {
                            manifest: pluginGroup.modelData
                        }
                    }
                }
            }
        }
    }
}
