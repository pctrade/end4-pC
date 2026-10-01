import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Bluetooth in two columns: headphones (battery ring, per-part levels, output) left, other devices and actions right.
RowLayout {
    id: xb
    required property Item di
    spacing: 20
    implicitWidth: xb.wantedWidth
    readonly property real wantedWidth: 532

    readonly property var payload: IslandEvents.bluetooth.payload ?? ({})
    readonly property bool simulated: (xb.payload.address ?? "") === "simulado"
    readonly property var device: IslandEvents.bluetoothDevice(xb.payload.address ?? "")
        ?? (xb.simulated ? null : BluetoothStatus.primaryConnectedDevice)
    readonly property bool hasMain: xb.device !== null || xb.simulated

    readonly property string fullName: xb.device ? (xb.device.name || xb.device.deviceName || "") : (xb.payload.name ?? "")
    readonly property string name: IslandEvents.shortName(xb.fullName) || Translation.tr("Bluetooth device")
    readonly property string icon: xb.device?.icon ?? xb.payload.icon ?? ""
    readonly property bool busy: xb.device ? (xb.device.state === BluetoothDeviceState.Connecting)
        : xb.payload.phase === "connecting"
    readonly property bool connected: xb.device ? !!BluetoothStatus.isConnected(xb.device)
        : (xb.payload.phase === "connected" || xb.payload.phase === "lowBattery")
    readonly property var batterySource: xb.device
        ?? BluetoothStatus.connectedBatteryDevices.find(d => (d.name ?? "").toLowerCase() === xb.fullName.toLowerCase()) ?? null
    readonly property real battery: xb.simulated && xb.payload.battery !== undefined ? xb.payload.battery
        : BluetoothStatus.hasBattery(xb.batterySource) ? Number(xb.batterySource.battery)
        : (xb.payload.battery ?? -1)
    readonly property bool lowBattery: xb.connected && xb.battery >= 0 && xb.battery <= 0.2
    // Left bud, right bud, case: only when the device reports them apart ({ label, value } in the payload)
    readonly property var parts: (xb.payload.parts ?? []).filter(p => p.value >= 0)
    readonly property bool caseArt: IslandEvents.hasCaseArt(xb.fullName) && IslandEvents.caseClosedArt !== ""

    readonly property string sinkName: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : ""
    readonly property bool isOutput: {
        const sink = Audio.sink?.name ?? ""
        const address = (xb.device?.address ?? "").replace(/:/g, "_")
        if (address !== "" && sink.includes(address)) return true
        return sink.startsWith("bluez") && xb.sinkName.toLowerCase().includes(xb.name.toLowerCase())
    }

    readonly property var others: {
        const mainAddress = xb.device?.address ?? ""
        const mainName = xb.fullName.toLowerCase()
        const other = d => d.address !== mainAddress && (d.name ?? "").toLowerCase() !== mainName
        return [...BluetoothStatus.connectedDevices.filter(other), ...BluetoothStatus.pairedButNotConnectedDevices.filter(other)].slice(0, 3)
    }

    readonly property color accent: xb.lowBattery ? Appearance.colors.colError : Appearance.colors.colPrimary

    DiSpring {
        id: ringReveal
        stiffness: 50
        dampingRatio: 1
        epsilon: 0.002
    }
    Timer {
        interval: 260
        running: true
        onTriggered: ringReveal.target = 1
    }

    function percent(level) {
        return `${Math.round(Math.max(0, level) * 100)}%`
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component LevelBar: Rectangle {
        id: bar
        property real level: 0
        property color tint: Appearance.colors.colPrimary
        implicitWidth: 28
        implicitHeight: 4
        radius: 2
        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            radius: 2
            width: bar.width * Math.max(0, Math.min(1, bar.level)) * ringReveal.value
            color: bar.tint
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string value: ""
        property string label: ""
        // 0..1 fills the chip's background from the left as it comes in; -1 = no fill
        property real meter: -1
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        radius: 12
        color: Appearance.colors.colLayer1
        clip: true

        Rectangle {
            visible: chip.meter >= 0
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: chip.width * Math.max(0, Math.min(1, chip.meter)) * ringReveal.value
            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.86)
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 8
            }
            spacing: 8

            MaterialSymbol {
                text: chip.icon
                iconSize: 18
                fill: 1
                color: Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1
                StyledText {
                    Layout.fillWidth: true
                    text: chip.value
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: chip.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.55
                    elide: Text.ElideRight
                }
            }
        }
    }

    component Action: Rectangle {
        id: action
        property string icon: ""
        property string text: ""
        property int order: 0
        property bool available: true
        signal tapped()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        radius: 12
        color: actionMouse.containsMouse && action.available ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
        DiCascade { target: action; index: action.order; pressed: actionMouse.pressed && action.available }

        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            opacity: action.available ? 1 : 0.4

            MaterialSymbol {
                text: action.icon
                iconSize: 17
                fill: 1
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: action.text
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: action.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (action.available) action.tapped()
        }
    }

    ColumnLayout {
        // Children filling the width would otherwise make this column fill the row too
        Layout.fillWidth: false
        Layout.preferredWidth: 236
        Layout.maximumWidth: 236
        Layout.fillHeight: true
        spacing: 0

        ColumnLayout {
            id: titleBlock
            visible: xb.hasMain
            Layout.fillWidth: true
            spacing: -2
            DiCascade { target: titleBlock; index: 0 }

            StyledText {
                Layout.fillWidth: true
                text: xb.name
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: xb.busy ? Translation.tr("Connecting…")
                    : xb.lowBattery ? Translation.tr("Low battery · charge it in the case")
                    : xb.connected ? Translation.tr("Connected") : Translation.tr("Disconnected")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: xb.lowBattery ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                opacity: xb.lowBattery ? 1 : 0.6
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: heroRow
            visible: xb.hasMain
            Layout.topMargin: 10
            spacing: 14
            DiCascade { target: heroRow; index: 1 }

            Item {
                implicitWidth: 88
                implicitHeight: 88

                CircularProgress {
                    anchors.fill: parent
                    implicitSize: 88
                    lineWidth: 6
                    enableAnimation: false
                    value: Math.max(0, xb.battery) * ringReveal.value
                    colPrimary: xb.accent
                    colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88)

                    Behavior on colPrimary {
                        ColorAnimation { duration: IslandMotion.short }
                    }
                }

                Loader {
                    id: caseLoader
                    active: xb.caseArt
                    visible: status === Loader.Ready
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    source: Qt.resolvedUrl("DiEarbudsCase.qml")
                    onLoaded: {
                        item.open = Qt.binding(() => xb.connected)
                        item.busy = Qt.binding(() => xb.busy)
                    }
                }

                MaterialSymbol {
                    visible: caseLoader.status !== Loader.Ready
                    anchors.centerIn: parent
                    text: IslandEvents.bluetoothSymbol(xb.icon)
                    iconSize: 34
                    fill: 1
                    color: xb.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: xb.battery >= 0 ? Math.round(xb.battery * 100 * ringReveal.value) : "–"
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: xb.lowBattery ? Appearance.colors.colError : Appearance.colors.colOnLayer0

                    StyledText {
                        visible: xb.battery >= 0
                        anchors {
                            left: parent.right
                            leftMargin: 2
                            baseline: parent.baseline
                        }
                        text: "%"
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        color: parent.color
                        opacity: 0.6
                    }
                }
                StyledText {
                    Layout.topMargin: -4
                    text: xb.battery >= 0 ? Translation.tr("Battery") : Translation.tr("No battery info")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.6
                }

                Repeater {
                    model: xb.parts.length > 1 ? xb.parts.length : 0
                    delegate: RowLayout {
                        id: partRow
                        required property int index
                        readonly property var part: xb.parts[partRow.index]
                        Layout.topMargin: partRow.index === 0 ? 6 : 1
                        spacing: 6

                        StyledText {
                            Layout.preferredWidth: 30
                            text: partRow.part?.label ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                        LevelBar {
                            implicitWidth: 44
                            level: partRow.part?.value ?? 0
                            tint: (partRow.part?.value ?? 1) <= 0.2 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: xb.percent(partRow.part?.value ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.75
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: !xb.hasMain
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            Item { Layout.fillHeight: true }
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "headphones"
                iconSize: 30
                color: Appearance.colors.colOnLayer0
                opacity: 0.35
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No headphones connected")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 220
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Open the case near the computer to connect")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
                wrapMode: Text.Wrap
            }
            Item { Layout.fillHeight: true }
        }

        Item {
            visible: xb.hasMain
            Layout.fillHeight: true
            Layout.minimumHeight: 10
        }

        RowLayout {
            id: chipsRow
            visible: xb.hasMain && xb.connected
            Layout.fillWidth: true
            spacing: 6
            DiCascade { target: chipsRow; index: 2 }

            Chip {
                icon: xb.isOutput ? "headphones" : "speaker"
                value: xb.isOutput ? Translation.tr("This device") : (xb.sinkName || "–")
                label: Translation.tr("Audio output")
            }
            Chip {
                icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                value: (Audio.sink?.audio?.muted ?? false) ? Translation.tr("Muted") : xb.percent(Audio.value)
                label: Translation.tr("Volume")
                meter: (Audio.sink?.audio?.muted ?? false) ? 0 : Audio.value
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        SectionLabel {
            id: othersLabel
            text: Translation.tr("Other devices")
            DiCascade { target: othersLabel; index: 3 }
        }

        Repeater {
            model: xb.others.length
            delegate: Rectangle {
                id: row
                required property int index
                readonly property var d: xb.others[row.index]
                readonly property bool on: !!BluetoothStatus.isConnected(row.d)
                readonly property bool connecting: row.d?.state === BluetoothDeviceState.Connecting
                readonly property real level: BluetoothStatus.hasBattery(row.d) ? Number(row.d.battery) : -1
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 12
                color: rowMouse.containsMouse && !row.on ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                DiCascade { target: row; index: 4 + row.index; pressed: rowMouse.pressed && !row.on }

                Behavior on color {
                    ColorAnimation { duration: IslandMotion.micro }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    MaterialSymbol {
                        text: IslandEvents.bluetoothSymbol(row.d?.icon)
                        iconSize: 16
                        fill: 1
                        color: row.on ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        opacity: row.on ? 1 : 0.5
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: IslandEvents.shortName(row.d?.name || row.d?.deviceName || "")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        opacity: row.on ? 1 : 0.7
                        elide: Text.ElideRight
                    }
                    LevelBar {
                        visible: row.on && row.level >= 0
                        level: row.level
                        tint: row.level <= 0.2 ? Appearance.colors.colError : Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: row.on ? (row.level >= 0 ? xb.percent(row.level) : Translation.tr("Connected"))
                            : row.connecting ? Translation.tr("Connecting…") : Translation.tr("Tap to connect")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer1
                        opacity: row.on && row.level >= 0 ? 0.8 : 0.55
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !row.on && !row.connecting
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.d?.connect()
                }
            }
        }

        ColumnLayout {
            id: othersEmpty
            visible: xb.others.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            DiCascade { target: othersEmpty; index: 4 }

            Item { Layout.fillHeight: true }
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "devices_other"
                iconSize: 30
                color: Appearance.colors.colOnLayer0
                opacity: 0.35
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No other devices")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Pair one in the Bluetooth settings")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }
            Item { Layout.fillHeight: true }
        }

        Item {
            visible: xb.others.length > 0
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Action {
                order: 7
                icon: "link_off"
                text: Translation.tr("Disconnect")
                available: xb.device !== null && xb.connected
                onTapped: {
                    xb.device.disconnect()
                    xb.di.collapse()
                }
            }
            Action {
                order: 8
                icon: "settings_bluetooth"
                text: Translation.tr("Settings")
                onTapped: {
                    Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth])
                    xb.di.collapse()
                }
            }
        }
    }
}
