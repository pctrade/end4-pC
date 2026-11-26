import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Song recognition: the match with quick actions on the left, recent tracks on the right.
RowLayout {
    id: xsr
    required property Item di
    spacing: 20
    implicitWidth: xsr.wantedWidth
    readonly property real wantedWidth: 532

    readonly property bool showResult: xsr.di.expandedId === "songRecResult"
    readonly property var result: IslandEvents.songRecResult.payload ?? ({})
    readonly property var history: SongRec.history ?? []

    property bool copied: false
    Timer {
        id: copiedReset
        interval: 1600
        onTriggered: xsr.copied = false
    }

    readonly property string secondaryLine: {
        const bits = [xsr.result.subtitle ?? ""]
        if (xsr.result.album) bits.push(xsr.result.year ? `${xsr.result.album} (${xsr.result.year})` : xsr.result.album)
        return bits.filter(Boolean).join(" · ")
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component ActionButton: Rectangle {
        id: action
        property string icon: ""
        property string brand: ""
        property color tint: Appearance.colors.colPrimary
        property var onTap: null
        implicitWidth: 32
        implicitHeight: 32
        radius: 16
        color: actionMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        DiBrandIcon {
            anchors.centerIn: parent
            visible: action.brand !== ""
            source: action.brand !== "" ? Quickshell.shellPath(`assets/island/apps/${action.brand}.svg`) : ""
            size: 15
            color: action.tint
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: action.brand === ""
            text: action.icon
            iconSize: 16
            fill: 1
            color: action.tint
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (action.onTap) action.onTap()
        }
    }

    ColumnLayout {
        Layout.fillWidth: false
        Layout.preferredWidth: 150
        Layout.maximumWidth: 150
        Layout.alignment: Qt.AlignTop
        spacing: 6

        Rectangle {
            id: coverBox
            Layout.preferredWidth: 150
            Layout.preferredHeight: 130
            radius: 20
            clip: true
            color: Appearance.colors.colLayer1
            DiCascade { target: coverBox; index: 0 }

            StyledImage {
                id: coverImg
                anchors.fill: parent
                visible: xsr.showResult
                source: xsr.showResult ? (xsr.result.cover ?? "") : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 260
                sourceSize.height: 260
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: xsr.showResult && coverImg.status !== Image.Ready
                text: "album"
                iconSize: 36
                color: Appearance.colors.colOnLayer1
                opacity: 0.35
            }

            RowLayout {
                anchors.centerIn: parent
                visible: !xsr.showResult
                spacing: 5

                Repeater {
                    model: 4

                    Rectangle {
                        id: eqBar
                        required property int index
                        Layout.alignment: Qt.AlignVCenter
                        width: 6
                        radius: 3
                        height: 14
                        color: Appearance.colors.colPrimary

                        SequentialAnimation {
                            running: !xsr.showResult
                            loops: Animation.Infinite
                            NumberAnimation {
                                target: eqBar
                                property: "height"
                                to: 30 + (eqBar.index % 3) * 12
                                duration: 360 + eqBar.index * 70
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: eqBar
                                property: "height"
                                to: 12
                                duration: 360 + eqBar.index * 70
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: xsr.showResult
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 6
                }
                width: 24
                height: 24
                radius: 12
                color: xsr.di.surfaceColor
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "graphic_eq"
                    iconSize: 13
                    fill: 1
                    color: Appearance.colors.colPrimary
                }
            }
        }

        ColumnLayout {
            id: textBlock
            Layout.fillWidth: true
            spacing: 1
            DiCascade { target: textBlock; index: 1 }

            StyledText {
                Layout.fillWidth: true
                text: xsr.showResult ? (xsr.result.title ?? "") : Translation.tr("Listening…")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: xsr.showResult ? xsr.secondaryLine : Translation.tr("Identifying the song playing")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: actionRow
            Layout.fillWidth: true
            spacing: 6
            DiCascade { target: actionRow; index: 2 }

            ActionButton {
                visible: xsr.showResult
                icon: xsr.copied ? "check" : "content_copy"
                tint: xsr.copied ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                onTap: () => {
                    Quickshell.clipboardText = `${xsr.result.subtitle ?? ""} – ${xsr.result.title ?? ""}`
                    xsr.copied = true
                    copiedReset.restart()
                }
            }
            ActionButton {
                visible: xsr.showResult && !!xsr.result.spotifyUrl
                brand: "spotify"
                tint: "#1ED760"
                onTap: () => Qt.openUrlExternally(xsr.result.spotifyUrl)
            }
            ActionButton {
                visible: xsr.showResult && !!xsr.result.youtubeUrl
                brand: "youtube"
                tint: "#FF0000"
                onTap: () => Qt.openUrlExternally(xsr.result.youtubeUrl)
            }
            ActionButton {
                visible: xsr.showResult && !!(xsr.result.shazamUrl || xsr.result.url)
                icon: "open_in_new"
                onTap: () => Qt.openUrlExternally(xsr.result.shazamUrl || xsr.result.url)
            }

            Rectangle {
                visible: !xsr.showResult
                Layout.fillWidth: true
                implicitHeight: 32
                radius: 16
                color: stopMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: "stop"
                        iconSize: 15
                        fill: 1
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Stop")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer1
                    }
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        SongRec.toggleRunning(false)
                        xsr.di.collapse()
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 6

        RowLayout {
            id: histHeader
            Layout.fillWidth: true
            DiCascade { target: histHeader; index: 3 }

            SectionLabel {
                Layout.fillWidth: true
                text: Translation.tr("Recently recognized")
            }
            SectionLabel {
                visible: xsr.history.length > 0
                text: xsr.history.length
                font.features: { "tnum": 1 }
                opacity: 0.4
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 188

            ColumnLayout {
                id: emptyState
                anchors.centerIn: parent
                visible: xsr.history.length === 0
                spacing: 2
                DiCascade { target: emptyState; index: 4 }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "music_off"
                    iconSize: 26
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.35
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Nothing recognized yet")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Matches show up here")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.45
                }
            }

            Flickable {
                id: histList
                anchors.fill: parent
                clip: true
                contentHeight: histColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: histList.contentHeight > histList.height

                ColumnLayout {
                    id: histColumn
                    width: histList.width
                    spacing: 4

                    Repeater {
                        // By count, so the list isn't rebuilt when tracks are prepended
                        model: xsr.history.length

                        Rectangle {
                            id: histRow
                            required property int index
                            readonly property var track: xsr.history[histRow.index] ?? ({})
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 12
                            color: histMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                            DiCascade { target: histRow; index: 4 + histRow.index }

                            Behavior on color {
                                ColorAnimation { duration: IslandMotion.micro }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 6
                                    rightMargin: 8
                                }
                                spacing: 8

                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 9
                                    clip: true
                                    color: Appearance.colors.colLayer2

                                    StyledImage {
                                        id: histImg
                                        anchors.fill: parent
                                        source: histRow.track.cover ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 56
                                        sourceSize.height: 56
                                    }
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: histImg.status !== Image.Ready
                                        text: "music_note"
                                        iconSize: 14
                                        color: Appearance.colors.colOnLayer1
                                        opacity: 0.5
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: -1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: histRow.track.title ?? ""
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: histRow.track.subtitle ?? ""
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colOnLayer1
                                        opacity: 0.6
                                        elide: Text.ElideRight
                                    }
                                }

                                MaterialSymbol {
                                    text: "open_in_new"
                                    iconSize: 14
                                    color: Appearance.colors.colOnLayer1
                                    opacity: histMouse.containsMouse ? 0.8 : 0.35
                                    Behavior on opacity { NumberAnimation { duration: IslandMotion.micro } }
                                }
                            }

                            MouseArea {
                                id: histMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const url = histRow.track.shazamUrl || histRow.track.url
                                    if (url) Qt.openUrlExternally(url)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
