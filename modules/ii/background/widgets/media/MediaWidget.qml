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

    property real widgetSize: 200
    property real controlsSize: 55
    property real buttonIconSize: 30

    property bool downloaded: false
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    implicitHeight: contentItem.implicitHeight
    implicitWidth: contentItem.implicitWidth

    property bool hovering: false
    hoverEnabled: true
    onEntered: { hovering = true }
    onExited:  { hovering = false }

    onArtFilePathChanged: updateArt()

    function updateArt() {
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
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    Item {
        id: contentItem

        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

        FadeLoader {
            z: 2
            anchors.centerIn: parent
            shown: root.currentPlayer == null
            sourceComponent: MaterialShapeWrappedMaterialSymbol {
                padding: 20
                text: root.currentPlayer == null ? "music_off" : !root.downloaded ? "hourglass_bottom" : ""
                anchors.centerIn: parent
                iconSize: root.widgetSize / 4
                shape: MaterialShape.Shape.Cookie12Sided
                color: Appearance.colors.colOnSecondaryContainer
                colSymbol: Appearance.colors.colPrimaryContainer
            }
        }

        MaterialShape {
            id: artBackground
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shape: MaterialShape.Shape.Cookie4Sided

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: MaterialShape {
                    width: artBackground.width
                    height: artBackground.height
                    shape: MaterialShape.Shape.Cookie4Sided
                }
            }

            StyledImage {
                id: mediaArt
                property int size: parent.height
                anchors.fill: parent

                source: root.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true

                width: size
                height: size
                sourceSize.width: size
                sourceSize.height: size
            }
        }

        Loader {
            active: Config.options.background.widgets.media.showTitles
            anchors {
                left: parent.left
                bottom: parent.bottom
            }
            sourceComponent: Column {
                spacing: 0

                Rectangle {
                    implicitWidth: controlsSize * 2
                    implicitHeight: controlsSize - 10
                    z: 2
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            width: controlsSize * 2 - 12
                            text: root.currentPlayer?.trackArtist ?? ""
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            width: controlsSize * 2 - 12
                            text: root.currentPlayer?.trackTitle ?? ""
                            color: Appearance.colors.colOnSecondaryContainer
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // cajita decorativa centrada debajo
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 8 + cornerRadius * 2   // el rect + espacio para las esquinas
                    height: Config.options.background.widgets.media.showLyrics ? 16 : 0
                    
                    property int cornerRadius: 4  // r = mitad del ancho del rect (8/2)

                    // El rect principal SIN radius en las esquinas de arriba
                    Rectangle {
                        id: theRect
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 0
                        height: Config.options.background.widgets.media.showLyrics ? 16 : 0
                        color: Appearance.colors.colSecondaryContainer
                        // solo radio abajo
                        radius: 0
                    }

                    // Esquina cóncava izquierda
                    RoundCorner {
                        visible: Config.options.background.widgets.media.showLyrics
                        anchors.right: theRect.left
                        anchors.top: theRect.top
                        implicitSize: cornerRadius
                        color: Appearance.colors.colSecondaryContainer // color del fondo/barra
                        corner: RoundCorner.CornerEnum.TopRight  // curva hacia adentro
                    }

                    // Esquina cóncava derecha
                    RoundCorner {
                        visible: Config.options.background.widgets.media.showLyrics
                        anchors.left: theRect.right
                        anchors.top: theRect.top
                        implicitSize: cornerRadius
                        color: Appearance.colors.colSecondaryContainer
                        corner: RoundCorner.CornerEnum.TopLeft
                    }
                    Item {
                        width: 320
                        height: Config.options.background.widgets.media.showLyrics ? 250 + 16 : 0
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            id: lyricsBox
                            visible: Config.options.background.widgets.media.showLyrics
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 320
                            height: 250
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSecondaryContainer

                            Lyrics {
                                id: lyricsComp
                                anchors.fill: parent
                                anchors.margins: 16
                                player: root.currentPlayer
                                textColor: Appearance.colors.colOnLayer0
                                activeColor: Appearance.colors.colPrimary
                                dimColor: Appearance.colors.colSubtext
                                indicatorColor: Appearance.colors.colPrimary
                                indicatorShapeColor: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }
        }

        FadeLoader {
            active: Config.options.background.widgets.media.showControls
            anchors {
                top: parent.top
                right: parent.right
            }
            sourceComponent: ControlButton {
                buttonRadius: root.currentPlayer?.isPlaying ? Appearance.rounding.normal : controlsSize / 2
                colBackground: Appearance.colors.colTertiaryContainer
                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                colRipple: Appearance.colors.colTertiaryContainerActive
                symbolText: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                symbolColor: Appearance.colors.colSecondary
                onClicked: {
                    root.currentPlayer.togglePlaying()
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
                    onPressed: (event) => {
                        if (event.button === Qt.MiddleButton || event.button === Qt.BackButton) {
                            root.currentPlayer.previous()
                        } else if (event.button === Qt.RightButton || event.button === Qt.ForwardButton) {
                            root.currentPlayer.next()
                        }
                    }
                }
            }
        }
    }

    component ControlButton: RippleButton {
        id: button
        property string symbolText
        property color symbolColor

        z: 2
        implicitWidth: controlsSize
        implicitHeight: implicitWidth
        buttonRadius: Appearance.rounding.full

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: root.buttonIconSize
            text: button.symbolText
            fill: 1
            color: button.symbolColor
        }
    }
}