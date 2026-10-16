import qs.modules.common
import qs.modules.common.widgets
import qs.services

/*
 * Play and pause the live wallpaper. Only shows up when one is running, so the
 * panel does not carry a dead button on a still wallpaper.
 */
QuickToggleButton {
    id: root
    visible: LiveWallpaper.available
    buttonIcon: LiveWallpaper.paused ? "play_arrow" : "pause"
    toggled: !LiveWallpaper.paused

    onClicked: LiveWallpaper.toggle()

    StyledToolTip {
        text: LiveWallpaper.paused
            ? Translation.tr("Live wallpaper paused")
            : Translation.tr("Live wallpaper playing")
    }
}
