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
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : (isMaterial ? (rowLoader.item?.implicitWidth ?? 0) : (rowLoader.item?.implicitWidth ?? 0) + 12)
    implicitHeight: vertical ? (colLoader.item?.implicitHeight ?? 0) + 8 : Appearance.sizes.barHeight

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
            leftPadding: 5
            rightPadding: 3
            font.pixelSize: Appearance.font.pixelSize.small
            color: isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            text: Updates.count
        }
    }

    Component {
        id: spinnerComp
        MaterialSymbol {
            leftPadding: 5
            rightPadding: 3
            text: "progress_activity"
            iconSize: Appearance.font.pixelSize.normal
            color: isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            RotationAnimation on rotation {
                from: 0; to: 360
                duration: 1000
                loops: Animation.Infinite
                running: true
            }
        }
    }

    // Horizontal
    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? rowMaterial : rowDefault

        Component {
            id: rowDefault
            RowLayout {
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
        }

        Component {
            id: rowMaterial
            Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.full
                implicitHeight: 30
                implicitWidth: pillRow.implicitWidth + 8

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 3

                    Rectangle {
                        width: 24
                        height: 24
                        radius: Appearance.rounding.full
                        color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                            : Updates.updateAdvised ? Appearance.colors.colTertiary
                            : Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "package"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        sourceComponent: Updates.checking ? spinnerComp : textComp
                    }
                }
            }
        }
    }

    // Vertical
    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? colMaterial : colDefault

        Component {
            id: colDefault
            ColumnLayout {
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

        Component {
            id: colMaterial
            Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.full
                implicitWidth: 30
                implicitHeight: pillCol.implicitHeight + 8

                ColumnLayout {
                    id: pillCol
                    anchors.centerIn: parent
                    spacing: 3

                    Rectangle {
                        width: 24
                        height: 24
                        radius: Appearance.rounding.full
                        color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                            : Updates.updateAdvised ? Appearance.colors.colTertiary
                            : Appearance.colors.colPrimary
                        Layout.alignment: Qt.AlignHCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "package"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    Loader {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 3
                        sourceComponent: Updates.checking ? spinnerComp : textComp
                    }
                }
            }
        }
    }
}