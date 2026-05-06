pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.common.models
import qs
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    // DockMedia-like properties
    property var    artUrl:      activePlayer?.trackArtUrl ?? ""
    property string trackTitle:  activePlayer?.trackTitle  ?? ""
    property string trackArtist: activePlayer?.trackArtist ?? ""
    property bool   isPlaying:   activePlayer?.isPlaying   ?? false
    property bool   hasTrack:    trackTitle.length > 0

    property string artDownloadLocation: Directories.coverArt
    property string artFileName:         Qt.md5(artUrl)
    property string artFilePath:         `${artDownloadLocation}/${artFileName}`
    property bool   artDownloaded:       false

    property string displayedArtFilePath: {
        if (!root.artDownloaded) return ""
        if (root.artUrl.startsWith("file://")) return root.artUrl
        return Qt.resolvedUrl(artFilePath)
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDownloaded = false
            return
        }
        if (root.artUrl.startsWith("file://")) {
            root.artDownloaded = true
            return
        }
        artDownloader.targetFile  = root.artUrl
        artDownloader.artFilePath = root.artFilePath
        root.artDownloaded = false
        artDownloader.running = true
    }

    Process {
        id: artDownloader
        property string targetFile:  root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c",
            `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: { root.artDownloaded = true }
    }

    Layout.fillHeight: true
    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : (isMaterial ? materialRow.implicitWidth : Math.min(rowLayout.implicitWidth + 8, 280))
    implicitHeight: vertical ? (isMaterial ? 26 : mediaCircProg.implicitHeight + 6) : Appearance.sizes.barHeight

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

    // Vertical default
    Loader {
        id: mediaCircProg
        active: root.vertical && !root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: ClippedFilledCircularProgress {
            implicitSize: 20
            lineWidth: Appearance.rounding.unsharpen
            value: root.activePlayer?.position / root.activePlayer?.length
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false
            Item {
                anchors.centerIn: parent
                width: 20
                height: 20
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    // Vertical Material
    Rectangle {
        visible: root.vertical && root.isMaterial
        anchors.centerIn: parent
        color: Appearance.colors.colSecondaryContainer
        radius: Appearance.rounding.full
        implicitWidth: 32
        implicitHeight: 32
        
        MaterialSymbol {
            anchors.centerIn: parent
            fill: 1
            text: root.activePlayer?.isPlaying ? "pause" : "music_note"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSecondaryContainer
        }
    }

    // Horizontal default
    Loader {
        id: rowLayout
        active: !root.vertical && !root.isMaterial
        visible: active
        anchors.fill: parent
        sourceComponent: RowLayout {
            spacing: 4
            ClippedFilledCircularProgress {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 3
                implicitSize: 20
                lineWidth: Appearance.rounding.unsharpen
                value: root.activePlayer?.position / root.activePlayer?.length
                colPrimary: Appearance.colors.colOnSecondaryContainer
                enableAnimation: false
                Item {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
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

    // Horizontal Material
    Loader {
        id: materialRow
        active: !root.vertical && root.isMaterial
        visible: active
        anchors.centerIn: parent
        sourceComponent: Rectangle {
            id: card
            color: Appearance.colors.colSecondaryContainer
            radius: Appearance.rounding.full
            implicitHeight: 30
            implicitWidth: innerRow.implicitWidth + 8

            RowLayout {
                id: innerRow
                anchors.centerIn: parent
                spacing: 6

                // Art
                Rectangle {
                    id: artRect
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer
                    Layout.alignment: Qt.AlignVCenter

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artRect.width
                            height: artRect.height
                            radius: artRect.radius
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: artRect.width
                        sourceSize.height: artRect.height
                        visible: root.displayedArtFilePath !== ""
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "music_note"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: root.displayedArtFilePath === ""
                    }
                }

                // Title + Artist
                ColumnLayout {
                    spacing: -4
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 2

                    StyledText {
                        id: artistText
                        text: root.trackArtist
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: artistText; property: "x"; to: -artistText.width; duration: 150; easing.type: Easing.InQuad }
                                PropertyAction { target: artistText; property: "text" }
                                NumberAnimation { target: artistText; property: "x"; from: artistText.width; to: 0; duration: 150; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                    StyledText {
                        id: titleText
                        Layout.topMargin: !root.activePlayer ? -13 : 0
                        text: StringUtils.cleanMusicTitle(root.trackTitle) || Translation.tr("No media")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                        opacity: 0.7
                        Layout.maximumWidth: 120
                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: titleText; property: "x"; to: -artistText.width; duration: 150; easing.type: Easing.InQuad }
                                PropertyAction { target: titleText; property: "text" }
                                NumberAnimation { target: titleText; property: "x"; from: artistText.width; to: 0; duration: 150; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                // Play/Pause
                RippleButton {
                    implicitWidth: 40
                    implicitHeight: 23
                    buttonRadius: root.isPlaying ? Appearance.rounding.normal : 13
                    colBackground: root.isPlaying ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                    colBackgroundHover: root.isPlaying ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover
                    colRipple: root.isPlaying ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive
                    downAction: () => root.activePlayer?.togglePlaying()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: root.isPlaying ? "pause" : "play_arrow"
                        iconSize: Appearance.font.pixelSize.large
                        fill: 1
                        color: root.isPlaying ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer
                    }
                }

                // Next
                RippleButton {
                    implicitWidth: 26
                    implicitHeight: 26
                    Layout.leftMargin: -4
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    downAction: () => root.activePlayer?.next()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "skip_next"
                        iconSize: Appearance.font.pixelSize.large
                        fill: 1
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }
}