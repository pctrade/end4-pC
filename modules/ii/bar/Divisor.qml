import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property real btnSize: 40
    property real btnSpacing: 2
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property string style: Config.options.bar.divider.style // "rect" - "dot" - "space"
    property int dividerSpacing: Config.options.bar.divider.spacing
    property int dividerSize: Config.options.bar.divider.size ?? 2

    implicitWidth:  vertical ? btnSize : root.dividerSpacing
    implicitHeight: vertical ? root.dividerSpacing : btnSize

    Rectangle {
        visible: root.style === "rect"
        anchors.centerIn: parent
        width:  vertical ? Math.round(btnSize * 0.6) : root.dividerSize
        height: vertical ? root.dividerSize : Math.round(btnSize * 0.6)
        color:  isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
    }

    StyledText {
        id: dotText
        visible: root.style === "dot"
        anchors.centerIn: parent
        text: "•"
        color: isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
        font.pixelSize: Math.round(Appearance.font.pixelSize.normal * (root.dividerSize / 2.0))
    }
}