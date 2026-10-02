pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root

    required property Item anchorItem
    signal dismissed()

    readonly property bool vertical: Config.options.bar.vertical
    readonly property bool farEdge: Config.options.bar.bottom
    readonly property real shadowMargin: Appearance.sizes.elevationMargin
    readonly property real barThickness: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    readonly property point buttonCenter: anchorItem.QsWindow.mapFromItem(anchorItem, anchorItem.width / 2, anchorItem.height / 2)
    readonly property real edgeOffset: barThickness + (Config.options.bar.cornerStyle === 3 ? 5 : 0) + 6
    readonly property real contentPadding: 12
    readonly property real frameWidth: contentPadding * 2
    readonly property real frameHeight: contentPadding * 2 + header.implicitHeight + contentLayout.spacing
    readonly property real maxPopupWidth: Math.min(720, screen.width * 0.8,
        screen.width - shadowMargin * 2 - (vertical ? edgeOffset : 0))
    readonly property real maxPopupHeight: Math.min(720, screen.height * 0.8,
        screen.height - shadowMargin * 2 - (vertical ? 0 : edgeOffset))
    readonly property real phoneAspectRatio: viewLoader.item?.videoAspectRatio || 9 / 19.5
    readonly property real videoHeight: Math.min(Math.max(1, maxPopupHeight - frameHeight),
        Math.max(1, maxPopupWidth - frameWidth) / phoneAspectRatio)
    readonly property real popupWidth: Math.floor(videoHeight * phoneAspectRatio) + frameWidth
    readonly property real popupHeight: Math.floor(videoHeight) + frameHeight

    screen: anchorItem.QsWindow.window?.screen
    anchors.top: true
    anchors.left: true
    implicitWidth: popupWidth + shadowMargin * 2
    implicitHeight: popupHeight + shadowMargin * 2
    margins.left: Math.max(0, Math.min(screen.width - width,
        vertical ? (farEdge ? screen.width - edgeOffset - popupWidth - shadowMargin : edgeOffset - shadowMargin)
                 : buttonCenter.x - width / 2))
    margins.top: Math.max(0, Math.min(screen.height - height,
        vertical ? buttonCenter.y - height / 2
                 : (farEdge ? screen.height - edgeOffset - popupHeight - shadowMargin : edgeOffset - shadowMargin)))
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    mask: Region { item: background }
    WlrLayershell.namespace: "quickshell:scrcpy"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Component.onCompleted: GlobalFocusGrab.addDismissable(root)
    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.dismissed() }
    }

    StyledRectangularShadow { target: background }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: root.shadowMargin
        radius: Appearance.rounding.normal + 4
        color: Appearance.colors.colLayer1Base
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: 8

            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "smartphone"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "scrcpy"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    Accessible.name: Translation.tr("Close scrcpy")
                    onClicked: root.dismissed()
                    contentItem: MaterialSymbol {
                        text: "close"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#000000"
                radius: Appearance.rounding.small
                clip: true

                // The native window must exist before WaylandOutput is created.
                Loader {
                    id: viewLoader
                    anchors.fill: parent
                    active: root.contentItem.Window.window !== null
                    source: "ScrcpyView.qml"
                    onLoaded: item.dismissed.connect(root.dismissed)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 12
                    visible: !viewLoader.item?.connected

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: viewLoader.item?.errorMessage ? "phonelink_erase" : "phonelink"
                        iconSize: 36
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: viewLoader.status === Loader.Error
                            ? Translation.tr("Could not load the phone view. Qt Wayland Compositor is required.")
                            : viewLoader.item?.errorMessage || Translation.tr("Connecting to your phone…")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: "#ffffff"
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    RippleButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !!viewLoader.item?.errorMessage
                        enabled: !viewLoader.item?.running
                        implicitWidth: 100
                        implicitHeight: 34
                        buttonText: Translation.tr("Retry")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        contentItem: StyledText {
                            text: Translation.tr("Retry")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Appearance.colors.colOnPrimary
                        }
                        onClicked: viewLoader.item.retry()
                    }
                }
            }
        }

        Keys.onEscapePressed: root.dismissed()
    }
}
