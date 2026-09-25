import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: xsr
    required property Item di
    spacing: 14
    implicitWidth: 320
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 320

    readonly property bool showResult: xsr.di.expandedId === "songRecResult"
    readonly property var result: IslandEvents.songRecResult.payload ?? ({})

    MaterialShapeWrappedMaterialSymbol {
        wrappedShape: xsr.showResult ? MaterialShape.Shape.Cookie7Sided : MaterialShape.Shape.SoftBurst
        color: Appearance.colors.colPrimary
        colSymbol: Appearance.colors.colOnPrimary
        text: xsr.showResult ? "music_note" : "graphic_eq"
        iconSize: 26
        fill: 1
        padding: 12

        RotationAnimation on rotation {
            running: !xsr.showResult
            from: 0
            to: 360
            duration: 6000
            loops: Animation.Infinite
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            text: xsr.showResult ? (xsr.result.title ?? "") : Translation.tr("Listening…")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: xsr.showResult ? (xsr.result.subtitle ?? "") : Translation.tr("Identifying the song playing")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    Rectangle {
        implicitWidth: 40
        implicitHeight: 40
        radius: 20
        color: actionMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

        MaterialSymbol {
            anchors.centerIn: parent
            text: xsr.showResult ? "open_in_new" : "stop"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colOnLayer1
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (xsr.showResult && xsr.result.url) Qt.openUrlExternally(xsr.result.url)
                else SongRec.toggleRunning(false)
                xsr.di.collapse()
            }
        }
    }
}
