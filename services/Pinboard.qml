pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Pinboard manager for storing text and images.
 * Each item has "id", "content", "image", and "createdAt".
 */
Singleton {
    id: root

    property string filePath: Directories.pinboardPath
    property string imagesDir: Directories.pinboardImages
    property var list: []

    function addPin(content: string, imagePath: string): string {
        content = (content ?? "").trim();
        imagePath = (imagePath ?? "").trim();

        if (content.length === 0 && imagePath.length === 0) {
            return "";
        }

        const id = Date.now().toString() + "-" + Math.floor(Math.random() * 10000);
        let finalImagePath = "";

        if (imagePath.length > 0) {
            const cleanPath = FileUtils.trimFileProtocol(imagePath);
            if (!cleanPath.startsWith(root.imagesDir)) {
                let ext = cleanPath.split(".").pop().toLowerCase() || "png";
                if (ext.indexOf("?") !== -1) {
                    ext = ext.split("?")[0];
                }
                finalImagePath = `${root.imagesDir}/pin_${id}.${ext}`;
                Quickshell.execDetached(["cp", cleanPath, finalImagePath]);
            } else {
                finalImagePath = cleanPath;
            }
        }

        const item = {
            "id": id,
            "content": content,
            "image": finalImagePath,
            "createdAt": Date.now()
        };

        list.unshift(item);
        root.list = list.slice(0);
        save();
        return item.id;
    }

    function deletePin(id: string): void {
        const idx = list.findIndex(p => p.id === id);
        if (idx >= 0) {
            const item = list[idx];
            if (item.image && item.image.startsWith(root.imagesDir)) {
                Quickshell.execDetached(["rm", "-f", item.image]);
            }
            list.splice(idx, 1);
            root.list = list.slice(0);
            save();
        }
    }

    function clearAll(): void {
        Quickshell.execDetached(["bash", "-c", `rm -rf '${root.imagesDir}'/*`]);
        list = [];
        root.list = [];
        save();
    }

    function movePin(from: int, to: int): void {
        if (from === to) return;
        if (from < 0 || from >= list.length) return;
        if (to < 0 || to >= list.length) return;
        const arr = root.list.slice(0);
        const item = arr.splice(from, 1)[0];
        arr.splice(to, 0, item);
        list = arr;
        root.list = arr;
        save();
    }

    function save(): void {
        pinboardFileView.setText(JSON.stringify(root.list, null, 2));
    }

    function refresh(): void {
        pinboardFileView.reload();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${root.imagesDir}`]);
        refresh();
    }

    FileView {
        id: pinboardFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const fileContents = pinboardFileView.text();
            try {
                const parsed = JSON.parse(fileContents);
                root.list = Array.isArray(parsed) ? parsed : [];
                list = root.list;
            } catch (e) {
                console.log("[Pinboard] Corrupt or empty file, resetting to empty list. Error: " + e);
                root.list = [];
                list = [];
                save();
            }
            console.log("[Pinboard] File loaded with " + root.list.length + " items");
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Pinboard] File not found, creating new file.");
                root.list = [];
                save();
            } else {
                console.log("[Pinboard] Error loading file: " + error);
            }
        }
    }
}
