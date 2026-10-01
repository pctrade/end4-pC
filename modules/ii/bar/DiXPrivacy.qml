import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Privacy: who uses the mic, camera and screen now (or last), plus mic controls.
ColumnLayout {
    id: xp
    required property Item di
    spacing: 10
    implicitWidth: xp.wantedWidth

    readonly property bool hasHistory: IslandEvents.privacyLastUse.mic !== null
        || IslandEvents.privacyLastUse.camera !== null || IslandEvents.privacyLastUse.screen !== null
    readonly property bool wide: IslandEvents.anyPrivacy || xp.hasHistory
    readonly property real wantedWidth: xp.wide ? 532 : 372

    property real now: Date.now()
    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: xp.now = Date.now()
    }

    readonly property var mic: Audio.source
    readonly property bool micMuted: xp.mic?.audio?.muted ?? false
    readonly property real micVolume: xp.mic?.audio?.volume ?? 0

    readonly property var resources: [
        { key: "mic", icon: "mic", label: Translation.tr("Microphone"), color: IslandEvents.colorAttention },
        { key: "camera", icon: "videocam", label: Translation.tr("Camera"), color: "#30D158" },
        { key: "screen", icon: "screen_share", label: Translation.tr("Screen sharing"), color: "#30D158" }
    ]

    readonly property int inUseCount: (IslandEvents.micInUse ? 1 : 0) + (IslandEvents.cameraInUse ? 1 : 0)
        + (IslandEvents.screenInUse ? 1 : 0)

    function agoText(ms) {
        const minutes = Math.floor(Math.max(0, ms) / 60000)
        if (minutes < 1) return Translation.tr("just now")
        if (minutes < 60) return Translation.tr("%1 min ago").arg(minutes)
        if (minutes < 1440) return Translation.tr("%1 h ago").arg(Math.floor(minutes / 60))
        return Translation.tr("%1 d ago").arg(Math.floor(minutes / 1440))
    }

    function forText(ms) {
        const minutes = Math.floor(Math.max(0, ms) / 60000)
        if (minutes < 1) return Translation.tr("in use now")
        if (minutes < 60) return Translation.tr("in use · %1 min").arg(minutes)
        return Translation.tr("in use · %1 h %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60)
    }

    function openMixer() {
        Quickshell.execDetached(["bash", "-c", Config.options.apps.volumeMixer])
        xp.di.collapse()
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component ActionChip: Rectangle {
        id: chip
        property string icon
        property string label
        property bool active: false
        property var onTap: null
        property int order: 0
        implicitWidth: chipRow.implicitWidth + 24
        implicitHeight: 32
        radius: 16
        color: chip.active ? Appearance.colors.colPrimaryContainer
            : (chipMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: chip.icon
                iconSize: 17
                fill: 1
                color: chip.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
            }
        }

        DiCascade { target: chip; index: chip.order; pressed: chipMouse.pressed }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (chip.onTap) chip.onTap()
        }
    }

    component MicLevel: Rectangle {
        id: level
        property int order: 0
        implicitHeight: 32
        radius: 16
        color: levelMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        opacity: xp.mic?.audio ? 1 : 0.5

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        DiCascade { target: level; index: level.order }

        DiSpring {
            id: levelReveal
            stiffness: 55
            dampingRatio: 1
            epsilon: 0.002
        }
        Timer {
            interval: 250
            running: true
            onTriggered: levelReveal.target = 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            MaterialSymbol {
                text: xp.micMuted ? "mic_off" : "mic"
                iconSize: 16
                fill: 1
                color: Appearance.colors.colOnLayer1
                opacity: 0.8
            }
            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 6
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.15
                }
                Rectangle {
                    width: track.width * Math.min(1, xp.micVolume) * levelReveal.value
                    height: parent.height
                    radius: 3
                    color: xp.micMuted ? Appearance.colors.colOnLayer1 : Appearance.colors.colPrimary
                    opacity: xp.micMuted ? 0.35 : 1
                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.micro }
                    }
                }
            }
            StyledText {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(xp.micVolume * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer1
                opacity: 0.7
            }
        }

        MouseArea {
            id: levelMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !!xp.mic?.audio
            cursorShape: Qt.PointingHandCursor
            function setFrom(mx) {
                const p = track.mapFromItem(levelMouse, mx, 0).x
                const v = Math.max(0, Math.min(1, p / Math.max(1, track.width)))
                xp.mic.audio.volume = Math.round(v * 100) / 100
            }
            onPressed: mouse => levelMouse.setFrom(mouse.x)
            onPositionChanged: mouse => { if (levelMouse.pressed) levelMouse.setFrom(mouse.x) }
        }
    }

    component ResourceCard: Rectangle {
        id: card
        required property var res
        property int order: 0
        readonly property var apps: IslandEvents.privacy[card.res.key] ?? []
        readonly property bool live: card.apps.length > 0
        readonly property real since: IslandEvents.privacySince[card.res.key] ?? 0
        readonly property var last: IslandEvents.privacyLastUse[card.res.key]
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 12
        color: card.live ? Qt.alpha(card.res.color, 0.14) : Appearance.colors.colLayer1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.short }
        }

        DiCascade { target: card; index: card.order }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 12
            spacing: 10

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: card.res.color
                    visible: card.live
                    opacity: 0
                    SequentialAnimation on scale {
                        running: card.live
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.35; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 400 }
                    }
                    SequentialAnimation on opacity {
                        running: card.live
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 400 }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: card.live ? card.res.color : Appearance.colors.colLayer2
                    Behavior on color {
                        ColorAnimation { duration: IslandMotion.short }
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: card.res.icon
                        iconSize: 17
                        fill: 1
                        color: card.live ? "#111111" : Appearance.colors.colOnLayer1
                        opacity: card.live ? 1 : 0.55
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        Layout.fillWidth: true
                        text: card.res.label
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        text: card.live ? (card.since > 0 ? xp.forText(xp.now - card.since) : Translation.tr("in use now"))
                            : (card.last ? xp.agoText(xp.now - card.last.time) : "")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: card.live ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                        color: card.live ? card.res.color : Appearance.colors.colOnLayer0
                        opacity: card.live ? 1 : 0.55
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.live ? card.apps.join(", ")
                        : (card.last ? Translation.tr("Last: %1").arg(card.last.apps.join(", ")) : Translation.tr("Not used recently"))
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: card.live ? 0.8 : 0.55
                }
            }
        }
    }

    RowLayout {
        id: header
        Layout.fillWidth: true
        spacing: 8
        DiCascade { target: header; index: 0 }

        StyledText {
            text: Translation.tr("Privacy")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            visible: xp.wide
            text: IslandEvents.anyPrivacy
                ? (xp.inUseCount === 1 ? Translation.tr("1 in use") : Translation.tr("%1 in use").arg(xp.inUseCount))
                : Translation.tr("Nothing is using the microphone, camera or screen")
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: IslandEvents.anyPrivacy ? Font.DemiBold : Font.Normal
            color: IslandEvents.anyPrivacy ? (IslandEvents.micInUse ? IslandEvents.colorAttention : "#30D158")
                : Appearance.colors.colOnLayer0
            opacity: IslandEvents.anyPrivacy ? 1 : 0.55
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: xp.wide
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Repeater {
                model: xp.wide ? xp.resources.length : 0
                delegate: ResourceCard {
                    required property int index
                    res: xp.resources[index]
                    order: 1 + index
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 6

            ColumnLayout {
                id: micHead
                Layout.fillWidth: true
                spacing: 0
                DiCascade { target: micHead; index: 2 }
                SectionLabel {
                    text: Translation.tr("Input")
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: xp.mic?.description || xp.mic?.name || Translation.tr("No microphone")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer0
                }
            }

            ActionChip {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 12
                order: 3
                icon: xp.micMuted ? "mic_off" : "mic"
                label: xp.micMuted ? Translation.tr("Microphone muted") : Translation.tr("Mute microphone")
                active: xp.micMuted
                onTap: () => Audio.toggleMicMute()
            }
            MicLevel {
                Layout.fillWidth: true
                order: 4
            }
            ActionChip {
                Layout.fillWidth: true
                order: 5
                icon: "tune"
                label: Translation.tr("Volume control")
                onTap: () => xp.openMixer()
            }
        }
    }

    ColumnLayout {
        id: emptyState
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: !xp.wide
        spacing: 2
        DiCascade { target: emptyState; index: 1 }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "verified_user"
            iconSize: 30
            fill: 1
            color: Appearance.colors.colOnLayer0
            opacity: 0.35
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: Translation.tr("Nothing is using the microphone, camera or screen")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Apps that use them show up here")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.55
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: !xp.wide
        spacing: 6

        ActionChip {
            Layout.fillWidth: true
            order: 2
            icon: xp.micMuted ? "mic_off" : "mic"
            label: xp.micMuted ? Translation.tr("Microphone muted") : Translation.tr("Mute microphone")
            active: xp.micMuted
            onTap: () => Audio.toggleMicMute()
        }
        ActionChip {
            order: 3
            icon: "tune"
            label: Translation.tr("Volume control")
            onTap: () => xp.openMixer()
        }
    }
    MicLevel {
        Layout.fillWidth: true
        visible: !xp.wide
        order: 4
    }
}
