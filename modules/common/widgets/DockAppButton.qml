import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property var contextMenu
    property int lastFocused: -1
    property real iconSize: DockStyle.iconSize
    property bool appIsActive: appToplevel.toplevels.find(t => (t.activated == true)) !== undefined

    readonly property bool isSeparator: appToplevel.appId === "SEPARATOR"

    magnifiable: !root.isSeparator
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel.appId)
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : naturalWidth

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(appToplevel.appId);
        }
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin: DockStyle.separatorInset
            bottomMargin: DockStyle.separatorInset
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel.toplevels.length > 0
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    onClicked: {
        if (appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        root.contextMenu?.open(root, appToplevel.appId);
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: DockAppIcon {
            anchors.centerIn: parent
            iconSource: SystemAppearance.iconPath(AppSearch.guessIcon(appToplevel.appId), "image-missing")
            iconSize: root.iconSize
            windowCount: appToplevel.toplevels.length
            active: root.appIsActive
        }
    }
}
