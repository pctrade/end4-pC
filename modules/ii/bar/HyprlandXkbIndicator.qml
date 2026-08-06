import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Loader {
    id: root
    property bool vertical: false
    property color color: Appearance.colors.colOnSurfaceVariant

    sourceComponent: Item {
        implicitWidth: root.vertical ? null : rowLayout.implicitWidth + 8
        implicitHeight: root.vertical ? rowLayout.implicitHeight + 6 : null

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5

            StyledText {
                id: layoutCodeText
                horizontalAlignment: Text.AlignHCenter
                text: WM.compositor === "niri" ? NiriXkb.currentLayoutCode : HyprlandXkb.currentLayoutCode
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
                animateChange: true
            }
        }
    }
}