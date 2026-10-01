import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Screen recording view: elapsed time and stop on the left, file details on the right.
RowLayout {
    id: xr
    required property Item di
    spacing: 20
    implicitWidth: xr.wantedWidth
    readonly property real wantedWidth: 532

    readonly property int elapsed: xr.di.recordingElapsedSeconds
    readonly property string home: Quickshell.env("HOME") ?? ""

    property bool found: false
    property string filePath: ""
    property bool withAudio: false
    property bool region: false
    property string outputName: ""
    property real fileSize: -1
    property real rate: -1
    property real lastSize: -1
    property real lastRead: 0

    readonly property string folder: {
        if (xr.filePath !== "") return xr.filePath.substring(0, xr.filePath.lastIndexOf("/"))
        return (Config.options.screenRecord.savePath ?? "") || `${xr.home}/Videos`
    }
    readonly property string fileName: xr.filePath.substring(xr.filePath.lastIndexOf("/") + 1)

    function prettyPath(p) {
        return xr.home !== "" && p.startsWith(xr.home) ? "~" + p.substring(xr.home.length) : p
    }
    function clock(s) {
        const h = Math.floor(s / 3600)
        const m = Math.floor(s / 60) % 60
        const sec = s % 60
        const mm = m.toString().padStart(2, "0") + ":" + sec.toString().padStart(2, "0")
        return h > 0 ? `${h}:${mm}` : mm
    }
    function bytes(b) {
        if (b < 0) return "—"
        if (b < 1024) return `${Math.round(b)} B`
        if (b < 1024 * 1024) return `${Math.max(0, Math.round(b / 1024))} KB`
        if (b < 1024 * 1024 * 1024) return `${(b / 1048576).toFixed(1)} MB`
        return `${(b / 1073741824).toFixed(2)} GB`
    }
    function stop() {
        // The script toggles, so only call it when there really is a recorder to stop
        if (xr.found) Quickshell.execDetached([Directories.recordScriptPath])
        else xr.di.fakeRecording = false
        xr.di.collapse()
    }

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["sh", "-c", "p=$(pgrep -xn wf-recorder) || exit 0; readlink /proc/$p/cwd; tr '\\0' '\\n' < /proc/$p/cmdline"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "")
                if (lines.length < 2) return
                const cwd = lines[0]
                const args = lines.slice(1)
                let file = ""
                for (let i = 0; i < args.length; i++) {
                    const a = args[i]
                    if ((a === "-f" || a === "--file") && i + 1 < args.length) file = args[i + 1]
                    else if (a.startsWith("--file=")) file = a.substring(7)
                    else if (a === "-o" || a === "--output") xr.outputName = args[i + 1] ?? ""
                    else if (a === "-g" || a === "--geometry" || a.startsWith("--geometry=")) xr.region = true
                    else if (a === "-a" || a === "--audio" || a.startsWith("--audio=") || (a.startsWith("-a") && !a.startsWith("--"))) xr.withAudio = true
                }
                if (file === "") return
                if (file.startsWith("./")) file = file.substring(2)
                xr.filePath = file.startsWith("/") ? file : `${cwd}/${file}`
                xr.found = true
                sizeProc.running = true
            }
        }
    }

    Process {
        id: sizeProc
        command: ["stat", "-c", "%s", xr.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const size = parseInt(text.trim())
                if (isNaN(size)) return
                const now = Date.now()
                if (xr.lastSize >= 0 && now > xr.lastRead) xr.rate = Math.max(0, (size - xr.lastSize) / ((now - xr.lastRead) / 1000))
                xr.lastSize = size
                xr.lastRead = now
                xr.fileSize = size
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: xr.found
        onTriggered: sizeProc.running = true
    }

    DiSpring {
        id: tickReveal
        stiffness: 55
        dampingRatio: 1
        epsilon: 0.002
    }
    Timer {
        interval: 300
        running: true
        onTriggered: tickReveal.target = 1
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component InfoCard: Rectangle {
        id: card
        property string icon: ""
        property string value: ""
        property string label: ""
        property string trailing: ""
        property bool accent: false
        property var onTap: null
        readonly property bool pressedNow: cardMouse.pressed
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 12
        color: cardMouse.containsMouse && card.onTap ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        Behavior on color { ColorAnimation { duration: IslandMotion.micro } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            MaterialSymbol {
                text: card.icon
                iconSize: 18
                fill: 1
                color: card.accent ? Appearance.colors.colError : Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1
                StyledText {
                    Layout.fillWidth: true
                    text: card.value
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideMiddle
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
            MaterialSymbol {
                visible: card.trailing !== ""
                text: card.trailing
                iconSize: 16
                color: Appearance.colors.colOnLayer1
                opacity: cardMouse.containsMouse ? 0.9 : 0.5
                Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            enabled: card.onTap !== null
            hoverEnabled: true
            cursorShape: card.onTap ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.onTap) card.onTap()
        }
    }

    ColumnLayout {
        Layout.fillWidth: false
        Layout.preferredWidth: 196
        Layout.maximumWidth: 196
        Layout.alignment: Qt.AlignTop
        spacing: 6

        RowLayout {
            id: headRow
            Layout.fillWidth: true
            spacing: 8
            DiCascade { target: headRow; index: 0 }

            Item {
                implicitWidth: 14
                implicitHeight: 14

                Rectangle {
                    id: halo
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Appearance.colors.colError
                    SequentialAnimation {
                        running: true
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: halo; property: "width"; from: 10; to: 20; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "height"; from: 10; to: 20; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "opacity"; from: 0.8; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: Appearance.colors.colError
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }
            SectionLabel {
                Layout.fillWidth: true
                text: Translation.tr("Recording screen")
            }
        }

        StyledText {
            id: bigTime
            Layout.topMargin: -4
            text: xr.clock(xr.elapsed)
            font.pixelSize: 46
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            DiCascade { target: bigTime; index: 1 }
        }

        Item {
            id: ticker
            Layout.fillWidth: true
            implicitHeight: 12
            DiCascade { target: ticker; index: 2 }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 30
                    Rectangle {
                        required property int index
                        readonly property bool lit: index < Math.floor((xr.elapsed % 60) / 2) + 1
                        width: (ticker.width - 29 * 2) / 30
                        height: (lit ? 12 : 6) * tickReveal.value
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 1.5
                        color: lit ? Appearance.colors.colError : Appearance.colors.colLayer2
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: IslandMotion.micro } }
                    }
                }
            }
        }

        StyledText {
            id: modeText
            Layout.fillWidth: true
            text: !xr.found ? Translation.tr("Waiting for the recorder")
                : xr.region ? Translation.tr("Selected area")
                : xr.outputName !== "" ? Translation.tr("Full screen · %1").arg(xr.outputName)
                : Translation.tr("Full screen")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
            elide: Text.ElideRight
            DiCascade { target: modeText; index: 3 }
        }

        Rectangle {
            id: stopButton
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 40
            radius: stopMouse.containsMouse ? 12 : 20
            color: stopMouse.containsMouse ? Qt.darker(Appearance.colors.colError, 1.08) : Appearance.colors.colError
            DiCascade { target: stopButton; index: 4; pressed: stopMouse.pressed }
            Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: IslandMotion.micro } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "stop"
                    iconSize: 20
                    fill: 1
                    color: Appearance.colors.colOnError
                }
                StyledText {
                    text: Translation.tr("Stop and save")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnError
                }
            }

            MouseArea {
                id: stopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: xr.stop()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 6

        SectionLabel {
            id: fileLabel
            text: Translation.tr("File")
            DiCascade { target: fileLabel; index: 1 }
        }

        InfoCard {
            id: fileCard
            icon: "movie"
            value: xr.fileName !== "" ? xr.fileName : Translation.tr("No file yet")
            label: xr.fileSize < 0 ? Translation.tr("Size appears once writing starts")
                : xr.rate > 0 ? Translation.tr("%1 · %2/s").arg(xr.bytes(xr.fileSize)).arg(xr.bytes(xr.rate))
                : xr.bytes(xr.fileSize)
            DiCascade { target: fileCard; index: 2 }
        }

        InfoCard {
            id: folderCard
            icon: "folder"
            value: xr.prettyPath(xr.folder)
            label: Translation.tr("Open folder")
            trailing: "open_in_new"
            onTap: () => Quickshell.execDetached(["xdg-open", xr.folder])
            DiCascade { target: folderCard; index: 3; pressed: folderCard.pressedNow }
        }

        SectionLabel {
            id: captureLabel
            Layout.topMargin: 2
            text: Translation.tr("Capturing")
            DiCascade { target: captureLabel; index: 4 }
        }

        RowLayout {
            id: captureRow
            Layout.fillWidth: true
            spacing: 6
            DiCascade { target: captureRow; index: 5 }

            InfoCard {
                Layout.preferredWidth: 1
                icon: xr.region ? "crop_free" : "desktop_windows"
                value: xr.region ? Translation.tr("Area") : Translation.tr("Screen")
                label: Translation.tr("Video")
            }
            // Audio is the system output (the script records the sink monitor, not the mic); muting the
            // output also silences it in the file
            InfoCard {
                readonly property bool muted: Audio.sink?.audio?.muted ?? false
                Layout.preferredWidth: 1
                icon: !xr.withAudio ? "volume_off" : muted ? "volume_off" : "volume_up"
                accent: xr.withAudio && muted
                value: !xr.withAudio ? Translation.tr("No audio")
                    : muted ? Translation.tr("Muted") : Translation.tr("System audio")
                label: !xr.withAudio ? Translation.tr("Video only")
                    : muted ? Translation.tr("Tap to unmute") : Translation.tr("Tap to mute")
                onTap: xr.withAudio ? (() => { if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted }) : null
            }
        }
    }
}
