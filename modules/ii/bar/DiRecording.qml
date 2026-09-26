import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: rec
    required property Item di
    anchors {
        fill: parent
        leftMargin: 6
        rightMargin: 12
    }
    spacing: 6

    Item {
        implicitWidth: 22
        implicitHeight: 22

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 20
            radius: 10
            color: "transparent"
            border.width: 1.5
            border.color: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
        }

        Rectangle {
            id: recDot
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: stopHover.containsMouse ? 2 : 5
            color: Appearance.colors.colError

            Behavior on radius {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
            }

        }

        MouseArea {
            id: stopHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached([Directories.recordScriptPath])
        }
    }

    StyledText {
        id: recLabel
        visible: rec.di.hoverRevealed
        onVisibleChanged: if (visible) recIn.restart()
        text: Translation.tr("Recording screen")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0

        NumberAnimation {
            id: recIn
            target: recLabel
            property: "opacity"
            from: 0
            to: 0.75
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    Item { Layout.fillWidth: true }

    StyledText {
        text: rec.di.formatRecordingTime(rec.di.recordingElapsedSeconds)
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}
