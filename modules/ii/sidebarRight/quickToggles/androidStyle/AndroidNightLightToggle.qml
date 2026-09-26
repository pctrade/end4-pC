import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    toggleModel: NightLightToggle {}

    // Reconcile with the real hyprsunset state on load, the same way the
    // classic-style toggle does (classicStyle/NightLight.qml). Without this the
    // button just renders Hyprsunset.temperatureActive, which is only ever set
    // optimistically by enable/disableTemperature() -- so if the underlying
    // command failed, or the temperature changed outside the shell, the toggle
    // stays stuck showing the wrong state until it's manually cycled.
    Component.onCompleted: Hyprsunset.fetchState()
}

