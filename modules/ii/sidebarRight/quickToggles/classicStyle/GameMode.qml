import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    buttonIcon: "gamepad"
    toggled: GameMode.active

    onClicked: {
        GameMode.toggle()
    }

    StyledToolTip {
        text: Translation.tr("Game mode")
    }
}