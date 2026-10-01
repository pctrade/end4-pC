import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Home, compact: photo, one glance line for the most relevant thing, the time.
Item {
    id: diIdleRoot
    required property Item di
    anchors.fill: parent

    readonly property bool systemIconsElsewhere:
        Config.options.bar.layouts.leftLayout.includes("systemIcons")
        || Config.options.bar.layouts.rightLayout.includes("systemIcons")

    readonly property string avatarFile: Config.options.profile.avatarPicture || Config.options.profile.avatarPath || `${Quickshell.env("HOME")}/.face`

    readonly property string displayFont: {
        switch (diIdleRoot.di.cfg.anchorFont ?? "expressive") {
            case "numbers":   return Appearance.font.family.numbers
            case "monospace": return Appearance.font.family.monospace
            case "main":      return Appearance.font.family.main
            default:          return Appearance.font.family.expressive
        }
    }

    readonly property bool agentsOn: diIdleRoot.di.cfg.claudeCode ?? true
    readonly property var waitingSession: diIdleRoot.agentsOn ? (ClaudeCode.liveSessions.find(s => s.state === "waiting") ?? null) : null
    readonly property var workingSession: diIdleRoot.agentsOn ? (ClaudeCode.liveSessions.find(s => s.state === "working") ?? null) : null
    readonly property string agent: diIdleRoot.waitingSession?.agent ?? diIdleRoot.workingSession?.agent ?? (ClaudeCode.openAgents[0] ?? "claude")
    readonly property real agentUsed: ClaudeCode.limits[diIdleRoot.agent]?.five ?? -1
    readonly property int unread: Notifications.unread ?? 0
    readonly property var lastNotif: diIdleRoot.unread > 0 ? (Notifications.list[Notifications.list.length - 1] ?? null) : null
    readonly property bool updatesOn: (diIdleRoot.di.cfg.updatesIndicator ?? true) && Updates.updateAdvised
    readonly property bool hasWeather: (Weather.data?.temp ?? "") !== ""

    function agentName(a) {
        return a === "codex" ? "Codex" : a === "gemini" ? "Gemini" : "Claude"
    }
    function capitalize(t) {
        return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : t
    }

    readonly property string glanceKind: {
        if (diIdleRoot.waitingSession) return "agentWaiting"
        if (diIdleRoot.lastNotif) return "notification"
        if (diIdleRoot.workingSession) return "agentWorking"
        if (diIdleRoot.updatesOn && Updates.updateStronglyAdvised) return "updates"
        return "day"
    }

    readonly property var glance: {
        switch (diIdleRoot.glanceKind) {
            case "agentWaiting": return {
                title: diIdleRoot.agentName(diIdleRoot.agent),
                sub: Translation.tr("Waiting for you"),
                tone: IslandEvents.colorAttention
            }
            case "notification": {
                const n = diIdleRoot.lastNotif
                return {
                    title: n.appName || Translation.tr("Notification"),
                    sub: n.summary || n.body || "",
                    tone: IslandEvents.appColor(n.appName, Appearance.colors.colPrimary)
                }
            }
            case "agentWorking": return {
                title: diIdleRoot.agentName(diIdleRoot.agent),
                sub: diIdleRoot.agentUsed >= 0 ? Translation.tr("Working · %1% of 5h").arg(Math.round(diIdleRoot.agentUsed)) : Translation.tr("Working"),
                tone: ClaudeCode.agentColor(diIdleRoot.agent)
            }
            case "updates": return {
                title: Translation.tr("%1 updates").arg(Updates.count),
                sub: Translation.tr("Tap to update"),
                tone: Appearance.colors.colError
            }
            default: return {
                title: diIdleRoot.capitalize(Qt.locale().toString(DateTime.clock.date, "dddd, d MMM")),
                sub: diIdleRoot.hasWeather
                    ? [Weather.data.temp, diIdleRoot.capitalize(Weather.data.description ?? "")].filter(Boolean).join(" · ")
                    : "",
                tone: Appearance.colors.colOnLayer0
            }
        }
    }

    function openGlance() {
        switch (diIdleRoot.glanceKind) {
            case "agentWaiting":
            case "agentWorking": diIdleRoot.di.expand("agents"); break
            case "notification": GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen; break
            case "updates": IslandEvents.runSystemUpdate(); break
            default: diIdleRoot.di.expand("weather")
        }
    }

    component StatusGlyph: Item {
        id: glyph
        property string icon
        property color tone: Appearance.colors.colOnLayer0
        property bool toned: false
        property bool filled: false
        property bool dot: false
        property var onTap: null
        implicitWidth: 22
        implicitHeight: 22

        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: Appearance.colors.colLayer2
            opacity: glyphMouse.containsMouse ? 1 : 0
            scale: glyphMouse.containsMouse ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
            Behavior on scale { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: glyph.icon
            iconSize: 15
            fill: glyph.filled ? 1 : 0
            color: glyph.tone
            opacity: glyph.toned || glyphMouse.containsMouse ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
        }

        Rectangle {
            visible: glyph.dot
            anchors { right: parent.right; top: parent.top; margins: 3 }
            width: 5
            height: 5
            radius: 2.5
            color: glyph.toned ? glyph.tone : Appearance.colors.colPrimary
        }

        MouseArea {
            id: glyphMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: glyph.onTap ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (glyph.onTap) glyph.onTap()
        }
    }

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: diIdleRoot.di.isMaterial ? 0 : 4
            rightMargin: 12
        }
        spacing: 9

        Item {
            id: avatarBox
            Layout.preferredWidth: diIdleRoot.di.isMaterial ? diIdleRoot.di.pillHeight : diIdleRoot.di.pillHeight - 8
            Layout.preferredHeight: avatarBox.Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: avatarRect
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colPrimaryContainer

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: diIdleRoot.avatarFile.startsWith("file://") ? diIdleRoot.avatarFile : `file://${diIdleRoot.avatarFile}`
                    sourceSize.width: avatarImage.width * 2
                    sourceSize.height: avatarImage.height * 2
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatarRect.width
                            height: avatarRect.height
                            radius: avatarRect.radius
                        }
                    }
                }
            }

            Rectangle {
                readonly property bool on: diIdleRoot.unread > 0 && diIdleRoot.glanceKind !== "notification"
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: -1; bottomMargin: -1 }
                width: 9
                height: 9
                radius: 4.5
                color: Appearance.colors.colPrimary
                border.width: 2
                border.color: Appearance.colors.colLayer0
                scale: on ? 1 : 0
                Behavior on scale { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
            }
        }

        Item {
            id: glanceBox
            readonly property real textWidth: Math.min(200, Math.max(glanceTitle.implicitWidth, glanceSub.text !== "" ? glanceSub.implicitWidth : 0))
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: glanceBox.textWidth
            Layout.minimumWidth: 0
            Layout.fillHeight: true

            Column {
                id: glanceCol
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: -2

                StyledText {
                    id: glanceTitle
                    width: parent.width
                    text: diIdleRoot.glance.title
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: diIdleRoot.glanceKind === "day" ? Appearance.colors.colOnLayer0 : diIdleRoot.glance.tone
                    elide: Text.ElideRight
                }
                StyledText {
                    id: glanceSub
                    width: parent.width
                    visible: text !== ""
                    text: diIdleRoot.glance.sub
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.62
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: diIdleRoot.glanceKind === "notification" && diIdleRoot.unread > 1
                anchors { left: parent.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                height: 14
                width: Math.max(14, moreText.implicitWidth + 8)
                radius: 7
                color: ColorUtils.transparentize(diIdleRoot.glance.tone, 0.8)
                StyledText {
                    id: moreText
                    anchors.centerIn: parent
                    text: `${diIdleRoot.unread}`
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    color: diIdleRoot.glance.tone
                }
            }

            ParallelAnimation {
                id: glanceIn
                NumberAnimation { target: glanceCol; property: "opacity"; from: 0; to: 1; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
                NumberAnimation { target: glanceCol; property: "anchors.verticalCenterOffset"; from: 5; to: 0; duration: IslandMotion.medium; easing.type: Easing.OutCubic }
            }
            Connections {
                target: diIdleRoot
                function onGlanceKindChanged() { glanceIn.restart() }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    diIdleRoot.di.childTapAt = Date.now()
                    diIdleRoot.openGlance()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: diIdleRoot.glanceKind === "notification" && diIdleRoot.unread > 1 ? 24 : 4
        }

        RowLayout {
            id: iconsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.source?.audio?.muted ?? false)
                StatusGlyph {
                    icon: "mic_off"
                    tone: IslandEvents.colorAttention
                    toned: true
                    onTap: () => { if (Audio.source?.audio) Audio.source.audio.muted = false }
                }
            }
            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.sink?.audio?.muted ?? false)
                StatusGlyph {
                    icon: "volume_off"
                    onTap: () => { if (Audio.sink?.audio) Audio.sink.audio.muted = false }
                }
            }
            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere
                    && !Network.ethernet
                    && (Network.wifiStatus === "disconnected" || Network.wifiStatus === "disabled")
                StatusGlyph {
                    icon: "wifi_off"
                    tone: Appearance.colors.colError
                    toned: true
                    onTap: () => diIdleRoot.di.expand("download")
                }
            }
            Revealer {
                reveal: Notifications.silent
                StatusGlyph {
                    icon: "notifications_off"
                    tone: IslandEvents.colorAttention
                    toned: true
                    filled: true
                    onTap: () => Notifications.silent = false
                }
            }
            Revealer {
                reveal: IslandEvents.focusOn
                StatusGlyph {
                    icon: "psychology"
                    tone: IslandEvents.colorAttention
                    toned: true
                    dot: IslandEvents.focusSuppressedCount > 0
                    onTap: () => IslandEvents.toggleFocus()
                }
            }
            Revealer {
                reveal: F1.enabled && F1.nextSession !== null && F1.secondsToNext > 0 && F1.secondsToNext < 24 * 3600
                StatusGlyph {
                    icon: "sports_motorsports"
                    tone: Appearance.colors.colPrimary
                    toned: F1.secondsToNext < 3600
                    onTap: () => diIdleRoot.di.expand("f1")
                }
            }

            Revealer {
                reveal: (diIdleRoot.waitingSession || diIdleRoot.workingSession) !== null
                    && !diIdleRoot.glanceKind.startsWith("agent")
                Item {
                    implicitWidth: 22
                    implicitHeight: 22
                    CircularProgress {
                        anchors.centerIn: parent
                        visible: diIdleRoot.agentUsed >= 0
                        implicitSize: 17
                        lineWidth: 2
                        value: Math.max(0, Math.min(1, diIdleRoot.agentUsed / 100))
                        colPrimary: diIdleRoot.agentUsed >= 95 ? IslandEvents.colorError : diIdleRoot.agentUsed >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                        colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                    }
                    DiClaudeIcon {
                        anchors.centerIn: parent
                        agent: diIdleRoot.agent
                        size: 9
                        color: ClaudeCode.agentColor(diIdleRoot.agent)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: diIdleRoot.di.expand("agents")
                    }
                }
            }
            Revealer {
                reveal: diIdleRoot.updatesOn && diIdleRoot.glanceKind !== "updates"
                StatusGlyph {
                    icon: "system_update_alt"
                    dot: true
                    tone: Updates.updateStronglyAdvised ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    toned: Updates.updateStronglyAdvised
                    onTap: () => IslandEvents.runSystemUpdate()
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: Config.options.bar.dynamicIsland.leftWidget === "clockWidget" ? weatherComponent : clockComponent

            Component {
                id: clockComponent
                StyledText {
                    text: DateTime.time
                    font.family: diIdleRoot.displayFont
                    font.pixelSize: diIdleRoot.di.isMaterial ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            diIdleRoot.di.childTapAt = Date.now()
                            diIdleRoot.di.expandTo(2, "idle")
                        }
                    }
                }
            }

            Component {
                id: weatherComponent
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        fill: 0
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer0
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledText {
                        font.pixelSize: diIdleRoot.di.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                        text: Weather.data?.temp ?? "--°"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        readonly property real computedIdleWidth: row.implicitWidth + row.anchors.leftMargin + row.anchors.rightMargin

        onComputedIdleWidthChanged: diIdleRoot.di.idleTextContentWidth = row.computedIdleWidth
        Component.onCompleted: diIdleRoot.di.idleTextContentWidth = row.computedIdleWidth
    }
}
