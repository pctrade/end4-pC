import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Item {
    id: root
    property real contentPadding: 8
    property int currentPage: 0

    Connections {
        target: GlobalStates
        function onSettingsPageChanged() {
            if (GlobalStates.settingsPage === "") return
            
            let parts = GlobalStates.settingsPage.split(":");
            let pageName = parts[0];
            let searchTerm = parts.length > 1 ? parts[1] : "";

            const idx = root.pages.findIndex(p => p.name.toLowerCase() === pageName.toLowerCase());
            
            if (idx >= 0) {
                root.currentPage = idx;
                
                if (searchTerm !== "") {
                    Qt.callLater(() => {
                        let loader = pagesRepeater.itemAt(idx);
                        if (loader && loader.item && typeof loader.item.goTo === "function") {
                            loader.item.goTo(searchTerm);
                        }
                    });
                }
            }
            GlobalStates.settingsPage = "";
        }
    }

    onCurrentPageChanged: {
        if (currentPage === 7) {
            const aboutLoader = pagesRepeater.itemAt(7);
            if (aboutLoader && aboutLoader.item) {
                aboutLoader.item.refresh();
            }
        }
    }

    property var pages: [
        { name: Translation.tr("Quick"),      icon: "instant_mix",    component: Qt.resolvedUrl("pages/QuickConfig.qml") },
        { name: Translation.tr("General"),    icon: "browse",         component: Qt.resolvedUrl("pages/GeneralConfig.qml") },
        { name: Translation.tr("Bar"),        icon: "toast",          iconRotation: 180, component: Qt.resolvedUrl("pages/BarConfig.qml") },
        { name: Translation.tr("Desktop"), icon: "texture",        component: Qt.resolvedUrl("pages/BackgroundConfig.qml") },
        { name: Translation.tr("Interface"),  icon: "bottom_app_bar", component: Qt.resolvedUrl("pages/InterfaceConfig.qml") },
        { name: Translation.tr("Services"),   icon: "settings",       component: Qt.resolvedUrl("pages/ServicesConfig.qml") },
        { name: Translation.tr("Hyprland"),   icon: "select_window_2",   component: Qt.resolvedUrl("pages/HyprlandConfig.qml") },
        { name: Translation.tr("About"),      icon: "info",           component: Qt.resolvedUrl("pages/About.qml") }
    ]

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding

            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: navRail.expanded ? 150 : fab.baseSize
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                NavigationRail {
                    id: navRail
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    spacing: 10
                    expanded: root.width > 900

                    NavigationRailExpandButton {
                        focus: GlobalStates.settingsOpen
                    }

                    FloatingActionButton {
                        id: fab
                        property bool justCopied: false
                        iconText: justCopied ? "check" : "edit"
                        buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                        expanded: navRail.expanded
                        downAction: () => {
                            Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                        }
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            fab.justCopied = true;
                            revertTextTimer.restart()
                        }
                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: fab.justCopied = false
                        }
                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    NavigationRailTabArray {
                        currentIndex: root.currentPage
                        expanded: navRail.expanded
                        Repeater {
                            model: root.pages
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: root.currentPage === index
                                onPressed: root.currentPage = index
                                expanded: navRail.expanded
                                buttonIcon: modelData.icon
                                buttonIconRotation: modelData.iconRotation || 0
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }

                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut 

                Item {
                    anchors.fill: parent
                    Repeater {
                        id: pagesRepeater
                        model: root.pages
                        Loader {
                            id: pageLoader 
                            required property var modelData
                            required property var index
                            source: modelData.component
                            active: Config.ready
                            anchors.fill: parent

                            onLoaded: {
                                if (root.currentPage === index) {
                                    GlobalStates.currentPageInstance = item;
                                }
                            }
                            onIsActiveChanged: {
                                if (isActive && item) {
                                    GlobalStates.currentPageInstance = item;
                                }
                            }

                            property bool isActive: root.currentPage === index
                            opacity: isActive ? 1 : 0
                            enabled: isActive
                            visible: isActive
                            anchors.topMargin: isActive ? 0 : 12

                            Behavior on opacity {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Behavior on anchors.topMargin {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
