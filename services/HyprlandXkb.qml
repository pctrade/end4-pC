pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.services

/**
 * Exposes the active Hyprland Xkb keyboard layout name and code for indicators.
 */
Singleton {
    id: root
    // You can read these
    property list<string> layoutCodes: []
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    property int currentLayoutIndex: 0
    // Layout code -> description ("fr" -> "French"), to name every layout of
    // the list and not only the active one
    property var layoutDescriptions: ({})
    // For the service
    property var baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"

    // "next" or "prev", or a layout index
    function switchLayout(direction) {
        if (WM.compositor !== "hyprland" || root.layoutCodes.length <= 1) return;
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(direction)]);
    }

    // Update the layout code according to the layout name (Hyprland gives the name not the code)
    onCurrentLayoutNameChanged: {
        root.updateLayoutCode();
        root.updateLayoutIndex();
    }
    onLayoutDescriptionsChanged: root.updateLayoutIndex()
    function updateLayoutIndex() {
        const index = root.layoutCodes.findIndex(code => root.layoutDescriptions[code] === root.currentLayoutName);
        if (index >= 0) root.currentLayoutIndex = index;
    }

    Process {
        id: descriptionsProc
        running: WM.compositor === "hyprland"
        command: ["cat", root.baseLayoutFilePath]
        stdout: StdioCollector {
            id: descriptionsCollector
            onStreamFinished: {
                let descriptions = {};
                let inLayouts = false;
                for (const line of descriptionsCollector.text.split("\n")) {
                    if (line.startsWith("!")) {
                        inLayouts = line.trim() === "! layout";
                        continue;
                    }
                    const match = inLayouts && line.match(/^\s*(\S+)\s+(.+)$/);
                    if (match) descriptions[match[1]] = match[2];
                }
                root.layoutDescriptions = descriptions;
            }
        }
    }
    function updateLayoutCode() {
        if (WM.compositor !== "hyprland") return;
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            root.currentLayoutCode = cachedLayoutCodes[currentLayoutName];
        } else {
            getLayoutProc.running = true;
        }
    }

    // Get the layout code from the base.lst file by grabbing the line with the current layout name
    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector

            onStreamFinished: {
                const lines = layoutCollector.text.split("\n");
                const targetDescription = root.currentLayoutName;
                const foundLine = lines.find(line => {
                    // Skip comment lines and empty lines
                    if (!line.trim() || line.trim().startsWith('!'))
                        return false;

                    // Match layout: (whitespace + ) key + whitespace + description
                    const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/);
                    if (matchLayout && matchLayout[2] === targetDescription) {
                        root.cachedLayoutCodes[matchLayout[2]] = matchLayout[1];
                        root.currentLayoutCode = matchLayout[1];
                        return true;
                    }

                    // Match variant: (whitespace + ) variant + whitespace + key + whitespace + description
                    const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/);
                    if (matchVariant && matchVariant[3] === targetDescription) {
                        const complexLayout = matchVariant[2] + matchVariant[1];
                        root.cachedLayoutCodes[matchVariant[3]] = complexLayout;
                        root.currentLayoutCode = complexLayout;
                        return true;
                    }
                    
                    return false;
                });
            }
        }
    }

    // Find out available layouts and current active layout. Should only be necessary on init
    Process {
        id: fetchLayoutsProc
        running: WM.compositor === "hyprland"
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: devicesCollector
            onStreamFinished: {
                const parsedOutput = JSON.parse(devicesCollector.text);
                const hyprlandKeyboard = parsedOutput["keyboards"].find(kb => kb.main === true);
                root.layoutCodes = hyprlandKeyboard["layout"].split(",").map(code => code.trim());
                root.currentLayoutIndex = hyprlandKeyboard["active_layout_index"] ?? 0;
                root.currentLayoutName = hyprlandKeyboard["active_keymap"];
            }
        }
    }

    // Update the layout name when it changes
    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                if (root.layoutCodes.length <= 1) return;

                const dataString = event.data;
                root.currentLayoutName = dataString.substring(dataString.indexOf(",") + 1);

                Config.options.osk.layout = root.currentLayoutName.split(" (")[0];
            } else if (event.name == "configreloaded") {
                // A layout list edited in the settings arrives with a reload,
                // and no activelayout event may follow it
                fetchLayoutsProc.running = true;
            }
        }
    }
}