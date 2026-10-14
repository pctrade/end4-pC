import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    property bool vertical: root.barConfig.vertical
    property real btnSize: 40
    property real btnSpacing: 2
    property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    property string style: root.barConfig.divider.style // "rect" - "dot" - "space"
    property int dividerSpacing: root.barConfig.divider.spacing

    width:  vertical ? btnSize : (root.style === "space" ? root.dividerSpacing : root.style === "dot" ? dotText.implicitWidth + 10 : (1 + btnSpacing * 3))
    height: vertical ? (root.style === "space" ? root.dividerSpacing : root.style === "dot" ? dotText.implicitHeight - 4 : (1 + btnSpacing * 3)) : btnSize

    Rectangle {
        visible: root.style === "rect"
        anchors.centerIn: parent
        width:  vertical ? Math.round(btnSize * 0.6) : 1
        height: vertical ? 1 : Math.round(btnSize * 0.6)
        color:  isMaterial ? Appearance.colors.colPrimary : (root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.4) : Appearance.colors.colOutlineVariant)
    }

    StyledText {
        id: dotText
        visible: root.style === "dot"
        anchors.centerIn: parent
        text: "• "
        color: isMaterial ? Appearance.colors.colPrimary : root.contentColor
        font.pixelSize: Appearance.font.pixelSize.normal
    }
}