import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xclip
    required property Item di
    spacing: 10
    implicitWidth: 380

    // Pinned island opened with nothing just copied: show the latest item plus the history
    readonly property bool pinnedMode: !IslandEvents.clipboard.active
    readonly property var payload: xclip.pinnedMode ? IslandEvents.latestClipboard : (IslandEvents.clipboard.payload ?? ({}))
    readonly property bool isImage: xclip.payload.isImage ?? false
    readonly property var files: xclip.payload.files ?? []
    readonly property bool hasFiles: xclip.files.length > 0
    readonly property string text: xclip.payload.text ?? ""
    readonly property bool isUrl: /^https?:\/\/\S+$/.test(xclip.text)
    readonly property bool isPlainText: !xclip.isImage && !xclip.hasFiles && xclip.text !== ""
    readonly property bool isYoutube: xclip.isUrl && /^https?:\/\/(www\.|m\.|music\.)?(youtube\.com\/(watch|shorts|live)|youtu\.be\/)/.test(xclip.text)
    readonly property bool isPdfUrl: xclip.isUrl && /\.pdf([?#]|$)/i.test(xclip.text)
    readonly property bool isAddress: xclip.isPlainText && !xclip.isUrl && IslandEvents.looksLikeAddress(xclip.text)
    readonly property bool isForeign: xclip.isPlainText && !xclip.isUrl && IslandEvents.looksForeign(xclip.text)
    readonly property bool showTranslation: xclip.isPlainText && IslandEvents.translation.source === xclip.text
    readonly property var colorValue: xclip.isPlainText ? IslandEvents.parseColor(xclip.text) : null
    readonly property var jsonValue: {
        if (!xclip.isPlainText || !/^\s*[\[{]/.test(xclip.text)) return null
        try {
            return JSON.parse(xclip.text)
        } catch (e) {
            return null
        }
    }
    readonly property string trackingCode: xclip.isPlainText && /^\s*[A-Z]{2}\d{9}[A-Z]{2}\s*$/.test(xclip.text) ? xclip.text.trim() : ""
    // Brazilian phone numbers, with or without +55 and punctuation
    readonly property string phoneDigits: {
        if (!xclip.isPlainText || xclip.text.length > 25 || !/^[\s()+\-.\d]+$/.test(xclip.text)) return ""
        let digits = xclip.text.replace(/\D/g, "")
        if (digits.length === 10 || digits.length === 11) digits = `55${digits}`
        return /^55\d{10,11}$/.test(digits) ? digits : ""
    }
    readonly property bool isEmail: xclip.isPlainText && /^\s*[^\s@]+@[^\s@]+\.[^\s@]+\s*$/.test(xclip.text)
    readonly property string imagePath: IslandEvents.clipboardImagePath
    readonly property var imageFiles: xclip.files.filter(f => DropShelf.isImage(f))
    readonly property string exportDir: `${Directories.pictures}/Clipboard`
    property string status: ""
    property string savedPath: ""

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")
    }

    function run(script, successText, onDone) {
        actionProc.successText = successText
        actionProc.onDone = onDone ?? null
        actionProc.command = ["bash", "-c", script]
        actionProc.running = true
    }

    function q(path) {
        return `'${StringUtils.shellSingleQuoteEscape(path)}'`
    }

    function exportImage(extension, reveal) {
        if (xclip.imagePath === "") return
        const target = `${xclip.exportDir}/clip-${xclip.stamp()}.${extension}`
        const convert = extension === "png" ? `cp ${xclip.q(xclip.imagePath)} ${xclip.q(target)}` : `magick ${xclip.q(xclip.imagePath)} ${xclip.q(target)}`
        xclip.run(`mkdir -p ${xclip.q(xclip.exportDir)} && ${convert}`, Translation.tr("Saved to Pictures/Clipboard"), () => {
            xclip.savedPath = target
            if (reveal) Quickshell.execDetached(["dolphin", "--select", target])
        })
    }

    function convertFiles(extension) {
        const script = xclip.imageFiles.map(f => `magick ${xclip.q(f)} ${xclip.q(f.replace(/\.[^.\/]+$/, "") + "." + extension)}`).join(" && ")
        xclip.run(script, `${Translation.tr("Converted to")} ${extension.toUpperCase()}`)
    }

    function copyText(value) {
        xclip.run(`printf '%s' ${xclip.q(value)} | wl-copy`, Translation.tr("Copied"))
    }

    function keepInDrawer() {
        if (xclip.hasFiles) {
            DropShelf.addItems(xclip.files.map(f => `file://${f}`))
        } else if (xclip.isImage && xclip.imagePath !== "") {
            const target = `${DropShelf.storeDir}/clip-${xclip.stamp()}.png`
            xclip.run(`mkdir -p ${xclip.q(DropShelf.storeDir)} && cp ${xclip.q(xclip.imagePath)} ${xclip.q(target)}`, Translation.tr("Kept in the drawer"),
                () => DropShelf.addItems([`file://${target}`]))
            return
        } else {
            DropShelf.addText(xclip.text)
        }
        xclip.status = Translation.tr("Kept in the drawer")
    }

    Process {
        id: actionProc
        property string successText: ""
        property var onDone: null
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                xclip.status = Translation.tr("Something went wrong")
                return
            }
            xclip.status = actionProc.successText
            if (actionProc.onDone) actionProc.onDone()
        }
    }

    component ActionChip: Rectangle {
        id: chip
        property string icon
        property string label
        property var onTap
        property bool primary: false
        property string agent: ""       // an AI brand mark (gemini) instead of a Material icon
        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 30
        radius: 15
        color: chip.primary
            ? (chipMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.62) : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8))
            : (chipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
        scale: chipMouse.pressed ? 0.93 : 1

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            DiClaudeIcon {
                visible: chip.agent !== ""
                agent: chip.agent || "gemini"
                size: 13
            }
            MaterialSymbol {
                visible: chip.agent === ""
                text: chip.icon
                iconSize: 15
                fill: 1
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.onTap()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MaterialSymbol {
            text: xclip.hasFiles ? "file_copy" : "content_paste"
            iconSize: 18
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: xclip.status !== "" ? xclip.status : (xclip.pinnedMode ? Translation.tr("Clipboard") : Translation.tr("Copied to clipboard"))
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: xclip.status !== "" ? Appearance.m3colors.m3success : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        MaterialSymbol {
            text: "drag_indicator"
            iconSize: 16
            color: Appearance.colors.colOnLayer0
            opacity: 0.4
        }
    }

    // Preview doubles as a drag handle
    Item {
        id: preview
        Layout.fillWidth: true
        implicitHeight: xclip.isImage ? 190 : (xclip.hasFiles ? filesColumn.implicitHeight : textBox.implicitHeight)

        Drag.active: previewMouse.drag.active

        Binding {
            target: xclip.di
            property: "dragging"
            value: true
            when: previewMouse.drag.active
            restoreMode: Binding.RestoreValue
        }
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: {
            if (xclip.hasFiles) return { "text/uri-list": xclip.files.map(f => `file://${f}`).join("\r\n") }
            if (xclip.isImage && xclip.imagePath !== "") return { "text/uri-list": `file://${xclip.imagePath}` }
            return { "text/plain": xclip.text }
        }

        Loader {
            anchors.centerIn: parent
            active: xclip.isImage
            sourceComponent: CliphistImage {
                entry: xclip.payload.entry ?? ""
                maxWidth: 350
                maxHeight: 190
                radius: 12
            }
        }

        ColumnLayout {
            id: filesColumn
            width: parent.width
            visible: xclip.hasFiles
            spacing: 4

            Repeater {
                model: xclip.files.slice(0, 5)
                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: Appearance.colors.colLayer1

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8
                        MaterialSymbol {
                            text: DropShelf.iconFor(modelData)
                            iconSize: 18
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: DropShelf.fileName(modelData)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }

        Rectangle {
            id: textBox
            width: parent.width
            visible: !xclip.isImage && !xclip.hasFiles
            implicitHeight: clipText.implicitHeight + 20
            radius: 12
            color: Appearance.colors.colLayer1

            StyledText {
                id: clipText
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 10
                }
                text: xclip.text
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: /^\s*[{<\[]|;\s*$|\bfunction\b|=>/.test(xclip.text) ? Appearance.font.family.monospace : Appearance.font.family.main
                color: Appearance.colors.colOnLayer1
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 6
                elide: Text.ElideRight
            }
        }

        Item { id: previewDragProxy }

        MouseArea {
            id: previewMouse
            anchors.fill: parent
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: previewDragProxy
            onReleased: {
                previewDragProxy.x = 0
                previewDragProxy.y = 0
            }
        }
    }

    // What to do with what was copied: the actions that fit it, the most useful first
    Flow {
        Layout.fillWidth: true
        spacing: 6

        ActionChip {
            visible: !xclip.isImage && !xclip.hasFiles && xclip.text.trim() !== ""
            primary: true
            agent: "gemini"
            label: Translation.tr("Ask Gemini")
            onTap: () => {
                IslandEvents.sendToGemini(xclip.text, true)
                xclip.di.collapse()
            }
        }
        ActionChip {
            visible: !xclip.isImage && !xclip.hasFiles && !xclip.isUrl && xclip.text.trim() !== "" && xclip.text.length < 300
            primary: true
            icon: "search"
            label: Translation.tr("Search")
            onTap: () => {
                Qt.openUrlExternally(`https://www.google.com/search?q=${encodeURIComponent(xclip.text.trim())}`)
                xclip.di.collapse()
            }
        }

        // Image
        ActionChip {
            visible: xclip.isImage
            icon: "save"
            label: Translation.tr("Save")
            onTap: () => xclip.exportImage("png", false)
        }
        ActionChip {
            visible: xclip.isImage
            icon: "photo"
            label: "JPG"
            onTap: () => xclip.exportImage("jpg", false)
        }
        ActionChip {
            visible: xclip.isImage
            icon: "image"
            label: "WEBP"
            onTap: () => xclip.exportImage("webp", false)
        }
        ActionChip {
            visible: xclip.isImage
            icon: "folder_open"
            label: Translation.tr("Show in folder")
            onTap: () => {
                if (xclip.savedPath !== "") Quickshell.execDetached(["dolphin", "--select", xclip.savedPath])
                else xclip.exportImage("png", true)
            }
        }

        // Files
        ActionChip {
            visible: xclip.hasFiles
            icon: "open_in_new"
            label: Translation.tr("Open")
            onTap: () => Qt.openUrlExternally(`file://${xclip.files[0]}`)
        }
        ActionChip {
            visible: xclip.hasFiles
            icon: "folder_open"
            label: Translation.tr("Show in folder")
            onTap: () => Quickshell.execDetached(["dolphin", "--select", xclip.files[0]])
        }
        ActionChip {
            visible: xclip.imageFiles.length > 0
            icon: "photo"
            label: `${Translation.tr("Convert to")} JPG`
            onTap: () => xclip.convertFiles("jpg")
        }
        ActionChip {
            visible: xclip.imageFiles.length > 0
            icon: "image"
            label: `${Translation.tr("Convert to")} WEBP`
            onTap: () => xclip.convertFiles("webp")
        }
        ActionChip {
            visible: xclip.imageFiles.length > 0
            icon: "image"
            label: `${Translation.tr("Convert to")} PNG`
            onTap: () => xclip.convertFiles("png")
        }

        // Image tools
        ActionChip {
            visible: (xclip.isImage && xclip.imagePath !== "") || xclip.imageFiles.length > 0
            icon: "document_scanner"
            label: Translation.tr("Copy text")
            onTap: () => IslandEvents.ocrImage(xclip.isImage ? xclip.imagePath : xclip.imageFiles[0])
        }
        ActionChip {
            visible: (xclip.isImage && xclip.imagePath !== "") || xclip.imageFiles.length > 0
            icon: "image_search"
            label: "Google Lens"
            onTap: () => IslandEvents.lensSearch(xclip.isImage ? xclip.imagePath : xclip.imageFiles[0])
        }

        // Text
        ActionChip {
            visible: xclip.isUrl
            icon: "link"
            label: Translation.tr("Open link")
            onTap: () => Qt.openUrlExternally(xclip.text)
        }
        ActionChip {
            visible: xclip.isYoutube
            icon: "movie"
            label: Translation.tr("Download video")
            onTap: () => {
                IslandEvents.downloadMedia(xclip.text, false)
                xclip.status = Translation.tr("Downloading to the drawer…")
            }
        }
        ActionChip {
            visible: xclip.isYoutube
            icon: "music_note"
            label: Translation.tr("Download audio")
            onTap: () => {
                IslandEvents.downloadMedia(xclip.text, true)
                xclip.status = Translation.tr("Downloading to the drawer…")
            }
        }
        ActionChip {
            visible: xclip.isPdfUrl
            icon: "picture_as_pdf"
            label: Translation.tr("Open PDF")
            onTap: () => Qt.openUrlExternally(xclip.text)
        }
        ActionChip {
            visible: xclip.isPdfUrl
            icon: "download"
            label: Translation.tr("Save to drawer")
            onTap: () => {
                DropShelf.addItems([xclip.text])
                xclip.status = Translation.tr("Saving to the drawer…")
            }
        }
        ActionChip {
            visible: xclip.isAddress
            icon: "map"
            label: Translation.tr("Open in Maps")
            onTap: () => Qt.openUrlExternally(`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(xclip.text.replace(/\s+/g, " "))}`)
        }
        ActionChip {
            visible: xclip.isForeign
            icon: "translate"
            label: Translation.tr("Translate")
            onTap: () => IslandEvents.translateText(xclip.text)
        }

        // Color: swatch and the same color in other notations
        Rectangle {
            visible: xclip.colorValue !== null
            implicitWidth: 30
            implicitHeight: 30
            radius: 15
            color: xclip.colorValue?.color ?? "transparent"
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)
        }
        ActionChip {
            visible: xclip.colorValue !== null
            icon: "tag"
            label: xclip.colorValue?.hex ?? ""
            onTap: () => xclip.copyText(xclip.colorValue.hex)
        }
        ActionChip {
            visible: xclip.colorValue !== null
            icon: "palette"
            label: xclip.colorValue?.rgb ?? ""
            onTap: () => xclip.copyText(xclip.colorValue.rgb)
        }
        ActionChip {
            visible: xclip.colorValue !== null
            icon: "palette"
            label: xclip.colorValue?.hsl ?? ""
            onTap: () => xclip.copyText(xclip.colorValue.hsl)
        }

        // JSON, package tracking, phone and e-mail
        ActionChip {
            visible: xclip.jsonValue !== null
            icon: "data_object"
            label: Translation.tr("Format JSON")
            onTap: () => xclip.copyText(JSON.stringify(xclip.jsonValue, null, 2))
        }
        ActionChip {
            visible: xclip.jsonValue !== null
            icon: "compress"
            label: Translation.tr("Minify JSON")
            onTap: () => xclip.copyText(JSON.stringify(xclip.jsonValue))
        }
        ActionChip {
            visible: xclip.trackingCode !== ""
            icon: "local_shipping"
            label: Translation.tr("Track package")
            onTap: () => Qt.openUrlExternally(`https://www.linkcorreios.com.br/?id=${xclip.trackingCode}`)
        }
        ActionChip {
            visible: xclip.phoneDigits !== ""
            icon: "chat"
            label: Translation.tr("Open in WhatsApp")
            onTap: () => Qt.openUrlExternally(`https://wa.me/${xclip.phoneDigits}`)
        }
        ActionChip {
            visible: xclip.isEmail
            icon: "mail"
            label: Translation.tr("Write email")
            onTap: () => Qt.openUrlExternally(`mailto:${xclip.text.trim()}`)
        }
    }

    // Second row: text tools grouped on the left, keep/remove as quiet icons on the right
    component ToolSegment: Rectangle {
        id: seg
        property string icon
        property string label
        property string tip
        property var onTap
        implicitWidth: segRow.implicitWidth + 16
        implicitHeight: 28
        radius: 8
        color: segArea.containsMouse ? Appearance.colors.colLayer2 : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        RowLayout {
            id: segRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                visible: seg.icon !== ""
                text: seg.icon
                iconSize: 15
                color: Appearance.colors.colOnLayer1
                opacity: 0.85
            }
            StyledText {
                visible: seg.label !== ""
                text: seg.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }
        MouseArea {
            id: segArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.onTap()
        }
        StyledToolTip {
            text: seg.tip
            extraVisibleCondition: false
            alternativeVisibleCondition: segArea.containsMouse && seg.tip !== ""
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // Text: one grouped control instead of three loose chips
        Rectangle {
            visible: !xclip.isImage && !xclip.hasFiles && xclip.text.trim() !== ""
            implicitWidth: textTools.implicitWidth + 8
            implicitHeight: 32
            radius: 10
            color: Appearance.colors.colLayer1

            RowLayout {
                id: textTools
                anchors.centerIn: parent
                spacing: 0

                ToolSegment {
                    label: "ABC"
                    tip: Translation.tr("Copy in uppercase")
                    onTap: () => xclip.copyText(xclip.text.toUpperCase())
                }
                ToolSegment {
                    label: "abc"
                    tip: Translation.tr("Copy in lowercase")
                    onTap: () => xclip.copyText(xclip.text.toLowerCase())
                }
                ToolSegment {
                    icon: "format_clear"
                    tip: Translation.tr("Clean up spaces")
                    onTap: () => xclip.copyText(xclip.text.replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim())
                }
            }
        }

        Item { Layout.fillWidth: true }

        ToolSegment {
            icon: "inventory_2"
            tip: Translation.tr("Keep in drawer")
            onTap: () => xclip.keepInDrawer()
        }
        ToolSegment {
            icon: "delete"
            tip: Translation.tr("Remove from history")
            onTap: () => {
                Cliphist.deleteEntry(xclip.payload.entry ?? "")
                IslandEvents.clipboard.dismiss()
                xclip.di.collapse()
            }
        }
    }

    // Translation of copied text in another language
    Rectangle {
        Layout.fillWidth: true
        visible: xclip.showTranslation
        implicitHeight: translationColumn.implicitHeight + 20
        radius: 12
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)

        ColumnLayout {
            id: translationColumn
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 10
            }
            spacing: 6

            RowLayout {
                spacing: 5
                MaterialSymbol {
                    text: "translate"
                    iconSize: 15
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: Translation.tr("Translation")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: IslandEvents.translation.busy ? Translation.tr("Translating…")
                    : (IslandEvents.translation.result || Translation.tr("Couldn't translate"))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                wrapMode: Text.Wrap
                maximumLineCount: 8
                elide: Text.ElideRight
            }
            ActionChip {
                visible: !IslandEvents.translation.busy && IslandEvents.translation.result !== ""
                icon: "content_copy"
                label: Translation.tr("Copy translation")
                onTap: () => xclip.copyText(IslandEvents.translation.result)
            }
        }
    }

    StyledText {
        visible: xclip.pinnedMode && Cliphist.entries.length > 1
        text: Translation.tr("History")
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.8
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: xclip.pinnedMode
        spacing: 4

        Repeater {
            model: xclip.pinnedMode ? Cliphist.entries.slice(1, 13) : []
            delegate: Rectangle {
                id: historyItem
                required property string modelData
                readonly property bool image: Cliphist.entryIsImage(historyItem.modelData)
                Layout.fillWidth: true
                implicitHeight: historyItem.image ? 60 : 34
                radius: 10
                color: historyMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    Loader {
                        active: historyItem.image
                        visible: active
                        sourceComponent: CliphistImage {
                            entry: historyItem.modelData
                            maxWidth: 76
                            maxHeight: 46
                            radius: 6
                        }
                    }
                    MaterialSymbol {
                        visible: !historyItem.image
                        text: "content_paste"
                        iconSize: 15
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: historyItem.image ? Translation.tr("Image") : historyItem.modelData.replace(/^\d+\t/, "").replace(/\s+/g, " ")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: historyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Cliphist.copy(historyItem.modelData)
                        xclip.status = Translation.tr("Copied")
                    }
                }
            }
        }
    }
}
