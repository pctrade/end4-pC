import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitWidth: rowLayout.implicitWidth + 12
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "package"
            iconSize: Appearance.font.pixelSize.normal
            color: Updates.updateStronglyAdvised ? Appearance.m3colors.m3error
                : Updates.updateAdvised ? Appearance.colors.colTertiary
                : Appearance.colors.colOnLayer1
        }

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Updates.checking ? "..." : Updates.count > 0 ? `${Updates.count}` : "✓"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached([
                "kitty", "--hold",
                "fish", "-i", "-l", "-c",
                "yay -Syu --combinedupgrade=false"
            ])
        }
    }
}