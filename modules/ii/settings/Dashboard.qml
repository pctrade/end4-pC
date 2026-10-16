import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    readonly property bool active: GlobalStates.settingsOpen && Config.options.settings.style === "dashboard"

    Loader {
        active: root.active

        sourceComponent: FloatingWindow {
            id: window
            title: "illogical-impulse Settings"
            color: Appearance.colors.colUiBackground

            implicitWidth: 1100
            implicitHeight: 680
            minimumSize: Qt.size(900, 600)

            property bool settled: false

            visible: true
            onVisibleChanged: {
                if (!visible) GlobalStates.settingsOpen = false;
            }
            onWidthChanged: settleTimer.restart()
            onHeightChanged: settleTimer.restart()

            Timer {
                id: settleTimer
                interval: 70
                running: true
                onTriggered: window.settled = true
            }

            Loader {
                anchors.fill: parent
                active: window.settled

                sourceComponent: DashboardContent {}
            }
        }
    }
}
