import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    name: Translation.tr("VPN")
    icon: Vpn.connected ? "vpn_lock" : "vpn_key"
    statusText: Vpn.busy ? Translation.tr("Working…") : (Vpn.selectedProfile?.name ?? Translation.tr("Set up"))
    tooltipText: Vpn.available
        ? Translation.tr("%1 | Right-click to manage profiles").arg(Vpn.selectedProfile?.name ?? "")
        : Translation.tr("No VPN profiles yet | Click to import one")

    toggled: Vpn.connected
    mainAction: () => Vpn.toggle()
    hasMenu: true
}
