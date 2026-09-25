import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: flag
    required property Item di
    anchors.fill: parent
    clip: true

    readonly property color flagColor: F1.flagColor(F1.flag)
    readonly property bool safetyCar: F1.flag === "sc" || F1.flag === "vsc" || F1.flag === "vscEnding"

    Rectangle {
        id: wash
        anchors.fill: parent
        radius: height / 2
        color: flag.flagColor
        opacity: 0.9

        SequentialAnimation on opacity {
            running: F1.flag === "yellow" || F1.flag === "vscEnding"
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 700; easing.type: Easing.InOutSine }
        }

    }

    MaterialSymbol {
        id: car
        visible: false
        anchors.verticalCenter: parent.verticalCenter
        text: "directions_car"
        iconSize: 18
        fill: 1
        color: "#111111"
        opacity: 0.35

    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 7

        MaterialSymbol {
            text: F1.flag === "green" ? "flag" : flag.safetyCar ? "car_crash" : "flag"
            iconSize: 17
            fill: 1
            color: "#111111"
        }

        StyledText {
            Layout.fillWidth: true
            text: F1.flagLabel(F1.flag)
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Bold
            color: "#111111"
            elide: Text.ElideRight
        }

        StyledText {
            visible: F1.totalLaps > 0
            text: `L${F1.lap}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: "#111111"
        }
    }
}
