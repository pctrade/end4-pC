import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: xr
    required property Item di
    spacing: 14
    implicitWidth: 280
    readonly property real wantedWidth: 280

    Rectangle {
        implicitWidth: 14
        implicitHeight: 14
        radius: 7
        color: Appearance.colors.colError

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -2
        StyledText {
            text: Translation.tr("Recording screen")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }
        StyledText {
            text: xr.di.formatRecordingTime(xr.di.recordingElapsedSeconds)
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
        }
    }

    Rectangle {
        implicitWidth: 44
        implicitHeight: 44
        radius: stopMouse.containsMouse ? 12 : 22
        color: Appearance.colors.colError

        Behavior on radius {
            NumberAnimation { duration: 250; easing.type: Easing.OutBack }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "stop"
            iconSize: 24
            fill: 1
            color: Appearance.colors.colOnError
        }

        MouseArea {
            id: stopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached([Directories.recordScriptPath])
                xr.di.collapse()
            }
        }
    }
}
