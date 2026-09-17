pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property color dimColor: Qt.rgba(1, 1, 1, 0.35)
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property color indicatorShapeColor: Appearance.colors.colOnPrimaryContainer
    property int textAlignment: Text.AlignLeft

    implicitWidth: 200
    implicitHeight: 200

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status !== "ok"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48

                    MaterialLoadingIndicator {
                        anchors.fill: parent
                        loading: LyricsService.status === "loading"
                        colBg: root.indicatorColor
                        colShape: root.indicatorShapeColor
                        implicitSize: 48
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.restartLyrics()
                    }
                }
            }
        }

        ListView {
            id: lyricViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LyricsService.status === "ok"
            clip: true
            model: LyricsService.lyricsLines
            currentIndex: Math.max(0, LyricsService.activeIndex)
            preferredHighlightBegin: height / 2 - 20
            preferredHighlightEnd: height / 2 + 20
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 420
            highlightMoveVelocity: -1
            maximumFlickVelocity: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: lyricLine
                required property int index
                required property var modelData
                width: lyricViewport.width
                implicitHeight: wordFlow.implicitHeight + 8
                readonly property int dist: Math.abs(index - lyricViewport.currentIndex)
                readonly property var wordModel: (modelData.words && modelData.words.length > 0)
                    ? modelData.words : [{ time: modelData.time, text: modelData.text || "♪" }]
                opacity: dist === 0 ? 1 : dist === 1 ? 0.62 : dist === 2 ? 0.34 : 0.14
                scale: dist === 0 ? 1.035 : dist === 1 ? 1.01 : 1
                transformOrigin: Item.Left
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                Flow {
                    id: wordFlow
                    width: parent.width
                    spacing: 0
                    layoutDirection: root.textAlignment === Text.AlignRight ? Qt.RightToLeft : Qt.LeftToRight
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: lyricLine.wordModel
                        delegate: Item {
                            required property int index
                            required property var modelData
                            implicitWidth: wordText.implicitWidth + 5
                            implicitHeight: wordText.implicitHeight + 6

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 5
                                color: root.activeColor
                                opacity: lyricLine.dist === 0 &&
                                    (modelData.time <= LyricsService.playbackPosition) &&
                                    (LyricsService.activeWordIndex === index || lyricLine.wordModel.length === 1)
                                    ? 0.18 : 0
                                Behavior on opacity { NumberAnimation { duration: 110 } }
                            }

                            StyledText {
                                id: wordText
                                anchors.centerIn: parent
                                text: modelData.text
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: lyricLine.dist === 0
                                    ? Appearance.font.pixelSize.normal
                                    : lyricLine.dist === 1 ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                                font.weight: lyricLine.dist === 0 ? Font.DemiBold : Font.Normal
                                color: lyricLine.dist === 0 &&
                                    (LyricsService.activeWordIndex === index || lyricLine.wordModel.length === 1)
                                    ? root.activeColor : root.textColor
                                Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }
    }
}
