import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: act
    required property Item di
    anchors {
        fill: parent
        leftMargin: 4
        rightMargin: 12
    }
    spacing: 8

    readonly property var activity: IslandEvents.latestActivity
    readonly property string state: act.activity?.state ?? "running"
    readonly property real progress: act.activity?.progress ?? -1
    readonly property bool isClaude: ["claude", "codex", "gemini"].includes(act.activity?.icon ?? "")
    readonly property color accent: act.state === "error" ? Appearance.colors.colError
        : act.state === "done" ? Appearance.m3colors.m3success
        : act.state === "attention" ? IslandEvents.colorAttention : Appearance.colors.colPrimary

    Item {
        implicitWidth: 26
        implicitHeight: 26

        CircularProgress {
            id: ring
            anchors.fill: parent
            implicitSize: 26
            lineWidth: 3
            visible: act.state === "running"
            value: act.progress >= 0 ? act.progress : 0.28
            colPrimary: act.accent
            colSecondary: ColorUtils.transparentize(act.accent, 0.75)

            spinning: act.state === "running" && act.progress < 0

            // Stepped instead of animated: a smooth 60 fps spin means the bar repaints sixty times a second for
            // a 26-pixel ring, and that alone measured around fifteen points of CPU. Sixteen steps per turn look
            // the same at this size and cost a quarter of that.
            Timer {
                interval: 60
                repeat: true
                running: ring.spinning
                onTriggered: ring.rotation = (ring.rotation + 22.5) % 360
            }

            onSpinningChanged: if (!ring.spinning) ring.rotation = 0
        }

        MaterialShapeWrappedMaterialSymbol {
            anchors.centerIn: parent
            wrappedShape: act.state === "running" ? MaterialShape.Shape.Circle : MaterialShape.Shape.Cookie9Sided
            color: act.state === "running" ? "transparent" : act.accent
            colSymbol: act.state === "running" ? act.accent : Appearance.colors.colOnPrimary
            text: act.state === "done" ? "check" : act.state === "error" ? "priority_high" : act.isClaude ? "" : (act.activity?.icon ?? "bolt")
            iconSize: act.state === "running" ? 13 : 15
            fill: 1
            padding: act.state === "running" ? 2 : 5

            // Waiting for you: a slow pulse until it's answered
            SequentialAnimation on scale {
                running: act.state === "attention"
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 1.12; duration: IslandMotion.long; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: IslandMotion.long; easing.type: Easing.InOutSine }
            }
        }

        DiClaudeIcon {
            anchors.centerIn: parent
            visible: act.isClaude && act.state !== "done" && act.state !== "error"
            agent: act.activity?.icon ?? "claude"
            size: act.state === "running" ? 13 : 15
            color: act.state === "attention" ? Appearance.colors.colOnPrimary : ClaudeCode.agentColor(act.activity?.icon ?? "claude")
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: act.activity?.title ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: act.activity?.subtitle ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    StyledText {
        id: startedLabel
        visible: act.di.hoverRevealed && act.activity !== null
        onVisibleChanged: if (visible) startedIn.restart()
        text: act.activity ? Qt.formatTime(new Date(act.activity.started), "hh:mm") : ""
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0

        NumberAnimation {
            id: startedIn
            target: startedLabel
            property: "opacity"
            from: 0
            to: 0.7
            duration: IslandMotion.medium
            easing.type: Easing.OutCubic
        }
    }

    StyledText {
        visible: act.state === "running" && act.progress >= 0
        text: `${Math.round(act.progress * 100)}%`
        font.pixelSize: Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }

    Rectangle {
        visible: IslandEvents.activities.length > 1
        implicitWidth: countText.implicitWidth + 8
        implicitHeight: 16
        radius: 8
        color: Appearance.colors.colSecondaryContainer

        StyledText {
            id: countText
            anchors.centerIn: parent
            text: `+${IslandEvents.activities.length - 1}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
}
