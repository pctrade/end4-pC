pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var availablePlugins: []
    property var manifestsMap: ({})

    function rebuildFromLoadedFiles() {
        let loaded = [];
        let map = {};
        [clockManifestFile, batteryManifestFile, dockerManifestFile, atAGlanceManifestFile].forEach(fileView => {
            if (!fileView.loaded) return;
            try {
                const text = fileView.text();
                if (!text) return;
                const manifest = JSON.parse(text);
                loaded.push(manifest);
                map[manifest.id] = manifest;
            } catch (e) {
                console.log("[PluginManager] Error parsing plugin manifest at " + fileView.path + ": " + e);
            }
        });
        root.availablePlugins = loaded;
        root.manifestsMap = map;
    }

    FileView {
        id: clockManifestFile
        path: Quickshell.shellPath("modules/common/plugins/bundled/clock/manifest.json")
        onLoaded: root.rebuildFromLoadedFiles()
    }
    FileView {
        id: batteryManifestFile
        path: Quickshell.shellPath("modules/common/plugins/bundled/battery/manifest.json")
        onLoaded: root.rebuildFromLoadedFiles()
    }
    FileView {
        id: dockerManifestFile
        path: Quickshell.shellPath("modules/common/plugins/bundled/docker/manifest.json")
        onLoaded: root.rebuildFromLoadedFiles()
    }
    FileView {
        id: atAGlanceManifestFile
        path: Quickshell.shellPath("modules/common/plugins/bundled/atAGlance/manifest.json")
        onLoaded: root.rebuildFromLoadedFiles()
    }
}
