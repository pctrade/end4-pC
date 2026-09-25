import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Every active island at once, with the quick controls that make sense for each
ColumnLayout {
    id: xo
    required property Item di
    spacing: 8
    implicitWidth: 380
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 380

    readonly property var ids: xo.di.persistentIds

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "stacks"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: `${xo.ids.length} ${Translation.tr("active islands")}`
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
    }

    Repeater {
        model: xo.ids

        delegate: Rectangle {
            id: card
            required property string modelData
            required property int index
            readonly property bool current: card.modelData === xo.di.primaryId
            Layout.fillWidth: true
            implicitHeight: card.modelData === "media" ? 64 : 46
            radius: 16
            color: card.current ? Appearance.colors.colPrimaryContainer : (cardMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1)
            opacity: 0
            transform: Translate { id: slideIn; y: 10 }

            Behavior on color {
                ColorAnimation { duration: 160 }
            }

            // Cards deal in one after another
            SequentialAnimation {
                running: true
                PauseAnimation { duration: card.index * 60 }
                ParallelAnimation {
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slideIn; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBack }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    xo.di.focusIsland(card.modelData)
                    xo.di.selectIsland(card.modelData)
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 10
                }
                spacing: 8

                Rectangle {
                    visible: card.modelData === "media" && (xo.di.activePlayer?.trackArtUrl ?? "") !== ""
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 10
                    clip: true
                    color: Appearance.colors.colLayer2

                    StyledImage {
                        anchors.fill: parent
                        source: parent.visible ? xo.di.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }
                }

                DiCapsule {
                    visible: !(card.modelData === "media" && (xo.di.activePlayer?.trackArtUrl ?? "") !== "")
                    di: xo.di
                    providerId: card.modelData
                    showLabel: false
                    textColor: card.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            switch (card.modelData) {
                                case "media": return xo.di.activePlayer?.trackTitle ?? ""
                                case "f1": return F1.sessionLive ? `${F1.session?.meeting ?? ""} · ${F1.sessionLabel(F1.session?.name ?? "")}` : (F1.nextSession ? F1.sessionLabel(F1.nextSession.name) : "F1")
                                case "activity": return IslandEvents.latestActivity?.title ?? ""
                                case "timer": return xo.di.timerValueText()
                                case "recording": return Translation.tr("Recording screen")
                                case "systemLoad": return Translation.tr("High CPU usage")
                                case "shelf": return Translation.tr("Drawer")
                                case "download": return IslandEvents.downloadFileName !== "" ? IslandEvents.downloadFileName
                                    : IslandEvents.formatBytes(IslandEvents.downloadRate, true)
                                case "songRec": return Translation.tr("Listening…")
                                default: return card.modelData
                            }
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: card.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: {
                            switch (card.modelData) {
                                case "media": return xo.di.activePlayer?.trackArtist ?? ""
                                case "f1": return F1.sessionLive ? `P${F1.focusDriver?.position ?? "-"} ${F1.focusDriver?.tla ?? ""} · ${F1.lap}/${F1.totalLaps}` : F1.formatCountdown(F1.secondsToNext)
                                case "activity": return IslandEvents.latestActivity?.subtitle ?? ""
                                case "shelf": return `${DropShelf.items.length} ${Translation.tr("files")}`
                                case "download": return `${IslandEvents.formatBytes(IslandEvents.downloadRate, true)} · ${IslandEvents.formatBytes(IslandEvents.burstBytes, false)} ${Translation.tr("downloaded")}`
                                case "recording": return xo.di.formatRecordingTime(xo.di.recordingElapsedSeconds)
                                default: return ""
                            }
                        }
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: card.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }

                // Quick controls
                Repeater {
                    model: {
                        switch (card.modelData) {
                            case "media": return [
                                { icon: "skip_previous", action: () => xo.di.activePlayer?.previous() },
                                { icon: xo.di.activePlayer?.isPlaying ? "pause" : "play_arrow", action: () => xo.di.activePlayer?.togglePlaying() },
                                { icon: "skip_next", action: () => xo.di.activePlayer?.next() }
                            ]
                            case "timer": return [
                                { icon: xo.di.timerRunning() ? "pause" : "play_arrow", action: () => xo.di.toggleActiveTimer() },
                                { icon: "stop", action: () => xo.di.resetActiveTimer() }
                            ]
                            default: return [{ icon: "open_in_full", action: () => xo.di.selectIsland(card.modelData) }]
                        }
                    }
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: buttonMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85) : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            iconSize: 18
                            fill: 1
                            color: card.current ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.action()
                        }
                    }
                }
            }
        }
    }
}
