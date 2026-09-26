import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Expanded call: the four things you do on a call, as big targets — mute, deafen, open the call, leave.
ColumnLayout {
    id: xcall
    required property Item di
    spacing: 12
    implicitWidth: 340
    readonly property real wantedWidth: 340

    readonly property bool muted: IslandEvents.callMuted
    readonly property bool deafened: IslandEvents.callDeafened

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            color: ColorUtils.transparentize("#5865F2", 0.75)
            DiBrandIcon {
                anchors.centerIn: parent
                source: Quickshell.shellPath("assets/island/apps/discord.svg")
                size: 21
                color: "#8C95FF"
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: -2
            StyledText {
                text: Translation.tr("On a call")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                text: `${IslandEvents.callApp} · ${IslandEvents.voiceCallMinutes < 1 ? Translation.tr("just started") : Translation.tr("%1 min").arg(IslandEvents.voiceCallMinutes)}`
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.65
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        BigButton {
            icon: xcall.muted ? "mic_off" : "mic"
            label: xcall.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
            active: xcall.muted
            onTap: IslandEvents.toggleCallMute()
        }
        BigButton {
            icon: xcall.deafened ? "headset_off" : "headphones"
            label: xcall.deafened ? Translation.tr("Undeafen") : Translation.tr("Deafen")
            active: xcall.deafened
            onTap: IslandEvents.toggleCallDeafen()
        }
        BigButton {
            icon: "open_in_new"
            label: Translation.tr("Open")
            onTap: {
                IslandEvents.openCall()
                xcall.di.collapse()
            }
        }
        BigButton {
            visible: IslandEvents.callLeaveShortcut !== ""
            icon: "call_end"
            label: Translation.tr("Leave")
            danger: true
            onTap: {
                IslandEvents.leaveCall()
                xcall.di.collapse()
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: IslandEvents.callLeaveShortcut === ""
        text: Translation.tr("To leave from here, set a Discord keybind for “Disconnect” and put it in callLeaveShortcut")
        wrapMode: Text.WordWrap
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colOnLayer0
        opacity: 0.45
    }

    component BigButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        property bool active: false
        property bool danger: false
        signal tap()
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 18
        color: button.active || button.danger ? Appearance.colors.colError
            : buttonMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer1
        scale: buttonMouse.pressed ? 0.95 : 1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }
        Behavior on scale {
            NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: button.icon
                iconSize: 22
                fill: 1
                color: button.active || button.danger ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: button.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: button.active || button.danger ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.tap()
        }
    }
}
