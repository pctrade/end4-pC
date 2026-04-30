pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : rowLayout.implicitWidth + 12
    implicitHeight: vertical ? colLayout.implicitHeight + 8 : Appearance.sizes.barHeight
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
            updateProc.running = true
        }
    }

    onPressed: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Updates.refresh()
            Quickshell.execDetached(["notify-send",
                Translation.tr("Updates"),
                Translation.tr("Checking for updates..."),
                "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    Process {
        id: updateProc
        command: [
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ]
        onExited: (exitCode, exitStatus) => {
            Updates.refresh()
            notifyTimer.restart()
        }
    }

    Timer {
        id: notifyTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (Updates.count === 0) {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Updates"),
                    Translation.tr("System up to date"),
                    "-a", "Shell"
                ])
            } else {
                Quickshell.execDetached(["notify-send",
                    Translation.tr("Updates"),
                    Translation.tr("Update cancelled — %1 updates still pending").arg(Updates.count),
                    "-a", "Shell", "-u", "normal"
                ])
            }
        }
    }

    Component {
        id: textComp
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Updates.count
        }
    }

    Component {
        id: spinnerComp
        MaterialSymbol {
            text: "progress_activity"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: true
            }
        }
    }

    // Horizontal
    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "package"
            iconSize: Appearance.font.pixelSize.normal
            color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                 : Updates.updateAdvised ? Appearance.colors.colTertiary
                 : Appearance.colors.colOnLayer1
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: Updates.checking ? spinnerComp : textComp
        }
    }

    // Vertical
    ColumnLayout {
        id: colLayout
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "package"
            iconSize: Appearance.font.pixelSize.normal
            color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                 : Updates.updateAdvised ? Appearance.colors.colTertiary
                 : Appearance.colors.colOnLayer1
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter
            sourceComponent: Updates.checking ? spinnerComp : textComp
        }
    }
}