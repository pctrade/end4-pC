import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// On a call (Vesktop/Discord): the app's mark, how long you've been talking, and the two controls you reach
// for mid-sentence — mic and headset — right on the pill. Muted shows in red, so a glance answers "can they
// hear me?".
Item {
    id: call
    required property Item di
    anchors.fill: parent

    readonly property bool muted: IslandEvents.callMuted
    readonly property bool deafened: IslandEvents.callDeafened

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 7
            rightMargin: 5
        }
        spacing: 8

        Item {
            implicitWidth: 28
            implicitHeight: 28

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ColorUtils.transparentize("#5865F2", 0.78)
            }
            DiBrandIcon {
                anchors.centerIn: parent
                source: Quickshell.shellPath("assets/island/apps/discord.svg")
                size: 15
                color: "#8C95FF"
            }
            // Live dot: the call is on
            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 8
                height: 8
                radius: 4
                color: IslandEvents.colorSuccess
                border.width: 1.5
                border.color: call.di.surfaceColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: IslandEvents.voiceCallMinutes < 1 ? Translation.tr("On a call") : Translation.tr("On a call · %1 min").arg(IslandEvents.voiceCallMinutes)
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: call.deafened ? Translation.tr("Deafened") : call.muted ? Translation.tr("Mic muted") : IslandEvents.callApp
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: call.muted || call.deafened ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                opacity: call.muted || call.deafened ? 1 : 0.65
                elide: Text.ElideRight
            }
        }

        CallButton {
            icon: call.muted ? "mic_off" : "mic"
            active: call.muted
            tip: call.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
            onTap: IslandEvents.toggleCallMute()
        }
        CallButton {
            icon: call.deafened ? "headset_off" : "headphones"
            active: call.deafened
            tip: call.deafened ? Translation.tr("Undeafen") : Translation.tr("Deafen")
            onTap: IslandEvents.toggleCallDeafen()
        }
    }

    component CallButton: Rectangle {
        id: button
        property string icon: ""
        property string tip: ""
        property bool active: false
        signal tap()
        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: button.active ? Appearance.colors.colError
            : buttonMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        scale: buttonMouse.pressed ? 0.9 : 1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }
        Behavior on scale {
            NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutCubic }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.icon
            iconSize: 16
            fill: 1
            color: button.active ? Appearance.colors.colOnError : Appearance.colors.colOnLayer2
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.tap()
        }

        StyledToolTip {
            extraVisibleCondition: buttonMouse.containsMouse
            text: button.tip
        }
    }
}
