import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

Item {
    id: root

    property LauncherSearchResult entry: null
    property real anchorY: 0
    property real anchorX: 0
    property bool pointLeft: true
    property real minY: 8
    property real maxBottom: 100000

    readonly property bool active: entry !== null
    readonly property bool isImage: entry ? Cliphist.entryIsImage(entry.rawValue) : false
    readonly property real arrowSize: 10
    readonly property real maxContentWidth: 340
    readonly property real maxContentHeight: 280

    property string fullText: ""
    property bool imageGate: true
    property bool animate: true

    function reset() {
        root.animate = false
        root.entry = null
        Qt.callLater(() => { root.animate = true })
    }
    readonly property bool hovered: hoverHandler.hovered

    width: card.width
    height: card.height
    x: root.pointLeft ? root.anchorX + root.arrowSize : root.anchorX - width - root.arrowSize
    y: Math.max(root.minY, Math.min(root.anchorY - height / 2, root.maxBottom - height))

    opacity: root.active ? 1 : 0
    scale: root.active ? 1 : 0.92
    visible: opacity > 0
    transformOrigin: root.pointLeft ? Item.Left : Item.Right

    Behavior on opacity {
        enabled: root.animate
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        enabled: root.animate
        NumberAnimation { duration: 220; easing.type: Easing.OutBack }
    }

    onEntryChanged: {
        root.fullText = ""
        root.imageGate = false
        root.imageGate = true
        textDecoder.active = false
        textDecoder.active = root.entry !== null && !Cliphist.entryIsImage(root.entry.rawValue)
    }

    Loader {
        id: textDecoder
        active: false
        sourceComponent: Process {
            id: decodeProc
            readonly property string decodedEntry: root.entry?.rawValue ?? ""
            running: true
            command: ["bash", "-c", `printf '%s' '${StringUtils.shellSingleQuoteEscape(decodeProc.decodedEntry)}' | ${Cliphist.cliphistBinary} decode | head -c 10000`]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (decodeProc.decodedEntry === (root.entry?.rawValue ?? "")) root.fullText = this.text
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        WindowGlass {
            anchors.fill: parent
            glassEnabled: (parent?.color.a ?? 0) > 0
            cardRadius: parent?.radius ?? 0
            tint: parent?.color ?? 'transparent'
        }
        radius: Appearance.rounding.normal
        color: Appearance.colors.colBackgroundSurfaceContainer
        implicitWidth: content.implicitWidth + 24
        implicitHeight: content.implicitHeight + 24
        width: implicitWidth
        height: implicitHeight

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: 8

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: root.isImage ? "image" : "notes"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: {
                        if (!root.entry) return ""
                        if (root.isImage) {
                            const dims = root.entry.rawValue.match(/(\d+)x(\d+)/)
                            return dims ? Translation.tr("Image • %1×%2").arg(dims[1]).arg(dims[2]) : Translation.tr("Image")
                        }
                        return Translation.tr("Text • %1 characters").arg(root.fullText.length)
                    }
                }
                MaterialSymbol {
                    visible: root.entry?.pinned ?? false
                    text: "keep"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                active: root.active && root.isImage && root.imageGate
                visible: active
                sourceComponent: CliphistImage {
                    entry: root.entry?.rawValue ?? ""
                    maxWidth: root.maxContentWidth
                    maxHeight: root.maxContentHeight
                    blur: root.entry?.blurImage ?? false
                }
            }

            Flickable {
                id: textFlick
                visible: root.active && !root.isImage
                Layout.preferredWidth: root.maxContentWidth
                Layout.preferredHeight: Math.min(textBody.implicitHeight, root.maxContentHeight)
                contentWidth: width
                contentHeight: textBody.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                TouchpadScrollArea { flickable: textFlick }

                ScrollBar.vertical: StyledScrollBar {}

                StyledText {
                    id: textBody
                    width: textFlick.width - 12
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: root.fullText
                }
            }
        }
    }
}
