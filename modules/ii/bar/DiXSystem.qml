import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: xs
    required property Item di
    spacing: 10
    implicitWidth: 380
    // Layouts overwrite implicitWidth with their children's; the container reads this instead
    readonly property real wantedWidth: 380

    // Temperature, fan and power profile are only measured often while this panel is the one you are looking at
    Binding {
        target: IslandHardware
        property: "powerWatch"
        value: true
        restoreMode: Binding.RestoreValue
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "memory"
            iconSize: 20
            fill: 1
            color: Pressure.cpuHigh ? Appearance.colors.colError : Appearance.colors.colPrimary
        }
        StyledText {
            Layout.fillWidth: true
            text: Pressure.cpuHigh ? Translation.tr("High CPU usage") : Translation.tr("System")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
        }
    }

    DiSparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        values: ResourceUsage.cpuUsageHistory
        points: ResourceUsage.historyLength
        color: ResourceUsage.cpuUsage >= 0.9 ? Appearance.colors.colError : Appearance.colors.colPrimary
        threshold: Pressure.cpuThreshold
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            text: IslandEvents.topProcess !== "" ? `${IslandEvents.topProcess} · ${Math.round(IslandEvents.topProcessCpu)}%` : ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            opacity: 0.8
            elide: Text.ElideRight
        }
        StyledText {
            text: `RAM ${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.8
        }
    }

    // Temperature, and a way out of it: the power profile is what actually brings the fan down
    Rectangle {
        Layout.fillWidth: true
        visible: IslandHardware.temperature > 0
        implicitHeight: 46
        radius: 12
        color: IslandHardware.temperatureHot ? ColorUtils.transparentize(IslandEvents.colorAttention, 0.85) : Appearance.colors.colLayer1

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 8
            }
            spacing: 8

            MaterialSymbol {
                text: IslandHardware.temperatureHot ? "local_fire_department" : "device_thermostat"
                iconSize: 18
                fill: 1
                color: IslandHardware.temperatureHot ? IslandEvents.colorAttention : Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: -3

                StyledText {
                    Layout.fillWidth: true
                    text: `${Math.round(IslandHardware.temperature)} °C${IslandHardware.fanRpm > 0 ? ` · ${IslandHardware.fanRpm} RPM` : ""}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: IslandHardware.temperatureHot && IslandEvents.topProcess !== ""
                        ? Translation.tr("Hot · %1 is the heaviest").arg(IslandEvents.topProcess)
                        : Translation.tr("Power profile: %1").arg(IslandHardware.powerProfileName)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: [
                    { profile: "power-saver", icon: "eco" },
                    { profile: "balanced", icon: "balance" },
                    { profile: "performance", icon: "bolt" }
                ]
                delegate: Rectangle {
                    id: profileButton
                    required property var modelData
                    readonly property bool current: IslandHardware.powerProfile === modelData.profile
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: profileButton.current ? Appearance.colors.colPrimary
                        : (profileMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: profileButton.modelData.icon
                        iconSize: 15
                        fill: 1
                        color: profileButton.current ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }

                    MouseArea {
                        id: profileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandHardware.setPowerProfile(profileButton.modelData.profile)
                    }
                }
            }
        }
    }

    // The heaviest processes right now (scanned only while this panel is open), with a way to end them
    StyledText {
        text: Translation.tr("Processes")
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    DiProcessList {
        Layout.fillWidth: true
        kind: "cpu"
        visibleRows: 4
        fadeColor: xs.di.surfaceColor
    }

    // Every other battery in the house: earbuds, mouse, keyboard, controller
    StyledText {
        visible: IslandHardware.peripherals.length > 0
        text: Translation.tr("Peripherals")
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer0
        opacity: 0.6
    }

    Repeater {
        model: IslandHardware.peripherals

        delegate: RowLayout {
            id: peripheralRow
            required property var modelData
            readonly property bool low: peripheralRow.modelData.level <= 0.2
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: peripheralRow.modelData.icon
                iconSize: 17
                fill: 1
                color: peripheralRow.low ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                opacity: peripheralRow.low ? 1 : 0.8
            }
            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: peripheralRow.modelData.name
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            MaterialSymbol {
                visible: peripheralRow.modelData.charging
                text: "bolt"
                iconSize: 13
                fill: 1
                color: IslandEvents.colorSuccess
            }
            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 5
                radius: 2.5
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, peripheralRow.modelData.level))
                    height: parent.height
                    radius: 2.5
                    color: peripheralRow.low ? Appearance.colors.colError : Appearance.colors.colPrimary
                }
            }
            StyledText {
                text: `${Math.round(peripheralRow.modelData.level * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: peripheralRow.low ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                opacity: peripheralRow.low ? 1 : 0.8
            }
        }
    }
}
