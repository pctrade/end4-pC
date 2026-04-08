import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function usageColor(value) {
        if (value > 0.9) return Appearance.colors.colError
        if (value > 0.6) return Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    Column {
        spacing: 8
        width: 280

        // RAM
        Rectangle {
            width: parent.width
            height: 72
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Row {
                anchors { fill: parent; margins: 12 }
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    shape: MaterialShape.Shape.Pentagon
                    text: "memory"
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 40
                    color: Qt.alpha(root.usageColor(ResourceUsage.memoryUsed / ResourceUsage.memoryTotal), 0.2)
                    colSymbol: root.usageColor(ResourceUsage.memoryUsed / ResourceUsage.memoryTotal)
                }

                Column {
                    width: parent.width - 40 - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    RowLayout {
                        width: parent.width

                        StyledText {
                            text: "RAM"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }

                        StyledText {
                            id: ramPct
                            text: `${Math.round(ResourceUsage.memoryUsed / ResourceUsage.memoryTotal * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: root.usageColor(ResourceUsage.memoryUsed / ResourceUsage.memoryTotal)
                        }
                    }

                    StyledProgressBar {
                        width: parent.width
                        value: ResourceUsage.memoryUsed / ResourceUsage.memoryTotal
                        highlightColor: root.usageColor(ResourceUsage.memoryUsed / ResourceUsage.memoryTotal)
                        valueBarHeight: 6
                    }

                    StyledText {
                        text: root.formatKB(ResourceUsage.memoryUsed) + " / " + root.formatKB(ResourceUsage.memoryTotal)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // CPU
        Rectangle {
            width: parent.width
            height: 72
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Row {
                anchors { fill: parent; margins: 12 }
                spacing: 12

                MaterialShapeWrappedMaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    shape: MaterialShape.Shape.Gem
                    text: "planner_review"
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 40
                    color: Qt.alpha(root.usageColor(ResourceUsage.cpuUsage), 0.2)
                    colSymbol: root.usageColor(ResourceUsage.cpuUsage)
                }

                Column {
                    width: parent.width - 40 - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    RowLayout {
                        width: parent.width

                        StyledText {
                            text: "CPU"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }

                        StyledText {
                            id: cpuPct
                            text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: root.usageColor(ResourceUsage.cpuUsage)
                        }
                    }

                    StyledProgressBar {
                        width: parent.width
                        value: ResourceUsage.cpuUsage
                        highlightColor: root.usageColor(ResourceUsage.cpuUsage)
                        valueBarHeight: 6
                    }

                    StyledText {
                        font.features: { "tnum": 1 }
                        text: `${Math.round(ResourceUsage.cpuTemp)}°C`
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: ResourceUsage.cpuTemp > 80 ? Appearance.colors.colError 
                            : ResourceUsage.cpuTemp > 60 ? Appearance.m3colors.m3tertiary 
                            : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}