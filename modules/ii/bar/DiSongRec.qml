import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: song
    required property Item di
    anchors {
        fill: parent
        leftMargin: 6
        rightMargin: 12
    }
    spacing: 8

    readonly property bool showResult: song.di.primaryId === "songRecResult"
    readonly property var result: IslandEvents.songRecResult.payload ?? ({})

    Item {
        implicitWidth: 24
        implicitHeight: 24

        Repeater {
            model: song.showResult ? 0 : 2
            delegate: Rectangle {
                id: ring
                required property int index
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 12
                color: "transparent"
                border.width: 1.5
                border.color: Appearance.colors.colPrimary

                ParallelAnimation {
                    running: true
                    loops: Animation.Infinite
                    SequentialAnimation {
                        PauseAnimation { duration: ring.index * 600 }
                        NumberAnimation { target: ring; property: "scale"; from: 0.3; to: 1; duration: 1200; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: ring.index * 600 }
                        NumberAnimation { target: ring; property: "opacity"; from: 1; to: 0; duration: 1200; easing.type: Easing.InQuad }
                    }
                }
            }
        }

        MaterialShapeWrappedMaterialSymbol {
            anchors.centerIn: parent
            wrappedShape: song.showResult ? MaterialShape.Shape.Cookie7Sided : MaterialShape.Shape.Circle
            color: song.showResult ? Appearance.colors.colPrimary : "transparent"
            colSymbol: song.showResult ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
            text: song.showResult ? "music_note" : "graphic_eq"
            iconSize: 14
            fill: 1
            padding: 4
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: song.showResult ? (song.result.title ?? "") : Translation.tr("Listening…")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: song.showResult
            text: song.result.subtitle ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }
}
