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
    property MprisPlayer currentPlayer: {
        const preferred = Config.options.bar.media.preferredPlayer.trim().toLowerCase()
        if (preferred.length === 0) return MprisController.activePlayer
        const _ = MprisController.players.count
        for (const p of MprisController.players) {
            if ((p.identity ?? "").toLowerCase().includes(preferred) ||
                (p.desktopEntry ?? "").toLowerCase().includes(preferred))
                return p
        }
        return MprisController.activePlayer
    }
    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    property real widgetWidth: 420
    property real widgetHeight: 120
    property real buttonSize: 34
    property real buttonIconSize: 18

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

    StyledRectangularShadow {
        target: card
        z: -2
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight + (root.showLyrics ? 264 : 0)
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Main Row
            Item {
                width: parent.width
                height: root.widgetHeight

                Rectangle {
                    id: artRect
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.widgetHeight
                    color: Appearance.colors.colSurfaceContainerLow
                    topLeftRadius: card.radius
                    bottomLeftRadius: card.radius
                    topRightRadius: 0
                    bottomRightRadius: 0
                    clip: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artRect.width
                            height: artRect.height
                            topLeftRadius: card.radius
                            bottomLeftRadius: card.radius
                            topRightRadius: 0
                            bottomRightRadius: 0
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: artRect.width * 2
                        sourceSize.height: artRect.height * 2
                        visible: root.displayedArtFilePath !== ""
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "music_note"
                        iconSize: root.widgetHeight / 3
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: root.displayedArtFilePath === ""
                    }
                }

                ColumnLayout {
                    anchors {
                        left: artRect.right
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: Appearance.spacing.large
                        rightMargin: 14
                    }
                    spacing: -10

                    // Artist + Title
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Appearance.spacing.unsharpen

                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackArtist ?? "Play"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackTitle ?? Translation.tr("Something")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.65
                            elide: Text.ElideRight
                        }
                    }

                    // Controls 
                    Rectangle {
                        id: controlsPill
                        Layout.alignment: Qt.AlignRight
                        implicitWidth: controlsRow.implicitWidth + 10
                        implicitHeight: root.buttonSize + 8
                        radius: Appearance.rounding?.full ?? 999
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.9)

                        RowLayout {
                            id: controlsRow
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.unsharpen
                    
                            RippleButton {
                                implicitWidth: root.buttonSize
                                implicitHeight: root.buttonSize
                                buttonRadius: Appearance.rounding?.full ?? 999
                                colBackground: root.showLyrics
                                    ? Appearance.colors.colPrimary
                                    : "transparent"
                                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                colRipple: Appearance.colors.colPrimaryContainerActive
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
                                iconSize: root.buttonIconSize + 12
                                fill: 1
                                padding: Appearance.spacing.small

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.currentPlayer?.togglePlaying()
                                }
                            }

                            RippleButton {
                                implicitWidth: root.buttonSize
                                implicitHeight: root.buttonSize
                                buttonRadius: Appearance.rounding?.full ?? 999
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                colRipple: Appearance.colors.colPrimaryContainerActive
                                downAction: () => root.currentPlayer?.next()
                                altAction: () => root.currentPlayer?.previous()

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    iconSize: root.buttonIconSize
                                    fill: 1
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }
            }

            // Divisor
            Item {
                width: parent.width
                height: root.showLyrics ? 2 : 0
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

            Item {
                width: parent.width
                height: root.showLyrics ? 250 : 0
                visible: root.showLyrics

                Lyrics {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.spacing.large
                    anchors.rightMargin: Appearance.spacing.large
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
