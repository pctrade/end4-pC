import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

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

    component StatusGlyph: Item {
        id: glyph
        property string icon
        property color tone: Appearance.colors.colOnLayer0
        property bool toned: false
        property bool filled: false
        property string badge: ""
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
            opacity: glyph.toned || glyphMouse.containsMouse ? 1 : 0.72
            Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
        }

        Rectangle {
            visible: glyph.badge !== ""
            anchors { right: parent.right; top: parent.top }
            height: 11
            width: Math.max(11, badgeText.implicitWidth + 5)
            radius: 5.5
            color: glyph.toned ? glyph.tone : Appearance.colors.colPrimary
            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: glyph.badge
                font.pixelSize: 8
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnPrimary
            }
        }

        MouseArea {
            id: glyphMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: glyph.onTap ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (glyph.onTap) glyph.onTap()
        }
    }

    readonly property bool dateWorthShowing: !diIdleRoot.di.hoverRevealed && (diIdleRoot.di.cfg.anchorDate ?? true)

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: diIdleRoot.di.isMaterial ? 0 : 4
            rightMargin: 10
        }
        spacing: 8

        Rectangle {
            id: avatarRect
            Layout.preferredWidth: diIdleRoot.di.isMaterial ? diIdleRoot.di.pillHeight : diIdleRoot.di.pillHeight - 8
            Layout.preferredHeight: avatarRect.Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
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

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 6
            implicitWidth: 10
        }

        RowLayout {
            id: iconsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

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
                reveal: (diIdleRoot.di.cfg.updatesIndicator ?? true) && Updates.updateAdvised
                StatusGlyph {
                    icon: "system_update_alt"
                    badge: `${Updates.count}`
                    tone: Updates.updateStronglyAdvised ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                    toned: Updates.updateStronglyAdvised
                    onTap: () => IslandEvents.runSystemUpdate()
                }
            }

            Revealer {
                reveal: (diIdleRoot.di.cfg.claudeCode ?? true) && ClaudeCode.openCount > 0
                Item {
                    id: agentMark
                    readonly property string agent: {
                        const waiting = ClaudeCode.liveSessions.find(s => s.state === "waiting")
                        if (waiting) return waiting.agent
                        const working = ClaudeCode.liveSessions.find(s => s.state === "working")
                        if (working) return working.agent
                        return ClaudeCode.openAgents[0] ?? "claude"
                    }
                    readonly property real used: ClaudeCode.limits[agentMark.agent]?.five ?? -1
                    readonly property bool waiting: ClaudeCode.liveSessions.some(s => s.agent === agentMark.agent && s.state === "waiting")
                    readonly property bool working: ClaudeCode.liveSessions.some(s => s.agent === agentMark.agent && s.state === "working")
                    implicitWidth: 22
                    implicitHeight: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: Appearance.colors.colLayer2
                        opacity: agentMouse.containsMouse ? 1 : 0
                        scale: agentMouse.containsMouse ? 1 : 0.6
                        Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
                        Behavior on scale { NumberAnimation { duration: IslandMotion.short; easing.type: Easing.OutBack } }
                    }

                    CircularProgress {
                        anchors.centerIn: parent
                        visible: agentMark.used >= 0
                        implicitSize: 18
                        lineWidth: 2
                        value: Math.max(0, Math.min(1, agentMark.used / 100))
                        colPrimary: agentMark.used >= 95 ? IslandEvents.colorError : agentMark.used >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                        colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                    }

                    DiClaudeIcon {
                        anchors.centerIn: parent
                        agent: agentMark.agent
                        size: 10
                        color: agentMark.waiting ? IslandEvents.colorAttention : ClaudeCode.agentColor(agentMark.agent)
                        opacity: agentMark.working || agentMark.waiting ? 1 : 0.72

                        SequentialAnimation on scale {
                            running: agentMark.waiting
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 1.25; duration: IslandMotion.long; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: IslandMotion.long; easing.type: Easing.InOutSine }
                        }
                    }

                    Rectangle {
                        visible: ClaudeCode.openCount > 1
                        anchors { right: parent.right; top: parent.top }
                        height: 11
                        width: Math.max(11, agentCount.implicitWidth + 5)
                        radius: 5.5
                        color: Appearance.colors.colPrimary
                        StyledText {
                            id: agentCount
                            anchors.centerIn: parent
                            text: `${ClaudeCode.openCount}`
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    MouseArea {
                        id: agentMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: diIdleRoot.di.expand("agents")
                    }
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
                    badge: IslandEvents.focusSuppressedCount > 0 ? `${IslandEvents.focusSuppressedCount}` : ""
                    onTap: () => IslandEvents.toggleFocus()
                }
            }

            Revealer {
                reveal: (Notifications.unread ?? 0) > 0
                StatusGlyph {
                    icon: "notifications"
                    badge: `${Notifications.unread}`
                    onTap: () => GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
            }
        }

        Revealer {
            id: detailRevealer
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 0
            reveal: diIdleRoot.di.hoverRevealed

            RowLayout {
                spacing: 5

                MaterialSymbol {
                    visible: (Weather.data?.temp ?? "") !== ""
                    text: IslandEvents.weatherSymbol(Weather.data?.wCode ?? 800)
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 1
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.85
                }
                StyledText {
                    Layout.minimumWidth: 0
                    text: `${(Weather.data?.temp ?? "") !== "" ? Weather.data.temp + "   " : ""}${DateTime.longDate}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: diIdleRoot.di.hoverRevealed
                cursorShape: Qt.PointingHandCursor
                onClicked: diIdleRoot.di.expand("weather")
            }
        }

        Revealer {
            Layout.alignment: Qt.AlignVCenter
            reveal: diIdleRoot.dateWorthShowing

            StyledText {
                text: DateTime.shortDate
                font.family: diIdleRoot.displayFont
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                opacity: diIdleRoot.di.dateIsNews ? 0.9 : 0.55
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
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: diIdleRoot.di.expandTo(2, "calendar")
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
