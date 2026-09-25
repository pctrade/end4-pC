import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xbat
    required property Item di
    spacing: 12
    implicitWidth: 360

    readonly property bool onBattery: !Battery.isPluggedIn

    readonly property color accent: Battery.isCharging ? Appearance.m3colors.m3success
        : Battery.percentage <= 0.2 ? Appearance.colors.colError : Appearance.colors.colPrimary

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Item {
            implicitWidth: 76
            implicitHeight: 76

            CircularProgress {
                anchors.fill: parent
                implicitSize: 76
                lineWidth: 6
                value: Battery.percentage
                colPrimary: xbat.accent
                colSecondary: ColorUtils.transparentize(xbat.accent, 0.8)
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: xbat.di.batteryIcon()
                iconSize: 28
                fill: 1
                color: xbat.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: `${Math.round(Battery.percentage * 100)}%`
                font.pixelSize: 30
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                text: Battery.isCharging
                    ? (Battery.timeToFull > 60 ? `${Translation.tr("Full in")} ${xbat.di.formatDuration(Battery.timeToFull)}` : Translation.tr("Charging"))
                    : Battery.isPluggedIn ? Translation.tr("Plugged in")
                    : (Battery.timeToEmpty > 60 ? `${xbat.di.formatDuration(Battery.timeToEmpty)} ${Translation.tr("left")}` : Translation.tr("On battery"))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
            }
        }
    }

    // On battery: quick ways to make it last, all undone when the charger goes in
    RowLayout {
        Layout.fillWidth: true
        visible: xbat.onBattery
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Save battery")
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
        }
        StyledText {
            text: PowerSaver.anyOn ? Translation.tr("Undone when you plug in") : ""
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.45
        }
    }

    DiSaverButtons {
        Layout.fillWidth: true
        visible: xbat.onBattery
    }

    Rectangle {
        Layout.fillWidth: true
        visible: xbat.onBattery
        implicitHeight: 34
        radius: 17
        color: saveAllMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
        opacity: PowerSaver.profileOn && PowerSaver.dimOn && PowerSaver.effectsOn ? 0.45 : 1

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                text: "battery_saver"
                iconSize: 17
                fill: 1
                color: Appearance.colors.colOnPrimary
            }
            StyledText {
                text: Translation.tr("Save everything")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimary
            }
        }

        MouseArea {
            id: saveAllMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerSaver.saveAll()
        }
    }

    // What's draining it right now (scanned only while this is open)
    StyledText {
        visible: xbat.onBattery
        text: Translation.tr("Using the most right now")
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Loader {
        Layout.fillWidth: true
        active: xbat.onBattery
        visible: active
        sourceComponent: DiProcessList {
            kind: "cpu"
            visibleRows: 3
            fadeColor: xbat.di.surfaceColor
        }
    }
}
