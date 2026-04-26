pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell

MouseArea {
    id: root
    property bool vertical: Config.options.bar.vertical
    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : rowLayout.implicitWidth + 12
    implicitHeight: vertical ? colLayout.implicitHeight + 8 : Appearance.sizes.barHeight
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
    }

    // Horizontal
    RowLayout {
        id: rowLayout
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "package"
            iconSize: Appearance.font.pixelSize.normal
            color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                : Updates.updateAdvised ? Appearance.colors.colTertiary
                : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Updates.checking ? "..." : Updates.count > 0 ? `${Updates.count}` : "✓"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Vertical
    ColumnLayout {
        id: colLayout
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "package"
            iconSize: Appearance.font.pixelSize.normal
            color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                : Updates.updateAdvised ? Appearance.colors.colTertiary
                : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Updates.checking ? "..." : Updates.count > 0 ? `${Updates.count}` : "✓"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}