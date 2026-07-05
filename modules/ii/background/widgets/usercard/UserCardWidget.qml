import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "userCard"
    implicitWidth: outerRect.implicitWidth
    implicitHeight: outerRect.implicitHeight

    property int cardWidth: 260
    property int blurMargin: 18   
    property int avatarSize: 64
    property string hostname: Quickshell.env("HOSTNAME") ?? "host"
    property var currentQuip: weatherQuip()
    

    function weatherQuip() {
        const desc = (Weather.data?.description ?? "").toLowerCase();
        const temp = Weather.data?.temp ?? "--";
        if (desc.includes("rain"))
            return { text: `${temp} • raining, grab a coffee`, icon: "coffee" };
        if (desc.includes("clear"))
            return { text: `${temp} • clear, good day to touch grass`, icon: "eco" };
        if (desc.includes("cloud"))
            return { text: `${temp} • a bit cloudy today`, icon: "cloud" };
        if (desc.includes("snow"))
            return { text: `${temp} • snowing`, icon: "ac_unit" };
        return { text: `${temp} • ${Weather.data?.description ?? ""}`, icon: "thermostat" };
    }

    Process {
        id: hostnameProcess
        command: ["cat", "/etc/hostname"]
        running: true
        stdout: StdioCollector {
            id: hostnameOutput
        }
        onExited: {
            hostname = hostnameOutput.text.trim()
        }
    }

    StyledDropShadow {
        target: outerRect
    }

    Item {
        id: outerRect
        implicitWidth: root.cardWidth + root.blurMargin * 2
        implicitHeight: contentBox.implicitHeight + root.blurMargin * 2 + 60

        Image {
            id: bgImage
            anchors.fill: parent
            source: "file://" + Config.options.background.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: false
        }

        FastBlur {
            id: blurredBg
            anchors.fill: bgImage
            source: bgImage
            radius: 48
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: outerRect.width
                    height: outerRect.height
                    radius: Appearance.rounding.large
                }
            }
        }

        Rectangle {
            anchors.fill: blurredBg
            radius: Appearance.rounding.large
            color: Appearance.colors.colScrim
            opacity: 0.1
        }

        Rectangle {
            id: contentBox
            x: root.blurMargin
            y: root.avatarSize / 2 + root.blurMargin + 30
            width: root.cardWidth
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.large
            implicitHeight: contentColumn.implicitHeight + 30

            ColumnLayout {
                id: contentColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                Layout.topMargin: root.avatarSize / 2 + 4
                spacing: 10

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.avatarSize / 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        iconSize: Appearance.font.pixelSize.normal
                        text: root.currentQuip.icon
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.85
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.85
                        text: root.currentQuip.text
                    }
                } 

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colOnPrimaryContainer

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.normal
                                text: "lock"
                                color: Appearance.colors.colPrimaryContainer
                            }
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimaryContainer
                                text: "Lock"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.screenLocked = true
                        }
                    }

                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colOnPrimaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "settings"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.settingsOpen = true
                        }
                    }

                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colOnPrimaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "power_settings_new"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.sessionOpen = true
                        }
                    }
                }
            }
        }

        Rectangle {
            id: avatarRect
            x: root.blurMargin + 16
            y: contentBox.y - root.avatarSize / 2
            width: root.avatarSize + 10
            height: root.avatarSize + 10
            radius: width / 2
            color: Appearance.colors.colPrimaryContainer
            border.width: 3
            border.color: Appearance.colors.colLayer1
            z: 2

            Image {
                id: avatarImage
                anchors.fill: parent
                anchors.margins: 3
                source: Config.options.profile.avatarPath !== ""
                    ? "file://" + Config.options.profile.avatarPicture
                    : "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face"
                sourceSize.width: avatarImage.width * 2
                sourceSize.height: avatarImage.height * 2
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: avatarRect.width - 6
                        height: avatarRect.height - 6
                        radius: (avatarRect.width - 6) / 2
                    }
                }
                onStatusChanged: {
                    if (status === Image.Error)
                        visible = false
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "account_circle"
                iconSize: 32
                color: Appearance.colors.colOnPrimaryContainer
                visible: avatarImage.status === Image.Error
            }
        }

        ColumnLayout {
            x: avatarRect.x + avatarRect.width + 13
            y: avatarRect.y + (avatarRect.height - implicitHeight) / 2 + 20
            spacing: 0
            z: 2
            

            StyledText {
                text: (Quickshell.env("USER") ?? "user") + "@" + hostname
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: "Up • " + DateTime.uptime
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.6
            }
        }
    }
}