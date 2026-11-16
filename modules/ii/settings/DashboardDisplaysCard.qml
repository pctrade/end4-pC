import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.settings.pages

// Hosts the shared Displays section (monitor canvas + per-monitor rows) inside
// a dashboard card. Scrolls internally only when the content is taller.
DashboardCard {
    id: root

    property string title: ""
    property string icon: "monitor"
    property var tileShape: MaterialShape.Shape.ClamShell

    tint: Appearance.colors.colLayer1

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 6
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 0

            DisplaysSection {
                Layout.fillWidth: true
            }
        }
    }
}
