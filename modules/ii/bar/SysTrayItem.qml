pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MouseArea {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    required property SystemTrayItem item
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()
    signal styleEditorRequested()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: 20
    implicitHeight: 20
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        }
        event.accepted = true;
    }
    onClicked: (event) => {
        if (event.button !== Qt.RightButton || !item.hasMenu) return;
        if (menu.active && menu.item && typeof menu.item.close === "function")
            menu.item.close();
        else
            menu.open();
    }
    onPressAndHold: (event) => {
        if (event.button === Qt.RightButton) root.styleEditorRequested();
    }
    onEntered: {
        tooltip.text = TrayService.getTooltipForItem(root.item);
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            trayItemId: root.item.id
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: root.barConfig.vertical
                    ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
                    : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
                edges: root.barConfig.vertical
                    ? (root.barConfig.bottom ? Edges.Left : Edges.Right)
                    : (root.barConfig.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        visible: !Config.options.tray.monochromeIcons
        source: root.item.icon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: Config.options.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!root.barConfig.bottom && !root.barConfig.vertical) ? Edges.Bottom : Edges.Top
    }

}
