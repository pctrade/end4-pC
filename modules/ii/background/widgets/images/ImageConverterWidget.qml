pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "images"

    property list<var> formatOptions: [
        { displayName: "PNG",  icon: "image",            value: "png"  },
        { displayName: "JPG",  icon: "photo",            value: "jpg"  },
        { displayName: "WEBP", icon: "motion_photos_on", value: "webp" },
        { displayName: "AVIF", icon: "hd",               value: "avif" },
        { displayName: "BMP",  icon: "grid_on",          value: "bmp"  },
        { displayName: "TIFF", icon: "photo_library",    value: "tiff" },
        { displayName: "PDF",  icon: "picture_as_pdf",   value: "pdf"  },
    ]

    property string selectedFormat: "webp"
    property string dropStatus: "idle"   // idle | hover | converting | done | error
    property string statusMessage: ""

    readonly property var acceptedExtensions: ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"]

    property var fileQueue: []
    property int queueTotal: 0
    property int queueDone: 0
    property var batchPaths: []

    implicitWidth:  276
    implicitHeight: 252

    Process {
        id: converter
        property string inputPath: ""
        property string outputPath: ""
        command: ["ffmpeg", "-y", "-i", inputPath, outputPath]
        onExited: (exitCode) => {
            root.queueDone++
            if (exitCode !== 0) {
                root.dropStatus = "error"
                root.statusMessage = "Failed: " + inputPath.replace(/.*\//, "")
                root.fileQueue = []
                root.queueTotal = 0
                root.queueDone = 0
                resetTimer.start()
                return
            }
            if (root.fileQueue.length > 0) {
                root.statusMessage = "Converting " + root.queueDone + " / " + root.queueTotal + "..."
                processNext()
            } else {
                root.dropStatus = "done"
                root.statusMessage = root.queueTotal === 1
                    ? "Saved: " + outputPath.replace(/.*\//, "")
                    : root.queueTotal + " files converted"
                root.queueTotal = 0
                root.queueDone = 0
                resetTimer.start()
            }
        }
    }

    Process {
        id: pdfMaker
        property string outputPath: ""
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.dropStatus = "done"
                root.statusMessage = root.batchPaths.length === 1
                    ? "Saved: " + outputPath.replace(/.*\//, "")
                    : root.batchPaths.length + " pages → " + outputPath.replace(/.*\//, "")
            } else {
                root.dropStatus = "error"
                root.statusMessage = "PDF failed.\nIs ImageMagick installed?"
            }
            root.batchPaths = []
            resetTimer.start()
        }
    }

    Timer {
        id: resetTimer
        interval: 3500
        repeat: false
        onTriggered: root.dropStatus = "idle"
    }

    function processNext() {
        var next = root.fileQueue[0]
        root.fileQueue = root.fileQueue.slice(1)
        converter.inputPath  = next
        converter.outputPath = next.replace(/\.[^/.]+$/, "") + "_converted." + root.selectedFormat
        converter.running = true
    }

    function enqueueFiles(urls) {
        var valid = []
        for (var i = 0; i < urls.length; i++) {
            var cleanPath = urls[i].toString().replace(/^file:\/\//, "")
            var ext = cleanPath.split(".").pop().toLowerCase()
            if (root.acceptedExtensions.indexOf(ext) !== -1)
                valid.push(cleanPath)
        }
        if (valid.length === 0) {
            root.dropStatus = "error"
            root.statusMessage = "No supported files dropped."
            resetTimer.start()
            return
        }

        root.dropStatus = "converting"

        if (root.selectedFormat === "pdf") {
            root.batchPaths = valid
            root.statusMessage = valid.length === 1
                ? "Converting to PDF..."
                : "Merging " + valid.length + " images into PDF..."
            var outPdf = valid[0].replace(/\.[^/.]+$/, "") + (valid.length > 1 ? "_merged" : "_converted") + ".pdf"
            pdfMaker.outputPath = outPdf
            pdfMaker.command = ["convert"].concat(valid).concat([outPdf])
            pdfMaker.running = true
            return
        }

        root.fileQueue  = valid.slice(1)
        root.queueTotal = valid.length
        root.queueDone  = 0
        root.statusMessage = valid.length > 1 ? "Converting 0 / " + valid.length + "..." : "Converting..."
        converter.inputPath  = valid[0]
        converter.outputPath = valid[0].replace(/\.[^/.]+$/, "") + "_converted." + root.selectedFormat
        converter.running = true
    }

    Rectangle {
        id: contentItem
        color: Appearance.colors.colPrimaryContainer
        radius: Appearance.rounding?.verylarge ?? 30
        implicitWidth: 276
        implicitHeight: 252

        ColumnLayout {
            id: columnLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Appearance.spacing.large
            }
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.4
                text: "PNG · JPG · WEBP · AVIF · BMP · PDF · TIFF"
            }

            Rectangle {
                id: dropZone
                Layout.fillWidth: true
                implicitHeight: 144
                radius: Appearance.rounding.large
                color: {
                    switch (root.dropStatus) {
                        case "hover":      return Appearance.colors.colPrimaryContainer
                        case "converting": return Appearance.colors.colSecondaryContainer
                        case "done":       return Appearance.colors.colTertiaryContainer
                        case "error":      return Qt.rgba(
                                                Appearance.colors.colError.r,
                                                Appearance.colors.colError.g,
                                                Appearance.colors.colError.b, 0.15)
                        default:           return Appearance.colors.colSurfaceContainerLow 
                    }
                }
                border.color: {
                    switch (root.dropStatus) {
                        case "hover":      return Appearance.colors.colPrimary
                        case "converting": return Appearance.colors.colSecondary
                        case "done":       return Appearance.colors.colTertiary
                        case "error":      return Appearance.colors.colError
                        default:           return Appearance.colors.colOnPrimaryContainer
                    }
                }
                border.width: root.dropStatus === "hover" ? 2 : 1

                Behavior on color        { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                MaterialLoadingIndicator {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -14
                    visible: root.dropStatus === "converting"
                    loading: root.dropStatus === "converting"
                    colBg: Appearance.colors.colPrimary
                    colShape: Appearance.colors.colOnPrimary
                    implicitSize: 48
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -14
                    visible: root.dropStatus !== "converting"
                    iconSize: 32
                    fill: root.dropStatus === "done" ? 1 : 0
                    color: {
                        switch (root.dropStatus) {
                            case "hover": return Appearance.colors.colPrimary
                            case "done":  return Appearance.colors.colTertiary
                            case "error": return Appearance.colors.colError
                            default:      return Appearance.colors.colOnLayer1
                        }
                    }
                    text: {
                        switch (root.dropStatus) {
                            case "hover": return "download"
                            case "done":  return "check_circle"
                            case "error": return "error"
                            default:      return root.selectedFormat === "pdf" ? "picture_as_pdf" : "image"
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 22
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.font.pixelSize.small
                    width: parent.width - 24
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: {
                        switch (root.dropStatus) {
                            case "hover":  return Appearance.colors.colPrimary
                            case "done":   return Appearance.colors.colTertiary
                            case "error":  return Appearance.colors.colError
                            default:       return Appearance.colors.colOnLayer1
                        }
                    }
                    opacity: root.dropStatus === "idle" ? 0.6 : 1.0
                    text: {
                        switch (root.dropStatus) {
                            case "idle":       return "Drop image(s) here\nto convert to ." + root.selectedFormat.toUpperCase()
                            case "hover":      return "Release to convert to ." + root.selectedFormat.toUpperCase()
                            case "converting": return root.statusMessage
                            case "done":       return root.statusMessage
                            case "error":      return root.statusMessage
                            default:           return ""
                        }
                    }
                    Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onEntered: (drag) => {
                        drag.accept(Qt.CopyAction)
                        root.dropStatus = "hover"
                    }
                    onExited: {
                        if (root.dropStatus === "hover")
                            root.dropStatus = "idle"
                    }
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0) {
                            root.enqueueFiles(drop.urls)
                        } else {
                            root.dropStatus = "error"
                            root.statusMessage = "Could not read file path."
                            resetTimer.start()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.leftMargin: Appearance.spacing.verysmall
                    text: "Convert to:"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.formatOptions
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colSurfaceContainerLow
                    colBackgroundActive: Appearance.colors.colSurfaceContainerLow // same color I didn't like the hover 
                    textRole: "displayName"
                    valueRole: "value"
                    currentIndex: {
                        for (var i = 0; i < model.length; i++) {
                            if (model[i].value === root.selectedFormat) return i;
                        }
                        return 0;
                    }
                    onActivated: (index) => {
                        root.selectedFormat = model[index].value
                    }
                }
            }
        }
    }
}