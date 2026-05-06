import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool showPing: false
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool animeEnabled: Config.options.policies.weeb !== 0
    visible: aiChatEnabled || translatorEnabled || animeEnabled

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Connections {
        target: Ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: Booru
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            root.showPing = false;
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: Config.options.bar.cornerStyle === 3 ? fabStyle : defaultStyle
    }

    Component {
        id: defaultStyle
        RippleButton {
            property real buttonPadding: 5
            implicitWidth: Config.options.bar.cornerStyle === 2 ? 27 : distroIcon.width + buttonPadding * 2
            implicitHeight: Config.options.bar.cornerStyle === 2 ? 27 : distroIcon.height + buttonPadding * 2
            buttonRadius: Appearance.rounding.full
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive
            toggled: GlobalStates.sidebarLeftOpen
            onPressed: {
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            }
            CustomIcon {
                id: distroIcon
                anchors.centerIn: parent
                width: 19.5
                height: 19.5
                source: Config.options.bar.topLeftIcon == 'distro' ? SystemInfo.distroIcon : `${Config.options.bar.topLeftIcon}-symbolic`
                colorize: true
                color: Appearance.colors.colPrimary
                Rectangle {
                    opacity: root.showPing ? 1 : 0
                    visible: opacity > 0
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        bottomMargin: -2
                        rightMargin: -2
                    }
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colTertiary
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }

    Component {
        id: fabStyle
        Fab {
            onClicked: {
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            }

            CustomIcon {
                anchors.centerIn: parent
                width: 19.5
                height: 19.5
                source: Config.options.bar.topLeftIcon == 'distro' ? SystemInfo.distroIcon : `${Config.options.bar.topLeftIcon}-symbolic`
                colorize: true
                color: Appearance.colors.colOnPrimaryContainer

                Rectangle {
                    opacity: root.showPing ? 1 : 0
                    visible: opacity > 0
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        bottomMargin: -2
                        rightMargin: -2
                    }
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colTertiary
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}