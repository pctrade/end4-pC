import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("VPN")
    statusText: Vpn.isConnected ? Vpn.activeVpnName : (Vpn.isConnecting ? Translation.tr("Connecting...") : Translation.tr("Off"))
    tooltipText: Vpn.isConnected 
        ? Translation.tr("%1 | Right-click to configure").arg(Vpn.activeVpnName)
        : Translation.tr("VPN | Right-click to configure")
    icon: Vpn.isConnected ? "vpn_key" : "vpn_key_off"

    toggled: Vpn.isConnected
    mainAction: () => Vpn.toggleVpn()

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
