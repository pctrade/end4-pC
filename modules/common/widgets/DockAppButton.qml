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

    hoverOwner: appListRoot
    // The first click focuses the most recent window.
    onHoverEntered: root.cycleIndex = appToplevel.toplevels.length - 1
    windows: appToplevel.toplevels
    onClicked: {
        if (!root.focusNextWindow())
            root.desktopEntry?.execute();
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        root.contextMenu?.open(root, appToplevel.appId);
    }

    DockTooltip {
        text: root.desktopEntry?.name || root.appToplevel.appId
        show: root.hovered && !root.isSeparator
        app: root.appToplevel
        contextMenu: root.contextMenu
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
