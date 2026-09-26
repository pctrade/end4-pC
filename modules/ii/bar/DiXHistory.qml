import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The events that already went by, newest first — the island's short-term memory
ColumnLayout {
    id: xh
    required property Item di
    spacing: 8
    implicitWidth: 400
    readonly property real wantedWidth: 400

    property double now: Date.now()

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: xh.now = Date.now()
    }

    function ago(time) {
        const seconds = Math.max(0, Math.round((xh.now - time) / 1000))
        if (seconds < 60) return Translation.tr("just now")
        if (seconds < 3600) return Translation.tr("%1 min ago").arg(Math.floor(seconds / 60))
        return Qt.formatDateTime(new Date(time), "HH:mm")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "history"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Recent events")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        Rectangle {
            visible: IslandEvents.eventLog.length > 0
            implicitWidth: clearRow.implicitWidth + 16
            implicitHeight: 26
            radius: 13
            color: clearMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

            RowLayout {
                id: clearRow
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    text: "delete_sweep"
                    iconSize: 14
                    fill: 1
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Clear")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandEvents.clearEventLog()
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: IslandEvents.eventLog.length === 0
        text: Translation.tr("Nothing has happened yet")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: IslandEvents.eventLog.slice(0, 12)

        delegate: Rectangle {
            id: entry
            required property var modelData
            readonly property bool actionable: entry.modelData.action !== null
            Layout.fillWidth: true
            implicitHeight: 46
            radius: 12
            color: entryMouse.containsMouse && entry.actionable ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

            Behavior on color {
                ColorAnimation { duration: IslandMotion.micro }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 9

                MaterialSymbol {
                    text: entry.modelData.icon
                    iconSize: 17
                    fill: 1
                    color: entry.modelData.kind === "error" ? Appearance.colors.colError : Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: -3

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.modelData.title
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: entry.modelData.subtitle
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    text: xh.ago(entry.modelData.time)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                }
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: entry.actionable
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const action = entry.modelData.action
                    if (action?.type === "file") IslandEvents.openDownload(action.path)
                    else if (action?.type === "command") IslandEvents.rerunCommand(action.data)
                    else if (action?.type === "notification") GlobalStates.sidebarRightOpen = true
                    xh.di.collapse()
                }
            }
        }
    }
}
