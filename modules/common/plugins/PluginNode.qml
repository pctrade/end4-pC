import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "bundled/atAGlance" as AtAGlancePlugin

Item {
    id: rootNode
    property var manifestNode
    property string pluginId: ""
    property var optionDefinitions: []

    implicitWidth: componentLoader.item ? (componentLoader.item.implicitWidth || componentLoader.item.width) : 0
    implicitHeight: componentLoader.item ? (componentLoader.item.implicitHeight || componentLoader.item.height) : 0
    width: implicitWidth
    height: implicitHeight

    function resolveBinding(bindingString) {
        switch (bindingString) {
            case "DateTime.time": return DateTime.time;
            case "DateTime.date": return DateTime.date;
            case "DateTime.shortDate": return DateTime.shortDate;
            case "Battery.percentage": return Battery.percentage;
            case "Battery.charging": return Battery.charging;
            case "Battery.pluggedIn": return Battery.pluggedIn;
            case "Network.networkName": return Network.networkName;
            case "Network.primaryIp": return Network.primaryIp;
            case "SystemInfo.cpuUsage": return SystemInfo.cpuUsage;
            case "SystemInfo.ramUsage": return SystemInfo.ramUsage;
            case "Audio.volume": return Audio.volume;
            case "Audio.muted": return Audio.muted;
            case "Docker.runningCount": return Docker.runningCount;
            case "Docker.totalCount": return Docker.totalCount;
            default: return undefined;
        }
    }

    function optionDefinition(propertyName) {
        for (const definition of rootNode.optionDefinitions) {
            if (definition.key === propertyName) return definition;
        }
        return null;
    }

    Loader {
        id: componentLoader
        // No anchors.fill here: rootNode's own size is *derived from* this
        // loaded item's implicit size (see implicitWidth/implicitHeight above),
        // so forcing the Loader to fill rootNode would force the item to match
        // rootNode's size right back - a circular binding ("binding loop
        // detected for property implicitWidth"). Let the Loader mirror the
        // item's natural size instead; explicit width/height come from the
        // manifest's own props (assigned directly onto the item in onLoaded).
        sourceComponent: {
            if (!manifestNode) return null;
            switch(manifestNode.type) {
                case "StyledText": return styledTextComponent;
                case "MaterialSymbol": return materialSymbolComponent;
                case "ResourceCard": return resourceCardComponent;
                case "StyledImage": return styledImageComponent;
                case "MaterialShape": return materialShapeComponent;
                case "Row": return rowComponent;
                case "Column": return columnComponent;
                case "Item": return itemComponent;
                case "Rectangle": return rectangleComponent;
                case "RippleButton": return rippleButtonComponent;
                case "StyledRectangularShadow": return styledRectangularShadowComponent;
                case "GroupedList": return groupedListComponent;
                case "ConfigSwitch": return configSwitchComponent;
                case "NoticeBox": return noticeBoxComponent;
                case "StyledPopup": return styledPopupComponent;
                case "AtAGlance": return atAGlanceComponent;
                default: return null;
            }
        }

        onLoaded: {
            if (!item) return;
            if (manifestNode.props) {
                for (let prop in manifestNode.props) {
                    let val = manifestNode.props[prop];
                    let finalVal = val;

                    const option = rootNode.optionDefinition(prop);
                    if (option) {
                        finalVal = Qt.binding(function() {
                            return PluginState.option(rootNode.pluginId, prop, option.default);
                        });
                    } else if (typeof val === "string" && val.startsWith("Appearance.colors.")) {
                        let colorName = val.substring(18);
                        finalVal = Qt.binding(function() { return Appearance.colors[colorName]; });
                    } else if (typeof val === "string" && val.startsWith("Appearance.rounding.")) {
                        let rName = val.substring(20);
                        finalVal = Qt.binding(function() { return Appearance.rounding[rName]; });
                    } else if (typeof val === "string" && val === "parent" && prop.startsWith("anchors")) {
                        finalVal = item.parent;
                    }
                    
                    let parts = prop.split('.');
                    let obj = item;
                    for (let i = 0; i < parts.length - 1; i++) {
                        if (obj[parts[i]] === undefined) break;
                        obj = obj[parts[i]];
                    }
                    obj[parts[parts.length - 1]] = finalVal;
                }
            }
            if (manifestNode.bindings) {
                for (let prop in manifestNode.bindings) {
                    let bindTarget = manifestNode.bindings[prop];
                    let finalVal = Qt.binding(function() {
                        return rootNode.resolveBinding(bindTarget);
                    });
                    
                    let parts = prop.split('.');
                    let obj = item;
                    for (let i = 0; i < parts.length - 1; i++) {
                        if (obj[parts[i]] === undefined) break;
                        obj = obj[parts[i]];
                    }
                    obj[parts[parts.length - 1]] = finalVal;
                }
            }
        }
    }

    Component { id: styledTextComponent; StyledText {} }
    Component { id: materialSymbolComponent; MaterialSymbol {} }
    Component { id: resourceCardComponent; ResourceCard {} }
    Component { id: styledImageComponent; StyledImage {} }
    Component { id: atAGlanceComponent; AtAGlancePlugin.AtAGlance {} }

    Component { id: materialShapeComponent; MaterialShape {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: rowComponent; Row {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: columnComponent; Column {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: itemComponent; Item {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: rectangleComponent; Rectangle {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}
    
    Component { id: rippleButtonComponent; RippleButton {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: styledRectangularShadowComponent; StyledRectangularShadow {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: groupedListComponent; GroupedList {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}

    Component { id: configSwitchComponent; ConfigSwitch {} }
    Component { id: noticeBoxComponent; NoticeBox {} }
    Component { id: styledPopupComponent; StyledPopup {
        Repeater {
            model: manifestNode.children || []
            Loader {
                source: "PluginNode.qml"
                onLoaded: { if (item) item.manifestNode = modelData }
            }
        }
    }}
}
