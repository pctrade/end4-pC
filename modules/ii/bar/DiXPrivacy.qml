import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: xp
    required property Item di
    spacing: 10
    implicitWidth: 320
    readonly property real wantedWidth: 320

    StyledText {
        text: Translation.tr("Privacy")
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
    }

    StyledText {
        visible: !IslandEvents.anyPrivacy
        text: Translation.tr("No app is using the microphone, camera or screen")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Repeater {
        model: [
            { icon: "mic", label: Translation.tr("Microphone"), color: IslandEvents.colorAttention, apps: IslandEvents.privacy.mic },
            { icon: "videocam", label: Translation.tr("Camera"), color: "#30D158", apps: IslandEvents.privacy.camera },
            { icon: "screen_share", label: Translation.tr("Screen sharing"), color: "#30D158", apps: IslandEvents.privacy.screen }
        ].filter(section => section.apps.length > 0)

        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: modelData.color
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: modelData.icon
                    iconSize: 18
                    fill: 1
                    color: "#111111"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    text: modelData.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.fillWidth: true
                    text: modelData.apps.join(", ")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }
    }
}
