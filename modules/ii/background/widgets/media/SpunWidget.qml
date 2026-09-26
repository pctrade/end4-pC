pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "spun"
    readonly property var player: Spun.player
    readonly property real discSize: Math.max(160, Math.min(360, configEntry.size))
    readonly property real trackLength: Math.max(0, player?.length ?? 0)
    readonly property real position: Math.max(0, player?.position ?? 0)
    implicitWidth: discSize + 32
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && !GlobalStates.screenLocked
            && (root.player?.isPlaying ?? false) && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.verylarge
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        FastBlurred {
            anchors.fill: parent
            blurSource: root.wallpaperItem
            cardRadius: card.radius
            tint: Appearance.colors.colLayer1
            tintOpacity: 0.55
            trackX: root.x
            trackY: root.y
            visible: Config.options.background.widgets.blurWidgets
        }
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            MaterialSymbol {
                text: "album"
                iconSize: 20
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: "Spun"
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            IconToolbarButton {
                implicitWidth: 32
                implicitHeight: 32
                text: "open_in_new"
                Accessible.name: Translation.tr("Open Spun")
                onClicked: Spun.open()
                StyledToolTip { text: Translation.tr("Open Spun") }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.discSize
            Layout.preferredHeight: root.discSize

            Rectangle {
                id: disc
                anchors.fill: parent
                radius: width / 2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f3f0f8" }
                    GradientStop { position: 0.24; color: "#969da9" }
                    GradientStop { position: 0.5; color: "#e0e5e6" }
                    GradientStop { position: 0.75; color: "#a5a0b6" }
                    GradientStop { position: 1; color: "#eef0f4" }
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 12000
                    loops: Animation.Infinite
                    running: root.visible && !GlobalStates.screenLocked && root.configEntry.animate
                    paused: !(root.player?.isPlaying ?? false)
                }

                Image {
                    id: artwork
                    anchors.fill: parent
                    anchors.margins: 12
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize.width: Math.round(root.discSize * 2)
                    sourceSize.height: Math.round(root.discSize * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artwork.width
                            height: artwork.height
                            radius: width / 2
                        }
                    }
                }

                Repeater {
                    model: artwork.status === Image.Ready ? 3 : 9
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: root.discSize - 8 - index * 6
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#30ffffff"
                    }
                }

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.2
                    visible: artwork.status !== Image.Ready
                    text: "music_note"
                    iconSize: root.discSize * 0.15
                    color: "#626775"
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.discSize * 0.22
                    height: width
                    radius: width / 2
                    color: "#b9bdc6"
                    border.width: 1
                    border.color: "#f0f1f4"
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.discSize * 0.09
                        height: width
                        radius: width / 2
                        color: Appearance.colors.colLayer0
                        border.width: 1
                        border.color: "#7d8290"
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || Translation.tr("Ready to spin")
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: Spun.launchError || (Spun.launching ? Translation.tr("Opening Spun…")
                    : root.player ? root.player.trackArtist || Translation.tr("Choose music in Spun")
                    : Translation.tr("Open Spun to start listening"))
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Spun.launchError ? Text.WordWrap : Text.NoWrap
                elide: Text.ElideRight
                color: Spun.launchError ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            }
        }

        StyledSlider {
            id: seekSlider
            objectName: "spunSeek"
            Layout.fillWidth: true
            configuration: StyledSlider.Configuration.XS
            from: 0
            to: Math.max(1, root.trackLength)
            enabled: (root.player?.canSeek ?? false) && root.trackLength > 0
            value: root.position
            usePercentTooltip: false
            tooltipContent: StringUtils.friendlyTimeForSeconds(value)
            Accessible.name: Translation.tr("Playback position")
            onMoved: if (root.player?.canSeek) root.player.position = value
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: StringUtils.friendlyTimeForSeconds(root.position)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
            Item { Layout.fillWidth: true }
            IconToolbarButton {
                objectName: "spunPrevious"
                implicitWidth: 36
                implicitHeight: 36
                text: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                Accessible.name: Translation.tr("Previous track")
                onClicked: root.player.previous()
            }
            IconToolbarButton {
                objectName: "spunPlayPause"
                implicitWidth: 44
                implicitHeight: 44
                text: root.player?.isPlaying ? "pause" : "play_arrow"
                enabled: !root.player || root.player.canTogglePlaying
                colBackground: Appearance.colors.colPrimary
                colText: Appearance.colors.colOnPrimary
                Accessible.name: !root.player ? Translation.tr("Open Spun")
                    : root.player.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                onClicked: root.player ? root.player.togglePlaying() : Spun.open()
            }
            IconToolbarButton {
                objectName: "spunNext"
                implicitWidth: 36
                implicitHeight: 36
                text: "skip_next"
                enabled: root.player?.canGoNext ?? false
                Accessible.name: Translation.tr("Next track")
                onClicked: root.player.next()
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: StringUtils.friendlyTimeForSeconds(root.trackLength)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }

        RowLayout {
            Layout.fillWidth: true
            MaterialSymbol {
                text: "volume_up"
                iconSize: 18
                color: Appearance.colors.colSubtext
            }
            StyledSlider {
                objectName: "spunVolume"
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.XS
                enabled: root.player?.volumeSupported ?? false
                value: root.player?.volume ?? 0
                Accessible.name: Translation.tr("Spun volume")
                onMoved: if (root.player?.volumeSupported) root.player.volume = value
            }
        }
    }
}
