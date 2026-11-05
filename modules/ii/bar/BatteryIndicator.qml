import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

MouseArea {
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool vertical: false
    property bool borderless: root.barConfig.borderless
    property bool isMaterial: root.barConfig.cornerStyle === 3 || root.barConfig.cornerStyle === 4
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : glyph.implicitWidth + 8
    implicitHeight: vertical ? glyph.implicitHeight + 8 : Appearance.sizes.barHeight

    hoverEnabled: !root.barConfig.tooltips.clickToShow

    BatteryGlyph {
        id: glyph
        anchors.centerIn: parent
        style: root.barConfig.battery.style
        percentage: root.percentage
        isCharging: root.isCharging
        isLow: root.isLow
        showPercentage: root.barConfig.battery.showPercentage
        showCharging: root.barConfig.battery.showCharging
        vertical: root.vertical
        contentColor: root.contentColor
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
