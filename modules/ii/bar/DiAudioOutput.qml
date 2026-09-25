import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Where the sound is going. When headphones connect, the island shows the hand-off itself: the old device fades
// out on the left, an arc of sound travels across, and the new one lands on the right.
RowLayout {
    id: output
    required property Item di
    anchors {
        fill: parent
        leftMargin: output.di.isMaterial ? 2 : 4
        rightMargin: 12
    }
    spacing: 8

    readonly property var payload: IslandEvents.audioOutput.payload ?? ({})
    readonly property bool switching: output.payload.switching ?? false
    // The hand-off happens once, a beat after the island appears: everything else follows this single flag
    property bool handedOver: false

    onSwitchingChanged: {
        output.handedOver = false
        if (output.switching) handOverDelay.restart()
    }

    Component.onCompleted: if (output.switching) handOverDelay.restart()

    Timer {
        id: handOverDelay
        interval: 260
        onTriggered: output.handedOver = true
    }

    // The hand-off, drawn as one object instead of a parade of sparks: the old device fades back, a single arc
    // of sound sweeps across, and the new one settles in. One movement, one meaning.
    Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: output.switching ? 52 : 26
        implicitHeight: 26

        Behavior on implicitWidth {
            NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
        }

        // Where the sound is leaving from: present, then quietly out of the way
        MaterialSymbol {
            id: fromIcon
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            visible: output.switching
            text: "laptop_mac"
            iconSize: 15
            fill: 1
            color: Appearance.colors.colOnLayer0
            opacity: output.handedOver ? 0.25 : 0.7
            scale: output.handedOver ? 0.85 : 1

            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
            }
        }

        // The sound crossing over: a short arc that grows out of the old device and lands on the new one
        Rectangle {
            id: trail
            anchors.verticalCenter: parent.verticalCenter
            x: 18
            height: 2
            radius: 1
            width: output.handedOver ? 14 : 0
            color: Appearance.colors.colPrimary
            opacity: output.switching ? (output.handedOver ? 0.5 : 0) : 0
            visible: output.switching

            Behavior on width {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.medium }
            }
        }

        MaterialShapeWrappedMaterialSymbol {
            id: toIcon
            anchors.verticalCenter: parent.verticalCenter
            x: output.switching ? (output.handedOver ? 26 : 12) : 0
            wrappedShape: MaterialShape.Shape.Cookie9Sided
            color: Appearance.colors.colPrimaryContainer
            colSymbol: Appearance.colors.colOnPrimaryContainer
            text: output.payload.icon ?? "speaker"
            iconSize: 16
            fill: 1
            padding: 5
            opacity: output.switching && !output.handedOver ? 0.4 : 1
            scale: output.switching && !output.handedOver ? 0.7 : 1

            Behavior on x {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
            Behavior on opacity {
                NumberAnimation { duration: IslandMotion.medium; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: IslandMotion.long; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: -3

        StyledText {
            text: output.switching ? Translation.tr("Switching sound") : Translation.tr("Audio output")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: output.switching ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
            opacity: output.switching ? 1 : 0.7
        }
        StyledText {
            Layout.fillWidth: true
            text: IslandEvents.shortName(output.payload.name ?? "")
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
    }

    StyledText {
        text: `${Math.round(Audio.value * 100)}%`
        font.pixelSize: Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}
