import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    Layout.fillHeight: true
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : Math.min(rowLayout.implicitWidth + 8, 280)
    implicitHeight: vertical ? mediaCircProg.implicitHeight + 6  : Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton)      activePlayer.togglePlaying()
            else if (event.button === Qt.BackButton)   activePlayer.previous()
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) activePlayer.next()
            else if (event.button === Qt.LeftButton)   GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    // Vertical
    ClippedFilledCircularProgress {
        id: mediaCircProg
        visible: root.vertical
        anchors.centerIn: parent
        implicitSize: 20
        lineWidth: Appearance.rounding.unsharpen
        value: activePlayer?.position / activePlayer?.length
        colPrimary: Appearance.colors.colOnSecondaryContainer
        enableAnimation: false
        Item {
            anchors.centerIn: parent
            width: 20; height: 20
            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    // Horizontal
    RowLayout {
        id: rowLayout
        visible: !root.vertical
        spacing: 4
        anchors.fill: parent

        ClippedFilledCircularProgress {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 3
            implicitSize: 20
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20; height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        StyledText {
            visible: Config.options.bar.verbose
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.rightMargin: 0
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            text: `${root.cleanedTitle}${root.activePlayer?.trackArtist ? ' • ' + root.activePlayer.trackArtist : ''}`
        }
    }
}