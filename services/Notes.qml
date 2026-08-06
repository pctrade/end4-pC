pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple notes manager.
 * Each item is an object with "id", "content", "attachments" (array of file paths), "createdAt".
 */
Singleton {
    id: root
    property var filePath: Directories.desktopNotesPath ?? (Directories.config + "/notes.json")
    property var list: []

    function addNote(content, attachments) {
        const item = {
            "id": Date.now().toString() + "-" + Math.floor(Math.random() * 10000),
            "content": content ?? "",
            "attachments": attachments ?? [],
            "createdAt": Date.now()
        }
        list.push(item)
        root.list = list.slice(0)
        notesFileView.setText(JSON.stringify(root.list))
        return item.id
    }

    function updateNote(id, content, attachments) {
        const idx = list.findIndex(n => n.id === id)
        if (idx >= 0) {
            list[idx].content = content
            if (attachments !== undefined)
                list[idx].attachments = attachments
            root.list = list.slice(0)
            notesFileView.setText(JSON.stringify(root.list))
        }
    }

    function deleteNote(id) {
        const idx = list.findIndex(n => n.id === id)
        if (idx >= 0) {
            list.splice(idx, 1)
            root.list = list.slice(0)
            notesFileView.setText(JSON.stringify(root.list))
        }
    }

    function refresh() {
        notesFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notesFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const fileContents = notesFileView.text()
            try {
                const parsed = JSON.parse(fileContents)
                root.list = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                console.log("[Notes] Corrupt or empty file, resetting to empty list. Error: " + e)
                root.list = []
                notesFileView.setText(JSON.stringify(root.list))
            }
            console.log("[Notes] File loaded")
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                console.log("[Notes] File not found, creating new file.")
                root.list = []
                notesFileView.setText(JSON.stringify(root.list))
            } else {
                console.log("[Notes] Error loading file: " + error)
            }
        }
    }
}