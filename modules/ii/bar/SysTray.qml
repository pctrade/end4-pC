import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: false
    property bool invertSide: false
    property bool trayOverflowOpen: false
    property bool showSeparator: true
    property bool showOverflowMenu: true
    property var activeMenu: null
    readonly property bool isOnLeft: Config.options.bar.layouts.leftLayout.includes("sysTray")
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3

    visible: SystemTray.items.values.length > 0
    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : (isMaterial ? pill.implicitWidth - 4 : gridLayout.implicitWidth)
    implicitHeight: vertical ? gridLayout.implicitHeight + 6 : Appearance.sizes.barHeight

    property list<var> pinnedItems: TrayService.pinnedItems
    property list<var> unpinnedItems: TrayService.unpinnedItems
    onUnpinnedItemsChanged: {
        if (unpinnedItems.length == 0) root.closeOverflowMenu()
    }

    function grabFocus() { focusGrab.active = true }
    function setExtraWindowAndGrabFocus(window) {
        if (root.activeMenu && root.activeMenu !== window) {
            if (typeof root.activeMenu.close === "function")
                root.activeMenu.close()
            root.activeMenu = null
        }
        root.activeMenu = window
        root.grabFocus()
    }
    function releaseFocus() { focusGrab.active = false }
    function closeOverflowMenu() { focusGrab.active = false }

    onTrayOverflowOpenChanged: {
        if (root.trayOverflowOpen) root.grabFocus()
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [trayOverflowLayout.QsWindow?.window, root.activeMenu]
        onCleared: {
            root.trayOverflowOpen = false
            if (root.activeMenu) {
                root.activeMenu.close()
                root.activeMenu = null
            }
        }
    }

    Rectangle {
        id: pill
        visible: false
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full
        implicitWidth: root.vertical ? 32 : gridLayout.implicitWidth
        implicitHeight: root.vertical ? gridLayout.implicitHeight + 12 : 32
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.centerIn: parent
        rowSpacing: 4
        columnSpacing: -6

        RippleButton {
            id: trayOverflowButton
            visible: root.showOverflowMenu && root.unpinnedItems.length > 0
            toggled: root.trayOverflowOpen
            downAction: () => root.trayOverflowOpen = !root.trayOverflowOpen

            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            background.implicitWidth: 24
            background.implicitHeight: 24
            background.anchors.centerIn: this
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.larger
                text: Config.options.bar.bottom ? "keyboard_control_key" : "expand_more"
                horizontalAlignment: Text.AlignHCenter
                color: root.trayOverflowOpen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                rotation: (root.trayOverflowOpen ? 180 : 0) - (90 * root.vertical) + (180 * root.invertSide)
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            StyledPopup {
                id: overflowPopup
                hoverTarget: trayOverflowButton
                active: root.trayOverflowOpen && root.unpinnedItems.length > 0

                GridLayout {
                    id: trayOverflowLayout
                    anchors.centerIn: parent
                    columns: Math.ceil(Math.sqrt(root.unpinnedItems.length))
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: root.unpinnedItems
                        delegate: SysTrayItem {
                            required property SystemTrayItem modelData
                            item: modelData
                            Layout.fillHeight: !root.vertical
                            Layout.fillWidth: root.vertical
                            onMenuClosed: root.releaseFocus()
                            onMenuOpened: (qsWindow) => root.setExtraWindowAndGrabFocus(qsWindow)
                        }
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel { values: root.pinnedItems }
            delegate: SysTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.fillHeight: !root.vertical
                Layout.fillWidth: root.vertical
                Layout.leftMargin:  6
                Layout.rightMargin: 6
                onMenuClosed: root.releaseFocus()
                onMenuOpened: (qsWindow) => root.setExtraWindowAndGrabFocus(qsWindow)
            }
        }
    }
}
