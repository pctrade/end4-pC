import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Pit stops (tyre change), rain at the track and the session result
RowLayout {
    id: event
    required property Item di
    anchors {
        fill: parent
        leftMargin: 5
        rightMargin: 12
    }
    spacing: 8

    readonly property var payload: event.di.f1Event ?? ({})
    readonly property color accent: event.payload.color ?? Appearance.colors.colPrimary

    TapHandler {
        enabled: event.payload.kind === "radio"
        onTapped: F1.playRadio(event.payload.url ?? "")
    }
    HoverHandler {
        enabled: event.payload.kind === "radio"
        cursorShape: Qt.PointingHandCursor
    }

    Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: 12
        color: event.payload.kind === "tyre" ? "#1B1B1B" : ColorUtils.transparentize(event.accent, 0.75)
        border.width: event.payload.kind === "tyre" ? 3 : 0
        border.color: event.accent

        StyledText {
            anchors.centerIn: parent
            visible: event.payload.kind === "tyre"
            text: event.payload.letter ?? ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Black
            color: event.accent
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: event.payload.kind !== "tyre"
            text: event.payload.icon ?? "sports_motorsports"
            iconSize: 15
            fill: 1
            color: event.accent
        }

        RotationAnimation on rotation {
            running: event.payload.kind === "tyre"
            from: -360
            to: 0
            duration: 900
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: event.payload.title ?? ""
            font.features: { "tnum": 1 }
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: event.payload.kind === "radio" && F1.radioPlaying ? Translation.tr("Playing…") : (event.payload.subtitle ?? "")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }
}
