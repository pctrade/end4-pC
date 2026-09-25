import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: bt
    required property Item di
    anchors {
        fill: parent
        leftMargin: bt.di.isMaterial ? 2 : 4
        rightMargin: 12
    }
    spacing: 10

    readonly property var payload: IslandEvents.bluetooth.payload ?? ({})
    readonly property var device: IslandEvents.bluetoothDevice(bt.payload.address ?? "")
    readonly property string phase: bt.payload.phase ?? ""
    readonly property bool lowBattery: bt.phase === "lowBattery"
    readonly property bool connected: bt.phase === "connected" || bt.lowBattery
    readonly property real battery: bt.payload.battery !== undefined ? bt.payload.battery
        : (bt.device?.batteryAvailable ? Number(bt.device.battery) : -1)
    readonly property string shortName: IslandEvents.shortName(bt.payload.name ?? "")

    readonly property bool caseArt: IslandEvents.hasCaseArt(bt.payload.name) && IslandEvents.caseClosedArt !== ""

    Loader {
        id: caseLoader
        active: bt.caseArt
        visible: active
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        DiEntrance { target: caseLoader }
        sourceComponent: DiEarbudsCase {
            open: bt.connected
            busy: bt.phase === "connecting"
        }
    }

    MaterialShapeWrappedMaterialSymbol {
        id: btShape
        visible: !bt.caseArt

        DiEntrance { target: btShape }
        wrappedShape: bt.phase === "connecting" ? MaterialShape.Shape.Cookie12Sided
            : bt.connected ? MaterialShape.Shape.Circle : MaterialShape.Shape.Cookie4Sided
        color: bt.lowBattery ? Appearance.colors.colError
            : bt.connected ? Appearance.colors.colPrimary
            : bt.phase === "connecting" ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
        colSymbol: bt.connected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        text: bt.phase === "disconnected" ? "bluetooth_disabled"
            : bt.phase === "connecting" ? "bluetooth_searching" : IslandEvents.bluetoothSymbol(bt.payload.icon)
        iconSize: 16
        fill: 1
        padding: 5

        Behavior on color {
            ColorAnimation { duration: IslandMotion.short }
        }

        RotationAnimation on rotation {
            id: spin
            running: bt.phase === "connecting"
            from: 0
            to: 360
            duration: 2400
            loops: Animation.Infinite
            onRunningChanged: if (!running) settle.restart()
        }

        NumberAnimation {
            id: settle
            target: btShape
            property: "rotation"
            to: 0
            duration: IslandMotion.medium
            easing.type: Easing.OutBack
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: bt.lowBattery ? Translation.tr("Low battery") : bt.shortName
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: bt.lowBattery ? Appearance.colors.colError : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: bt.lowBattery ? `${bt.shortName} · ${Translation.tr("charge it in the case")}`
                : bt.phase === "connecting" ? Translation.tr("Connecting…")
                : bt.connected ? Translation.tr("Connected") : Translation.tr("Disconnected")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    RowLayout {
        visible: bt.connected && bt.battery >= 0
        spacing: 2

        MaterialSymbol {
            text: bt.lowBattery ? "battery_alert" : bt.battery > 0.8 ? "battery_full" : bt.battery > 0.3 ? "battery_5_bar" : "battery_2_bar"
            iconSize: bt.lowBattery ? 19 : 15
            fill: 1
            color: bt.battery <= 0.2 ? Appearance.colors.colError : Appearance.colors.colOnLayer0

            SequentialAnimation on opacity {
                running: bt.lowBattery
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
            }
        }
        StyledText {
            text: `${Math.round(bt.battery * 100)}%`
            font.pixelSize: bt.lowBattery ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
            font.weight: bt.lowBattery ? Font.Bold : Font.Normal
            font.features: { "tnum": 1 }
            color: bt.lowBattery ? Appearance.colors.colError : Appearance.colors.colOnLayer0
        }
    }
}
