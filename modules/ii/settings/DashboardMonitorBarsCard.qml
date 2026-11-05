import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    readonly property string selectedScreen: GlobalStates.dashboardBarScreen
    readonly property bool isGlobal: selectedScreen === ""
    readonly property bool customized: !isGlobal && Config.hasBarOverride(selectedScreen)
    readonly property bool barEnabled: isGlobal || !customized
        ? true
        : Config.barForScreen(selectedScreen).enabled !== false
    readonly property var targets: [{ name: "", label: Translation.tr("All displays"), icon: "select_all" }]
        .concat(Quickshell.screens.map(screen => ({ name: screen.name, label: screen.name, icon: "monitor" })))

    tint: Appearance.colors.colSecondaryContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Cookie6Sided
                text: "tv_displays"
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colSecondary
                colSymbol: Appearance.colors.colOnSecondary
            }

            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Translation.tr("Bars per monitor")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSecondaryContainer
                }
                StyledText {
                    text: root.isGlobal
                        ? Translation.tr("Editing the defaults used by every display")
                        : root.customized
                            ? Translation.tr("Editing a separate bar for %1").arg(root.selectedScreen)
                            : Translation.tr("%1 currently inherits the defaults").arg(root.selectedScreen)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                    opacity: 0.75
                }
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: !root.isGlobal && root.customized
                implicitWidth: resetRow.implicitWidth + 24
                implicitHeight: 38
                buttonRadius: 19
                colBackground: Qt.rgba(1, 1, 1, 0.12)
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.22)
                colRipple: Qt.rgba(1, 1, 1, 0.3)
                downAction: () => Qt.callLater(() => Config.resetBarForScreen(root.selectedScreen))

                contentItem: RowLayout {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { text: "restart_alt"; iconSize: 18; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: Translation.tr("Use defaults"); color: Appearance.colors.colOnSecondaryContainer }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.targets

                delegate: RippleButton {
                    id: targetButton
                    required property var modelData
                    readonly property bool selected: root.selectedScreen === modelData.name
                    implicitWidth: targetRow.implicitWidth + 28
                    implicitHeight: 42
                    buttonRadius: 21
                    colBackground: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.12)
                    colBackgroundHover: selected ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.22)
                    colRipple: Qt.rgba(1, 1, 1, 0.3)
                    downAction: () => { GlobalStates.dashboardBarScreen = modelData.name; }

                    contentItem: RowLayout {
                        id: targetRow
                        anchors.centerIn: parent
                        spacing: 7
                        MaterialSymbol {
                            text: targetButton.modelData.icon
                            iconSize: 18
                            fill: targetButton.selected ? 1 : 0
                            color: targetButton.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: targetButton.modelData.label
                            font.weight: targetButton.selected ? Font.DemiBold : Font.Normal
                            color: targetButton.selected ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.isGlobal
            spacing: 10

            RippleButton {
                visible: !root.customized
                Layout.fillWidth: true
                implicitHeight: 44
                buttonRadius: 22
                colBackground: Appearance.colors.colSecondary
                colBackgroundHover: Appearance.colors.colSecondaryHover
                colRipple: Appearance.colors.colSecondaryActive
                downAction: () => Qt.callLater(() => Config.createBarOverride(root.selectedScreen))
                contentItem: RowLayout {
                    Item { Layout.fillWidth: true }
                    MaterialSymbol { text: "add"; iconSize: 19; color: Appearance.colors.colOnSecondary }
                    StyledText { text: Translation.tr("Customize this monitor"); font.weight: Font.DemiBold; color: Appearance.colors.colOnSecondary }
                    Item { Layout.fillWidth: true }
                }
            }

            RippleButton {
                visible: root.customized
                Layout.fillWidth: true
                implicitHeight: 44
                buttonRadius: 22
                colBackground: root.barEnabled ? Appearance.colors.colSecondary : Qt.rgba(1, 1, 1, 0.12)
                colBackgroundHover: root.barEnabled ? Appearance.colors.colSecondaryHover : Qt.rgba(1, 1, 1, 0.22)
                colRipple: Qt.rgba(1, 1, 1, 0.3)
                downAction: () => Config.setBarEnabledForScreen(root.selectedScreen, !root.barEnabled)
                contentItem: RowLayout {
                    Item { Layout.fillWidth: true }
                    MaterialSymbol {
                        text: root.barEnabled ? "visibility" : "visibility_off"
                        iconSize: 19
                        color: root.barEnabled ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: root.barEnabled ? Translation.tr("Bar shown on this monitor") : Translation.tr("Bar hidden on this monitor")
                        font.weight: Font.DemiBold
                        color: root.barEnabled ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSecondaryContainer
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
