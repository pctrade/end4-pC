import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: shot
    required property Item di
    anchors.fill: parent

    readonly property var payload: IslandEvents.screenshot.payload ?? ({})

    Rectangle {
        id: thumbFrame

        DiEntrance { target: thumbFrame }
        x: shot.di.isMaterial ? 4 : 6
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 24
        radius: 6
        color: Appearance.colors.colLayer2
        clip: true

        Image {
            anchors.fill: parent
            source: shot.payload.path ? `file://${shot.payload.path}` : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 160
            asynchronous: true
            cache: false
        }

    }

    ColumnLayout {
        anchors {
            left: thumbFrame.right
            leftMargin: 8
            right: parent.right
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Screenshot saved")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: shot.payload.name ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideMiddle
        }
    }
}
