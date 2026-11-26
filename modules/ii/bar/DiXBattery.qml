import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xbat
    required property Item di
    spacing: 12
    implicitWidth: xbat.wantedWidth
    readonly property real wantedWidth: 532

    readonly property bool onBattery: !Battery.isPluggedIn

    readonly property color accent: Battery.isCharging ? Appearance.m3colors.m3success
        : Battery.percentage <= 0.2 ? Appearance.colors.colError : Appearance.colors.colPrimary

    // The laptop's own battery (the display device is an aggregate and has no health)
    readonly property var cell: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    readonly property real healthPct: Battery.health > 0.5 ? Battery.health : 0
    readonly property real capacityWh: xbat.cell?.energyCapacity ?? 0
    readonly property real designWh: xbat.healthPct > 0 && xbat.capacityWh > 0 ? xbat.capacityWh / (xbat.healthPct / 100) : 0
    readonly property real watts: Math.abs(Battery.energyRate)
    readonly property bool slowCharger: Battery.isCharging && xbat.watts > 0.5 && xbat.watts < IslandHardware.slowChargerWatts
        && Battery.percentage < 0.95

    readonly property var profiles: [
        { key: "power-saver", icon: "eco", label: Translation.tr("Saver") },
        { key: "balanced", icon: "balance", label: Translation.tr("Balanced") },
        { key: "performance", icon: "speed", label: Translation.tr("Performance") }
    ]

    Component.onCompleted: IslandHardware.refreshPower()

    DiSpring {
        id: ringBuild
        stiffness: 50
        dampingRatio: 1
        epsilon: 0.002
    }
    Timer {
        interval: 180
        running: true
        onTriggered: ringBuild.target = 1
    }

    component SectionLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string value: ""
        property string label: ""
        property color iconColor: Appearance.colors.colPrimary
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        radius: 12
        color: Appearance.colors.colLayer1

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
                color: chip.iconColor
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

    function fullAtText() {
        if (Battery.isFull || Battery.percentage >= 0.995) return Translation.tr("Full")
        if (!Battery.isCharging) return Translation.tr("Paused")
        if (Battery.timeToFull <= 60) return "…"
        return Qt.formatTime(new Date(Date.now() + Battery.timeToFull * 1000), "hh:mm")
    }
    function fullAtLabel() {
        if (Battery.isFull || Battery.percentage >= 0.995) return Translation.tr("Charged")
        if (!Battery.isCharging) return Translation.tr("Not charging")
        if (Battery.timeToFull <= 60) return Translation.tr("Estimating")
        return `${Translation.tr("Full in")} ${xbat.di.formatDuration(Battery.timeToFull)}`
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 10

            RowLayout {
                id: chargeRow
                Layout.fillWidth: true
                spacing: 16
                DiCascade { target: chargeRow; index: 0 }

                Item {
                    implicitWidth: 76
                    implicitHeight: 76

                    CircularProgress {
                        anchors.fill: parent
                        implicitSize: 76
                        lineWidth: 6
                        enableAnimation: false
                        value: Battery.percentage * ringBuild.value
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
                        text: `${Math.round(Battery.percentage * 100 * ringBuild.value)}%`
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Battery.isCharging
                            ? (Battery.timeToFull > 60 ? `${Translation.tr("Full in")} ${xbat.di.formatDuration(Battery.timeToFull)}` : Translation.tr("Charging"))
                            : Battery.isPluggedIn ? Translation.tr("Plugged in")
                            : (Battery.timeToEmpty > 60 ? `${xbat.di.formatDuration(Battery.timeToEmpty)} ${Translation.tr("left")}` : Translation.tr("On battery"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                id: speedRow
                Layout.fillWidth: true
                visible: !xbat.onBattery
                spacing: 8
                DiCascade { target: speedRow; index: 1 }

                Chip {
                    icon: xbat.slowCharger ? "hourglass_bottom" : "bolt"
                    iconColor: xbat.slowCharger ? Appearance.colors.colError : Appearance.m3colors.m3success
                    value: Battery.isCharging && xbat.watts > 0.5 ? `${xbat.watts.toFixed(xbat.watts < 10 ? 1 : 0)} W` : "0 W"
                    label: !Battery.isCharging ? Translation.tr("Idle")
                        : xbat.slowCharger ? Translation.tr("Slow charger") : Translation.tr("Charging speed")
                }
                Chip {
                    icon: "schedule"
                    value: xbat.fullAtText()
                    label: xbat.fullAtLabel()
                }
            }

            Rectangle {
                id: healthCard
                Layout.fillWidth: true
                visible: !xbat.onBattery
                implicitHeight: 48
                radius: 12
                color: Appearance.colors.colLayer1
                DiCascade { target: healthCard; index: 2 }

                ColumnLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 7
                        bottomMargin: 8
                    }
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialSymbol {
                            text: "health_and_safety"
                            iconSize: 16
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: xbat.healthPct > 0 ? `${Translation.tr("Health")} ${Math.round(xbat.healthPct)}%` : Translation.tr("Health")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: {
                                const parts = []
                                if (xbat.designWh > 0) parts.push(`${xbat.capacityWh.toFixed(1)} / ${xbat.designWh.toFixed(1)} Wh`)
                                else if (xbat.capacityWh > 0) parts.push(`${xbat.capacityWh.toFixed(1)} Wh`)
                                if (Battery.chargeCycles > 0) parts.push(`${Battery.chargeCycles} ${Translation.tr("cycles")}`)
                                return parts.length > 0 ? parts.join(" · ") : Translation.tr("Not reported")
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            radius: 3
                            width: parent.width * Math.min(1, xbat.healthPct / 100) * ringBuild.value
                            color: xbat.healthPct > 0 && xbat.healthPct < 60 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        }
                    }
                }
            }

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
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 8

            SectionLabel {
                visible: xbat.onBattery
                text: Translation.tr("Using the most right now")
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

            SectionLabel {
                id: modeLabel
                visible: !xbat.onBattery
                text: Translation.tr("Power mode")
                DiCascade { target: modeLabel; index: 1 }
            }

            Rectangle {
                id: modeSwitch
                Layout.fillWidth: true
                visible: !xbat.onBattery
                implicitHeight: 40
                radius: 12
                color: Appearance.colors.colLayer1
                DiCascade { target: modeSwitch; index: 2 }

                readonly property int selected: Math.max(0, xbat.profiles.findIndex(p => p.key === IslandHardware.powerProfile))
                readonly property real segment: (modeSwitch.width - 8) / xbat.profiles.length

                DiSpring {
                    id: modeSlide
                    target: modeSwitch.selected
                    stiffness: 380
                    dampingRatio: 0.8
                    epsilon: 0.002
                }

                Rectangle {
                    x: 4 + modeSlide.value * modeSwitch.segment
                    y: 4
                    width: modeSwitch.segment
                    height: modeSwitch.height - 8
                    radius: 9
                    color: Appearance.colors.colPrimary
                }

                Row {
                    x: 4
                    y: 4
                    Repeater {
                        model: xbat.profiles.length
                        delegate: Item {
                            id: seg
                            required property int index
                            readonly property var d: xbat.profiles[index]
                            readonly property bool active: modeSwitch.selected === seg.index
                            width: modeSwitch.segment
                            height: modeSwitch.height - 8

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: !seg.active && segMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"
                                Behavior on color {
                                    ColorAnimation { duration: IslandMotion.micro }
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: seg.d.icon
                                    iconSize: 16
                                    fill: seg.active ? 1 : 0
                                    color: seg.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: seg.active || modeSwitch.segment > 96
                                    text: seg.d.label
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.DemiBold
                                    color: seg.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                }
                            }

                            MouseArea {
                                id: segMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!seg.active) IslandHardware.setPowerProfile(seg.d.key)
                            }
                        }
                    }
                }
            }

            StyledText {
                id: modeHint
                Layout.fillWidth: true
                visible: !xbat.onBattery
                text: IslandHardware.powerProfile === "power-saver" ? Translation.tr("Longer battery, lower speed")
                    : IslandHardware.powerProfile === "performance" ? Translation.tr("Full speed, more heat and fan noise")
                    : Translation.tr("Speed and battery in balance")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.55
                elide: Text.ElideRight
                DiCascade { target: modeHint; index: 3 }
            }

            SectionLabel {
                id: devicesLabel
                visible: !xbat.onBattery
                Layout.topMargin: 4
                text: Translation.tr("Devices")
                DiCascade { target: devicesLabel; index: 4 }
            }

            Repeater {
                model: xbat.onBattery ? 0 : Math.min(3, IslandHardware.peripherals.length)
                delegate: Rectangle {
                    id: device
                    required property int index
                    readonly property var d: IslandHardware.peripherals[index] ?? ({})
                    readonly property real level: Math.max(0, Math.min(1, Number(device.d.level) || 0))
                    readonly property color tone: device.level <= 0.15 ? Appearance.colors.colError : Appearance.colors.colPrimary
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 12
                    color: Appearance.colors.colLayer1
                    clip: true
                    DiCascade { target: device; index: 5 + device.index }

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: parent.width * device.level * ringBuild.value
                        color: ColorUtils.transparentize(device.tone, 0.86)
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8
                        MaterialSymbol {
                            text: device.d.icon ?? "devices_other"
                            iconSize: 16
                            fill: 1
                            color: device.tone
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: device.d.name ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        MaterialSymbol {
                            visible: device.d.charging ?? false
                            text: "bolt"
                            iconSize: 14
                            fill: 1
                            color: Appearance.m3colors.m3success
                        }
                        StyledText {
                            text: `${Math.round(device.level * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            Item {
                id: noDevices
                Layout.fillWidth: true
                visible: !xbat.onBattery && IslandHardware.peripherals.length === 0
                implicitHeight: 64
                DiCascade { target: noDevices; index: 5 }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "devices_other"
                        iconSize: 24
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.35
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No other batteries")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Headphones, mice and keyboards show up here")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.55
                    }
                }
            }
        }
    }
}
