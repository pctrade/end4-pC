import QtQuick

AnimatedImage {
    id: root

    property string path: ""
    readonly property string resolvedPath: {
        if (root.path === "") return ""
        if (root.path.startsWith("file://")) return root.path
        if (root.path.startsWith("/")) return "file://" + root.path
        return root.path
    }

    source: root.resolvedPath
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    playing: root.visible && root.source !== ""
    sourceSize.width: Math.max(1, width * 2)
    sourceSize.height: Math.max(1, height * 2)
}
