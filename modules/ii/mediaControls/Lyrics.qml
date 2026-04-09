pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    required property MprisPlayer player
    property color textColor: "white"
    property color activeColor: "white"
    property color dimColor: Qt.rgba(1, 1, 1, 0.35)
    
    property color indicatorColor: "red"
    property color indicatorShapeColor: "blue"

    property var lyricsLines: []
    property int activeIndex: -1
    property string status: "loading"

    readonly property int before: 3
    readonly property int after:  3
    readonly property int total:  7

    function buildSlots(idx) {
        let result = []
        for (let i = 0; i < root.total; i++) {
            let lineIdx = idx - root.before + i
            if (lineIdx >= 0 && lineIdx < root.lyricsLines.length) {
                result.push(root.lyricsLines[lineIdx].text || "♪")
            } else {
                result.push("")
            }
        }
        return result
    }

    property var slots: ["", "", "", "", "", "", ""]

    Timer {
        id: syncTimer
        interval: 300
        repeat: true
        running: root.status === "ok" && root.lyricsLines.length > 0
        onTriggered: {
            const pos = root.player?.position ?? 0
            let idx = -1
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= pos) {
                    idx = i
                } else {
                    break
                }
            }
            if (idx !== root.activeIndex) {
                root.activeIndex = idx
                root.slots = root.buildSlots(idx)
            }
        }
    }

    Process {
        id: lyricsProc
        running: false

        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (trimmed === "not_found") { root.status = "not_found"; return }
                if (trimmed === "no_info") { root.status = "no_info"; return }

                const parts = trimmed.split("§")
                if (parts.length < 3) return
                const last = parts[parts.length - 1].trim()
                if (last !== "ok") return

                let lines = []
                for (let i = 0; i < parts.length - 1; i += 2) {
                    const t = parseFloat(parts[i])
                    const txt = parts[i + 1] || ""
                    if (!isNaN(t)) { lines.push({ time: t, text: txt }) }
                }

                if (lines.length === 0) { root.status = "not_found"; return }

                root.lyricsLines = lines
                root.activeIndex = -1
                root.slots = root.buildSlots(-1)
                root.status = "ok"
            }
        }
    }

    function restartLyrics() {
        lyricsProc.running = false
        root.lyricsLines = []
        root.activeIndex = -1
        root.slots = ["", "", "", "", "", "", ""]
        root.status = "loading"

        const title    = root.player?.trackTitle  ?? ""
        const artist   = root.player?.trackArtist ?? ""
        const duration = root.player?.length       ?? 0

        if (!title || !artist) { root.status = "no_info"; return }

        lyricsProc.command = [
            "python3",
            `${Directories.scriptPath}/lyrics/lyrics.py`,
            title, artist, String(Math.floor(duration))
        ]
        lyricsProc.running = true
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.restartLyrics() }
    }

    Component.onCompleted: root.restartLyrics()

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.status !== "ok"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: indicatorBg
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    radius: 24
                    color: root.indicatorColor 

                    property double baseShapeSize: 48 * 0.7
                    property double leapZoomSize: baseShapeSize * 1.2
                    property double leapZoomProgress: 0
                    property int shapeIndex: 0
                    property double continuousRotation: 0
                    property double leapRotation: 0
                    rotation: continuousRotation + leapRotation

                    property list<var> shapes: [
                        MaterialShape.Shape.SoftBurst,
                        MaterialShape.Shape.Cookie9Sided,
                        MaterialShape.Shape.Pentagon,
                        MaterialShape.Shape.Pill,
                        MaterialShape.Shape.Sunny,
                        MaterialShape.Shape.Cookie4Sided,
                        MaterialShape.Shape.Oval,
                    ]

                    RotationAnimation on continuousRotation {
                        running: root.status === "loading"
                        duration: 12000; loops: Animation.Infinite
                        from: 0; to: 360
                    }

                    Timer {
                        interval: 800; running: root.status === "loading"; repeat: true
                        onTriggered: leapAnim.start()
                    }

                    ParallelAnimation {
                        id: leapAnim
                        PropertyAction { target: indicatorBg; property: "shapeIndex"; value: (indicatorBg.shapeIndex + 1) % indicatorBg.shapes.length }
                        RotationAnimation {
                            target: indicatorBg
                            direction: RotationAnimation.Shortest
                            property: "leapRotation"
                            to: (indicatorBg.leapRotation + 90) % 360
                            duration: 350
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: indicatorBg; property: "leapZoomProgress"
                            from: 0; to: 1; duration: 750
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.standard
                        }
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        shape: indicatorBg.shapes[indicatorBg.shapeIndex]
                        implicitSize: {
                            const leapZoomDiff = indicatorBg.leapZoomSize - indicatorBg.baseShapeSize
                            const progressFirstHalf = Math.min(indicatorBg.leapZoomProgress, 0.5) * 2
                            const progressSecondHalf = Math.max(indicatorBg.leapZoomProgress - 0.5, 0) * 2
                            return indicatorBg.baseShapeSize + leapZoomDiff * progressFirstHalf - leapZoomDiff * progressSecondHalf
                        }
                        // VÍNCULO CON EL COLOR DEL ICONO DE CARGA
                        color: root.indicatorShapeColor
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.status === "ok"
            spacing: 6

            Repeater {
                model: 7
                delegate: StyledText {
                    id: lyricSlot
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WordWrap
                    text: root.slots[index] ?? ""
                    readonly property int dist: Math.abs(index - root.before)
                    font.pixelSize: {
                        if (dist === 0) return Appearance.font.pixelSize.normal
                        if (dist === 1) return Appearance.font.pixelSize.small
                        return Appearance.font.pixelSize.smaller
                    }
                    opacity: {
                        if (dist === 0) return 1.0
                        if (dist === 1) return 0.6
                        if (dist === 2) return 0.35
                        return 0.15
                    }
                    color: dist === 0 ? root.activeColor : root.textColor
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}