import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: diOsdRoot
    required property Item di
    anchors {
        fill: parent
        leftMargin: root.isMaterial ? 0 : 4
        rightMargin: 10
    }
    spacing: 6

    readonly property var focusedScreen: WM.compositor === "hyprland"
        ? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        : Quickshell.screens.find(s => s.name === WM.focusedMonitor?.name)
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)
    readonly property real indicatorValue: {
        let value = 0
        switch (GlobalStates.osdIndicatorType) {
            case "brightness": value = brightnessMonitor?.brightness ?? 0.5; break
            case "gamma": value = (Hyprsunset.gamma ?? 50) / 100; break
            default: value = Audio.sink?.audio?.volume ?? 0; break
        }
        return Math.max(0, Math.min(1, value))
    }

    MaterialShapeWrappedMaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        wrappedShape: MaterialShape.Shape.Cookie12Sided
        color: Appearance.colors.colPrimary
        colSymbol: Appearance.colors.colOnPrimary
        text: root.iconForProviderId("osd")
        iconSize: root.isMaterial ? 20 : 16
        fill: 1
        padding: 4
    }

    StyledProgressBar {
        Layout.fillWidth: true
        Layout.minimumWidth: 30
        Layout.alignment: Qt.AlignVCenter
        value: diOsdRoot.indicatorValue
        valueBarHeight: 4
        valueBarGap: 3
        highlightColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colSecondaryContainer
    }

    StyledText {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 24
        horizontalAlignment: Text.AlignRight
        text: {
            switch (GlobalStates.osdIndicatorType) {
                case "brightness": return `${Math.round((brightnessMonitor?.brightness ?? 0.5) * 100)}`
                case "gamma":      return `${Math.round((Hyprsunset.gamma ?? 50))}`
                default:           return `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}`
            }
        }
        font.pixelSize: root.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}