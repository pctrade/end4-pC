import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string desktopPath: ""
    property string lockPath: ""
    property bool synced: true
    property string target: "desktop"

    signal targetSelected(string value)
    signal syncToggled(bool value)

    tint: Appearance.colors.colLayer1

    component PreviewTile: ClippingRectangle {
        id: tile

        property string path: ""
        property string label: ""
        property string icon: ""
        property color accent: Appearance.colors.colPrimary
        property color onAccent: Appearance.colors.colOnPrimary
        property bool active: true

        signal clicked()

        radius: 22
        color: Appearance.colors.colLayer2
        border.width: active ? 4 : 0
        border.color: accent
        opacity: active ? 1 : 0.6

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }

        Image {
            anchors.fill: parent
            source: tile.path !== "" ? "file://" + tile.path : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 720
            sourceSize.height: 405
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 10
            width: chip.implicitWidth + 24
            height: 34
            radius: 17
            color: tile.accent

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            RowLayout {
                id: chip
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: tile.icon
                    iconSize: 18
                    fill: 1
                    color: tile.onAccent
                }
                StyledText {
                    text: tile.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: tile.onAccent
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        PreviewTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            path: root.desktopPath
            label: Translation.tr("Desktop")
            icon: "desktop_windows"
            active: root.synced || root.target === "desktop"
            onClicked: root.targetSelected("desktop")
        }

        PreviewTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            path: root.lockPath
            label: Translation.tr("Lock screen")
            icon: "lock"
            active: root.synced || root.target === "lock"
            onClicked: root.targetSelected("lock")
            accent: root.synced ? Appearance.colors.colPrimary : Appearance.colors.colTertiary
            onAccent: root.synced ? Appearance.colors.colOnPrimary : Appearance.colors.colOnTertiary
        }
    }

    RippleButton {
        anchors.centerIn: parent
        implicitWidth: 48
        implicitHeight: 48
        buttonRadius: 24
        colBackground: root.synced ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        colBackgroundHover: root.synced ? Appearance.colors.colPrimary : Appearance.colors.colLayer2Hover
        colRipple: Qt.rgba(1, 1, 1, 0.3)
        downAction: () => Qt.callLater(() => root.syncToggled(!root.synced))

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: root.synced ? "link" : "link_off"
            iconSize: 24
            fill: root.synced ? 1 : 0
            color: root.synced ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        }
    }
}
