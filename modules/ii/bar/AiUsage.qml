import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import QtQuick.Layouts

MouseArea {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    property bool vertical: false
    readonly property bool active: ClaudeUsage.activeSessions > 0

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : content.implicitWidth + 12
    implicitHeight: vertical ? content.implicitHeight + 10 : Appearance.sizes.barHeight
    hoverEnabled: !root.barConfig.tooltips.clickToShow

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: 5
        rowSpacing: 2

        CustomIcon {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            width: 15
            height: 15
            source: "claude-symbolic"
            colorize: true
            color: root.active ? root.contentColor : (root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.6) : Appearance.colors.colSubtext)
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: `${Math.round(ClaudeUsage.percentage * 100)}%`
            font.pixelSize: root.vertical ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
            color: root.active ? root.contentColor : (root.contentColorOverridden ? Qt.alpha(root.contentColor, 0.6) : Appearance.colors.colSubtext)
        }
    }

    AiUsagePopup {
        hoverTarget: root
    }
}
