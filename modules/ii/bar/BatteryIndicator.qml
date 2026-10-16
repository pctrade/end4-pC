import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

MouseArea {
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : glyph.implicitWidth + 8
    implicitHeight: vertical ? glyph.implicitHeight + 8 : Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    BatteryGlyph {
        id: glyph
        anchors.centerIn: parent
        style: Config.options.bar.battery.style
        percentage: root.percentage
        isCharging: root.isCharging
        isLow: root.isLow
        showPercentage: Config.options.bar.battery.showPercentage
        showCharging: Config.options.bar.battery.showCharging
        vertical: root.vertical
        contentColor: root.contentColor
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
