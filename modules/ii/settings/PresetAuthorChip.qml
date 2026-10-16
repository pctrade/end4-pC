import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property string author: ""
    property color textColor: "white"
    property int avatarSize: 22

    visible: author !== ""
    spacing: 7

    Rectangle {
        implicitWidth: root.avatarSize
        implicitHeight: root.avatarSize
        radius: width / 2
        color: Appearance.colors.colPrimaryContainer

        Image {
            id: avatarImage
            anchors.fill: parent
            source: root.author !== "" ? `https://github.com/${root.author}.png?size=64` : ""
            sourceSize.width: root.avatarSize * 2
            sourceSize.height: root.avatarSize * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: avatarImage.width
                    height: avatarImage.height
                    radius: width / 2
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "person"
            iconSize: root.avatarSize * 0.7
            color: Appearance.colors.colOnPrimaryContainer
            visible: avatarImage.status !== Image.Ready
        }
    }

    StyledText {
        text: `@${root.author}`
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Medium
        color: root.textColor
        opacity: 0.9
        elide: Text.ElideRight
    }
}
