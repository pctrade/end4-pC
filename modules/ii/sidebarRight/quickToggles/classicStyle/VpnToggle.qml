import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarRight.quickToggles
import qs
import QtQuick
import Quickshell
import Quickshell.Io

QuickToggleButton {
    toggled: Vpn.isConnected
    buttonIcon: Vpn.materialSymbol
    onClicked: Vpn.toggleVpn()
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.network}`])
        GlobalStates.sidebarRightOpen = false
    }
    StyledToolTip {
        text: Vpn.isConnected
            ? Translation.tr("%1 | Right-click to configure").arg(Vpn.activeVpnName)
            : Translation.tr("VPN | Right-click to configure")
    }
}
