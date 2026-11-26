pragma Singleton

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property var kinds: [UPowerDeviceType.Mouse, UPowerDeviceType.Keyboard, UPowerDeviceType.Headset,
        UPowerDeviceType.Headphones, UPowerDeviceType.GamingInput, UPowerDeviceType.Touchpad,
        UPowerDeviceType.Tablet, UPowerDeviceType.Phone]

    readonly property var devices: UPower.devices.values.filter(dev => dev.isPresent && root.kinds.includes(dev.type))

    function isDraining(dev) {
        return dev.state !== UPowerDeviceState.Charging && dev.state !== UPowerDeviceState.FullyCharged
    }

    function isLow(dev) {
        return dev.percentage > 0 && dev.percentage <= Config.options.battery.peripheralLow / 100 && root.isDraining(dev)
    }

    function isCritical(dev) {
        return dev.percentage > 0 && dev.percentage <= Config.options.battery.peripheralCritical / 100 && root.isDraining(dev)
    }

    readonly property var lowDevices: root.devices.filter(dev => root.isLow(dev))

    Instantiator {
        model: ScriptModel {
            values: root.devices
            objectProp: "nativePath"
        }
        delegate: QtObject {
            id: tracker
            required property var modelData
            readonly property string name: modelData.model || Translation.tr("Device")
            readonly property bool low: root.isLow(modelData)
            readonly property bool critical: root.isCritical(modelData)

            onLowChanged: {
                if (!low || critical || !Config.options.battery.peripheralNotify) return;
                Quickshell.execDetached([
                    "notify-send",
                    Translation.tr("%1 battery low").arg(tracker.name),
                    Translation.tr("%1% remaining").arg(Math.round(modelData.percentage * 100)),
                    "-a", "Shell",
                    "--hint=int:transient:1",
                ]);
            }

            onCriticalChanged: {
                if (!critical || !Config.options.battery.peripheralNotify) return;
                Quickshell.execDetached([
                    "notify-send",
                    Translation.tr("%1 battery critically low").arg(tracker.name),
                    Translation.tr("%1% remaining, please charge it").arg(Math.round(modelData.percentage * 100)),
                    "-u", "critical",
                    "-a", "Shell",
                    "--hint=int:transient:1",
                ]);
            }
        }
    }
}
