import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: clip
    required property Item di
    anchors.fill: parent

    readonly property bool justCopied: IslandEvents.clipboard.active
    readonly property int historyIndex: Math.max(0, Math.min(clip.di.clipboardIndex, Cliphist.entries.length - 1))
    readonly property var payload: clip.justCopied ? (IslandEvents.clipboard.payload ?? ({}))
        : (Cliphist.entries.length > 0 ? IslandEvents.payloadFor(Cliphist.entries[clip.historyIndex]) : ({}))

    property int lastIndex: clip.historyIndex
    property real slide: 0

    onHistoryIndexChanged: {
        clip.slide = (clip.historyIndex > clip.lastIndex ? 1 : -1) * 12
        clip.lastIndex = clip.historyIndex
        clipSlide.restart()
    }

    NumberAnimation {
        id: clipSlide
        target: clip
        property: "slide"
        to: 0
        duration: IslandMotion.medium
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
    }
    readonly property bool isImage: clip.payload.isImage ?? false
    readonly property var kind: IslandEvents.clipKind(clip.payload)
    readonly property var files: clip.payload.files ?? []
    readonly property bool hasFiles: clip.files.length > 0

    Drag.active: dragArea.drag.active

    Binding {
        target: clip.di
        property: "dragging"
        value: true
        when: dragArea.drag.active
        restoreMode: Binding.RestoreValue
    }
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: {
        if (clip.hasFiles) return { "text/uri-list": clip.files.map(f => `file://${f}`).join("\r\n") }
        if (clip.isImage && IslandEvents.clipboardImagePath !== "") return { "text/uri-list": `file://${IslandEvents.clipboardImagePath}` }
        return { "text/plain": clip.payload.text ?? "" }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: clip.di.isMaterial ? 2 : 4
            rightMargin: 12
        }
        spacing: 8
        opacity: 1 - Math.min(1, Math.abs(clip.slide) / 14)
        transform: Translate { y: clip.slide }

        Item {
            implicitWidth: clip.isImage ? 40 : 28
            implicitHeight: 28

            DiClipIcon {
                anchors.centerIn: parent
                visible: !clip.isImage
                kind: clip.kind
                size: 26
            }

            Repeater {
                model: clip.isImage ? [clip.payload.entry ?? ""] : []
                delegate: CliphistImage {
                    required property string modelData
                    anchors.centerIn: parent
                    entry: modelData
                    maxWidth: 40
                    maxHeight: 26
                    radius: 6
                }
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -3

            StyledText {
                text: clip.justCopied ? (clip.kind.label && !["text", "file", "files", "image"].includes(clip.kind.kind)
                        ? `${Translation.tr("Copied")} · ${clip.kind.label}` : Translation.tr("Copied"))
                    : clip.historyIndex > 0 ? `${Translation.tr("History")} ${clip.historyIndex + 1}/${Cliphist.entries.length}`
                    : Translation.tr("Clipboard")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: clip.hasFiles
                    ? (clip.files.length > 1 ? `${clip.files.length} ${Translation.tr("files")}` : DropShelf.fileName(clip.files[0]))
                    : clip.isImage ? Translation.tr("Image")
                    : clip.kind.kind === "color" ? (IslandEvents.parseColor(clip.payload.text)?.rgb ?? "")
                    : (clip.payload.text ?? "").replace(/\s+/g, " ")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        MaterialSymbol {
            visible: !clip.showQuick
            text: "drag_indicator"
            iconSize: 15
            color: Appearance.colors.colOnLayer0
            opacity: dragArea.containsMouse ? 0.7 : 0.3
        }

        Item {
            visible: clip.showQuick
            implicitWidth: quick.implicitWidth - 6
            implicitHeight: 1
        }
    }

    readonly property string text: clip.payload.text ?? ""
    readonly property bool isText: !clip.isImage && !clip.hasFiles && clip.text.trim() !== ""
    readonly property bool isUrl: /^https?:\/\/\S+$/.test(clip.text.trim())
    readonly property var quickActions: {
        const actions = []
        if (clip.isText && !clip.isUrl)
            actions.push({ icon: "spark", tip: Translation.tr("Ask Gemini"), gemini: true, run: () => IslandEvents.sendToGemini(clip.text, true) })
        if (clip.isUrl)
            actions.push({ icon: "open_in_new", tip: Translation.tr("Open link"), run: () => Qt.openUrlExternally(clip.text.trim()) })
        else if (clip.isText && clip.text.length < 300)
            actions.push({ icon: "search", tip: Translation.tr("Search"), run: () => Qt.openUrlExternally(`https://www.google.com/search?q=${encodeURIComponent(clip.text.trim())}`) })
        if (clip.hasFiles)
            actions.push({ icon: "inventory_2", tip: Translation.tr("Keep in drawer"), run: () => DropShelf.addItems(clip.files.map(f => `file://${f}`)) })
        else if (clip.isText)
            actions.push({ icon: "inventory_2", tip: Translation.tr("Keep in drawer"), run: () => DropShelf.addText(clip.text) })
        return actions
    }
    readonly property bool showQuick: clip.justCopied && clip.di.hoverRevealed && clip.quickActions.length > 0 && !dragArea.drag.active

    Row {
        id: quick
        anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        z: 2
        spacing: 4
        enabled: clip.showQuick
        opacity: clip.showQuick ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: clip.quickActions
            delegate: Rectangle {
                id: quickButton
                required property var modelData
                required property int index
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: quickMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                property real shift: clip.showQuick ? 0 : 6 + quickButton.index * 5
                transform: Translate { x: quickButton.shift }
                Behavior on shift {
                    NumberAnimation { duration: 220 + quickButton.index * 70; easing.type: Easing.OutCubic }
                }

                DiClaudeIcon {
                    anchors.centerIn: parent
                    visible: quickButton.modelData.gemini ?? false
                    agent: "gemini"
                    size: 13
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !(quickButton.modelData.gemini ?? false)
                    text: quickButton.modelData.icon
                    iconSize: 15
                    fill: 1
                    color: Appearance.colors.colOnLayer2
                }

                MouseArea {
                    id: quickMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        quickButton.modelData.run()
                        IslandEvents.clipboard.dismiss()
                    }
                }

                StyledToolTip {
                    extraVisibleCondition: quickMouse.containsMouse
                    text: quickButton.modelData.tip
                }
            }
        }
    }

    Item { id: dragProxy }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: dragProxy
        onReleased: {
            dragProxy.x = 0
            dragProxy.y = 0
        }
        onClicked: {
            if (!clip.justCopied && clip.historyIndex > 0) {
                Cliphist.copy(clip.payload.entry)
                clip.di.clipboardIndex = 0
            } else {
                clip.di.toggleExpanded()
            }
        }
    }
}
