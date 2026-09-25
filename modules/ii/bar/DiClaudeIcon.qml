import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services

// An AI agent's mark (assets/island/<agent>.svg: claude, codex, gemini), tinted with its brand color by default
Item {
    id: mark
    property string agent: "claude"
    property real size: 16
    readonly property color brandColor: ClaudeCode.agentColor(mark.agent)
    property color color: mark.brandColor
    implicitWidth: mark.size
    implicitHeight: mark.size

    Image {
        id: markImage
        anchors.fill: parent
        source: Quickshell.shellPath(`assets/island/${["claude", "codex", "gemini"].includes(mark.agent) ? mark.agent : "claude"}.svg`)
        sourceSize.width: mark.size * 2
        sourceSize.height: mark.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: markImage
        color: mark.color
    }
}
