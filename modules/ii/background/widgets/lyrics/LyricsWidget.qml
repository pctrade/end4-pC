import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

/*
 * Synced lyrics of the playing track, floating on the desktop.
 * One line, or karaoke style with the previous and next lines around it.
 * Drag the corner handle to resize.
 */
AbstractBackgroundWidget {
    id: root
    configEntryName: "lyrics"
    hoverEnabled: true
    needsColText: root.configEntry.color === ""

    readonly property real minFontSize: 16
    readonly property real maxFontSize: 200
    readonly property real lineHeight: 1.25

    property real fontSize: root.configEntry.fontSize
    readonly property bool karaoke: root.configEntry.style === "karaoke"
    readonly property real sideFontSize: root.fontSize * 0.55
    readonly property color textColor: root.configEntry.color === "" ? root.colText : Appearance.getColorFromName(root.configEntry.color)
    readonly property string fontFamily: root.configEntry.fontFamily || Appearance.font.family.title
    readonly property int textAlignment: ({ left: Text.AlignLeft, right: Text.AlignRight })[root.configEntry.alignment] ?? Text.AlignHCenter

    readonly property bool showing: LyricsService.synced && (LyricsService.playing || !root.configEntry.hideWhenPaused)
    readonly property string currentLine: LyricsService.slots[LyricsService.before] ?? ""
    readonly property string previousLine: LyricsService.slots[LyricsService.before - 1] ?? ""
    readonly property string nextLine: LyricsService.slots[LyricsService.before + 1] ?? ""

    // Lines actually drawn, swapped while faded out so a new line reads as a transition
    property string shownCurrent: root.currentLine
    property string shownPrevious: root.previousLine
    property string shownNext: root.nextLine
    property real lineFade: 1

    // A fixed box: the widget does not jump around as line lengths change
    implicitWidth: Math.min(root.fontSize * 14, root.scaledScreenWidth * 0.9)
    implicitHeight: root.fontSize * root.lineHeight * 2
        + (root.karaoke ? (root.sideFontSize * root.lineHeight + content.spacing) * 2 : 0)
    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked

    onCurrentLineChanged: lineChange.restart()

    SequentialAnimation {
        id: lineChange
        NumberAnimation { target: root; property: "lineFade"; to: 0; duration: 110; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                root.shownCurrent = root.currentLine;
                root.shownPrevious = root.previousLine;
                root.shownNext = root.nextLine;
                slide.y = root.fontSize * 0.25;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lineFade"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: slide; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    // Resizing scales the font by how much the widget box is stretched
    property real resizeStartFontSize: -1
    property real resizeStartHeight: 0

    function resizeBy(dx, dy, startWidth) {
        if (root.resizeStartFontSize < 0) {
            root.resizeStartFontSize = root.fontSize;
            root.resizeStartHeight = root.height;
        }
        const factor = Math.max((startWidth + dx) / startWidth, (root.resizeStartHeight + dy) / root.resizeStartHeight);
        root.fontSize = Math.round(Math.min(Math.max(root.resizeStartFontSize * factor, root.minFontSize), root.maxFontSize));
    }

    function commitFontSize() {
        if (root.resizeStartFontSize < 0) return;
        root.resizeStartFontSize = -1;
        root.configEntry.fontSize = root.fontSize;
        root.fontSize = Qt.binding(() => root.configEntry.fontSize);
    }

    component LyricLine: Text {
        width: content.width
        horizontalAlignment: root.textAlignment
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        color: root.textColor
        font.family: root.fontFamily
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width
        spacing: root.fontSize * 0.2
        opacity: root.showing ? root.lineFade : 0
        transform: Translate { id: slide }

        Behavior on opacity {
            enabled: !lineChange.running
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        layer.enabled: root.configEntry.shadow
        layer.effect: DropShadow {
            radius: 8
            samples: radius * 2 + 1
            verticalOffset: 2
            color: Appearance.colors.colShadow
            transparentBorder: true
        }

        LyricLine {
            visible: root.karaoke
            text: root.shownPrevious
            font.pixelSize: root.sideFontSize
            maximumLineCount: 1
            opacity: 0.5
        }
        LyricLine {
            text: root.shownCurrent
            font.pixelSize: root.fontSize
            font.weight: Font.DemiBold
        }
        LyricLine {
            visible: root.karaoke
            text: root.shownNext
            font.pixelSize: root.sideFontSize
            maximumLineCount: 1
            opacity: 0.5
        }
    }

    // Widgets unlocked (right-click a widget): the desktop is being arranged
    readonly property bool editing: !Config.options.background.widgetsLocked

    // Nothing to show: still findable while arranging, to move or resize it
    Text {
        anchors.centerIn: parent
        visible: !root.showing && root.editing
        text: "♪"
        color: root.textColor
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    readonly property string statusText: {
        if (!LyricsService.activePlayer) return Translation.tr("Nothing playing");
        switch (LyricsService.status) {
            case "loading": return Translation.tr("Searching for lyrics…");
            case "not_found": return Translation.tr("No synced lyrics found");
            case "error": return Translation.tr("Lyrics server busy, retrying");
            case "no_info": return Translation.tr("No track info");
        }
        const track = LyricsService.activePlayer.trackTitle ?? "";
        const artist = LyricsService.activePlayer.trackArtist ?? "";
        return artist ? `${artist} · ${track}` : track;
    }

    // Only while arranging, on hover, and kept a moment so the pointer can reach it below the box
    property bool toolsShown: false
    readonly property bool pointerNear: root.editing && (root.containsMouse || toolsHover.hovered)
    onPointerNearChanged: {
        if (root.pointerNear) {
            hideTools.stop();
            root.toolsShown = true;
        } else {
            hideTools.restart();
        }
    }
    Timer {
        id: hideTools
        interval: 500
        onTriggered: root.toolsShown = false
    }

    Toolbar {
        anchors {
            top: parent.bottom
            topMargin: 8
            horizontalCenter: parent.horizontalCenter
        }
        visible: opacity > 0
        opacity: root.toolsShown ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        HoverHandler { id: toolsHover }

        StyledText {
            Layout.leftMargin: 12
            Layout.rightMargin: 4
            Layout.maximumWidth: 360
            elide: Text.ElideRight
            text: root.statusText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        IconToolbarButton {
            text: "refresh"
            enabled: LyricsService.activePlayer !== null && LyricsService.status !== "loading"
            onClicked: LyricsService.restartLyrics()
            StyledToolTip {
                text: Translation.tr("Search the lyrics again")
            }
        }
    }

    ResizeHandler {
        anchorItem: root
        hoverActive: root.containsMouse
        locked: Config.options.background.widgetsLocked
        currentWidth: root.width
        resizeMode: "diagonal"
        strokeCol: root.textColor
        onResizedXY: (dx, dy, startWidth) => root.resizeBy(dx, dy, startWidth)
        onResizeFinished: root.commitFontSize()
    }
}
