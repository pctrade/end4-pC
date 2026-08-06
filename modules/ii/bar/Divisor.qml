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

    width:  vertical ? btnSize : (root.style === "space" ? root.dividerSpacing : (1 + btnSpacing * 3))
    height: vertical ? (root.style === "space" ? root.dividerSpacing : (1 + btnSpacing * 3)) : btnSize

    Rectangle {
        visible: root.style === "rect"
        anchors.centerIn: parent
        width:  vertical ? Math.round(btnSize * 0.6) : 1
        height: vertical ? 1 : Math.round(btnSize * 0.6)
        color:  isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
    }

    StyledText {
        visible: root.style === "dot"
        anchors.centerIn: parent
        text: "•"
        color: isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
        font.pixelSize: Appearance.font.pixelSize.normal
    }
}