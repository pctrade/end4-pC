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

    // When the date earns its place: hovering, the weekend (when days blur together), the first hour of a new
    // day, and the first minutes after the machine woke up — the three moments you actually ask "what day is it".
    // Home has room, so the date lives here full time — quiet next to the clock, and brighter on the days when
    // it is the thing you are actually asking about. Hovering spells out the long date with the weather, so the
    // short one steps aside then instead of repeating itself.
    readonly property bool dateWorthShowing: !diIdleRoot.di.hoverRevealed && (diIdleRoot.di.cfg.anchorDate ?? true)

    // One row for everything: the photo is a layout item, not an overlay, so a hover that reveals more text
    // pushes the row instead of sliding under the photo. If the island still runs out of room the
    // spacer collapses and the long texts elide, and nothing is ever covered.
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

        // Breathing room between the photo and the indicators; the first thing to give way when space runs short
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 6
            implicitWidth: 10
        }

        RowLayout {
            id: iconsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.source?.audio?.muted ?? false)
                MaterialSymbol {
                    text: "mic_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }
            }

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere && (Audio.sink?.audio?.muted ?? false)
                MaterialSymbol {
                    text: "volume_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }
            }

            Revealer {
                reveal: !diIdleRoot.systemIconsElsewhere
                    && !Network.ethernet
                    && (Network.wifiStatus === "disconnected" || Network.wifiStatus === "disabled")
                MaterialSymbol {
                    text: "wifi_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colError
                }
            }

            // Pending updates with their count; a click opens yay in a terminal
            Revealer {
                reveal: (diIdleRoot.di.cfg.updatesIndicator ?? true) && Updates.updateAdvised
                Item {
                    implicitWidth: updatesRow.implicitWidth
                    implicitHeight: updatesRow.implicitHeight

                    RowLayout {
                        id: updatesRow
                        spacing: 2
                        MaterialSymbol {
                            text: "system_update_alt"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Updates.updateStronglyAdvised ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: `${Updates.count}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Updates.updateStronglyAdvised ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandEvents.runSystemUpdate()
                    }
                }
            }

            // Open AI agent sessions: ONE mark — whichever agent needs you most — plus a count when there's
            // more than one. Repeating a mark per agent read as a rendering glitch (two near-identical orange
            // marks), when what mattered was just "an agent is open", not "here is every agent".
            Revealer {
                reveal: (diIdleRoot.di.cfg.claudeCode ?? true) && ClaudeCode.openCount > 0
                Item {
                    implicitWidth: agentsRow.implicitWidth
                    implicitHeight: agentsRow.implicitHeight

                    readonly property string leadAgent: {
                        const waiting = ClaudeCode.liveSessions.find(s => s.state === "waiting")
                        if (waiting) return waiting.agent
                        const working = ClaudeCode.liveSessions.find(s => s.state === "working")
                        if (working) return working.agent
                        return ClaudeCode.openAgents[0] ?? "claude"
                    }

                    RowLayout {
                        id: agentsRow
                        spacing: 4

                        Item {
                            id: agentMark
                            readonly property string modelData: parent.parent.leadAgent
                            readonly property real used: ClaudeCode.limits[agentMark.modelData]?.five ?? -1
                            readonly property bool waiting: ClaudeCode.liveSessions.some(s => s.agent === agentMark.modelData && s.state === "waiting")
                            readonly property bool working: ClaudeCode.liveSessions.some(s => s.agent === agentMark.modelData && s.state === "working")
                            implicitWidth: 20
                            implicitHeight: 20

                            CircularProgress {
                                anchors.fill: parent
                                visible: agentMark.used >= 0
                                implicitSize: 20
                                lineWidth: 2
                                value: Math.max(0, Math.min(1, agentMark.used / 100))
                                colPrimary: agentMark.used >= 95 ? IslandEvents.colorError : agentMark.used >= 80 ? IslandEvents.colorAttention : Appearance.colors.colPrimary
                                colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
                            }
                            DiClaudeIcon {
                                anchors.centerIn: parent
                                agent: agentMark.modelData
                                size: 11
                                color: agentMark.waiting ? IslandEvents.colorAttention : ClaudeCode.agentColor(agentMark.modelData)
                                opacity: agentMark.working || agentMark.waiting ? 1 : 0.75

                                SequentialAnimation on scale {
                                    running: agentMark.waiting
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true
                                    NumberAnimation { to: 1.25; duration: 520; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                        // Only the percentage: the agent's own mark already says which one it is
                        Revealer {
                            reveal: diIdleRoot.di.hoverRevealed && ClaudeCode.limits[agentMark.modelData]
                            StyledText {
                                text: ClaudeCode.limits[agentMark.modelData] ? `${Math.round(ClaudeCode.limits[agentMark.modelData].five)}%` : ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnLayer0
                                opacity: 0.75
                            }
                        }
                        StyledText {
                            visible: ClaudeCode.openCount > 1
                            text: `+${ClaudeCode.openCount - 1}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.6
                        }
                    }
                }
            }

            Revealer {
                reveal: F1.enabled && F1.nextSession !== null && F1.secondsToNext > 0 && F1.secondsToNext < 24 * 3600
                MaterialSymbol {
                    text: "sports_motorsports"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
            }

            // Do not disturb is easy to forget you turned on; the island says so as long as it is on
            Revealer {
                reveal: Notifications.silent
                Item {
                    implicitWidth: dndRow.implicitWidth
                    implicitHeight: dndRow.implicitHeight

                    RowLayout {
                        id: dndRow
                        spacing: 3
                        MaterialSymbol {
                            text: "notifications_off"
                            iconSize: Appearance.font.pixelSize.normal
                            fill: 1
                            color: IslandEvents.colorAttention
                        }
                        StyledText {
                            visible: diIdleRoot.di.hoverRevealed
                            text: Translation.tr("Do not disturb")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: IslandEvents.colorAttention
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.silent = false
                    }
                }
            }

            Revealer {
                reveal: (Notifications.unread ?? 0) > 0
                Item {
                    implicitWidth: notifRow.implicitWidth
                    implicitHeight: notifRow.implicitHeight

                    RowLayout {
                        id: notifRow
                        spacing: 2
                        MaterialSymbol {
                            text: "notifications"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: `${Notifications.unread}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                    }
                }
            }
        }

        // Weather and date, revealed on hover. Elides before anything else is pushed off.
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

        // The date, shown when it is worth knowing rather than always: on the weekend, on the first hour after
        // the day turned, after coming back from sleep into a new day, or whenever there is room on hover.
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

        StyledText {
            Layout.alignment: Qt.AlignVCenter
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

        readonly property real computedIdleWidth: row.implicitWidth + row.anchors.leftMargin + row.anchors.rightMargin

        onComputedIdleWidthChanged: diIdleRoot.di.idleTextContentWidth = row.computedIdleWidth
        Component.onCompleted: diIdleRoot.di.idleTextContentWidth = row.computedIdleWidth
    }
}
