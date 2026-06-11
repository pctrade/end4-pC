import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.services
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    signal requestReset()

    configEntryName: "media"

    readonly property var playerList: MprisController.players
    property MprisPlayer currentPlayer: MprisController.activePlayer
    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    property real widgetWidth: 420
    property real widgetHeight: 70
    property real artSize: 50
    property real buttonSize: 36
    property real buttonIconSize: 20

    property bool downloaded: false
    property bool showLyrics: false

    property string displayedArtFilePath: {
        if (!root.downloaded) return ""
        if (root.artUrl && root.artUrl.startsWith("file://")) return root.artUrl
        return root.downloaded ? Qt.resolvedUrl(artFilePath) : ""
    }

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    onArtFilePathChanged: updateArt()

    function updateArt() {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.downloaded = false
            return
        }
        if (root.artUrl.startsWith("file://")) {
            root.downloaded = true
            return
        }
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: { root.downloaded = true }
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight + (root.showLyrics ? 267 : 0)
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        Behavior on implicitHeight {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Main Row
            RowLayout {
                width: parent.width
                height: root.widgetHeight
                spacing: 12

                Item { width: 0; height: 1 }

                // Art
                Rectangle {
                    id: artRect
                    implicitWidth: root.artSize
                    implicitHeight: root.artSize
                    radius: Appearance.rounding?.full ?? 999
                    color: Appearance.colors.colSecondaryContainer
                    Layout.alignment: Qt.AlignVCenter
                    clip: true
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
                        iconSize: root.artSize / 2
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: root.displayedArtFilePath === ""
                    }
                }

                // Artist + Title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackArtist ?? ""
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.SemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackTitle ?? Translation.tr("No media")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                // Buttons
                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    RippleButton {
                        implicitWidth: root.buttonSize
                        implicitHeight: root.buttonSize
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: root.showLyrics
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.85)
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        downAction: () => { root.showLyrics = !root.showLyrics }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "lyrics"
                            iconSize: root.buttonIconSize
                            fill: root.showLyrics ? 1 : 0
                            color: root.showLyrics
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                        iconSize: root.buttonIconSize
                        fill: 1
                        padding: 8

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentPlayer?.togglePlaying()
                        }
                    }

                    RippleButton {
                        implicitWidth: root.buttonSize
                        implicitHeight: root.buttonSize
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.85)
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        downAction: () => root.currentPlayer?.next()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: root.buttonIconSize
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }

                Item { width: 5; height: 1 }
            }

            // Divisor
            Item {
                width: parent.width
                height: root.showLyrics ? 16 : 0
                visible: root.showLyrics

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.2; color: Appearance.colors.colOnPrimaryContainer }
                        GradientStop { position: 0.8; color: Appearance.colors.colOnPrimaryContainer }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    opacity: 0.15
                }
            }

            // Lyrics
            Item {
                width: parent.width
                height: root.showLyrics ? 250 : 0
                visible: root.showLyrics

                Lyrics {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    textAlignment: Text.AlignHCenter
                    textColor: Appearance.colors.colOnPrimaryContainer
                    activeColor: Appearance.colors.colPrimary
                    dimColor: Appearance.colors.colSubtext
                    indicatorColor: Appearance.colors.colPrimary
                    indicatorShapeColor: Appearance.colors.colOnPrimary
                }
            }
        }
    }
}