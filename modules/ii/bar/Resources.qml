import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcherArea {
    id: root
    property bool alwaysShowAllResources: false
    horizontalExtraPadding: 12

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    rowDefault: Component {
        RowLayout {
            spacing: 0
            Resource {
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                iconName: "planner_review"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "hard_drive"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "swap_horiz"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                iconName: "monitor"
                shown: Config.options.bar.resources.alwaysShowGpu
                percentage: ResourceUsage.gpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.gpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowGpuTemp
                percentage: ResourceUsage.gpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowVram
                percentage: ResourceUsage.vramUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.vramWarningThreshold
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 0
            Resource {
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                iconName: "planner_review"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "hard_drive"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "swap_horiz"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                iconName: "monitor"
                shown: Config.options.bar.resources.alwaysShowGpu
                percentage: ResourceUsage.gpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.gpuWarningThreshold
            }
            Resource {
                iconName: "thermostat"
                shown: Config.options.bar.resources.alwaysShowGpuTemp
                percentage: ResourceUsage.gpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                iconName: "memory"
                shown: Config.options.bar.resources.alwaysShowVram
                percentage: ResourceUsage.vramUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.vramWarningThreshold
            }
        }
    }

    colDefault: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "monitor"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpu
                percentage: ResourceUsage.gpuUsage
                warningThreshold: Config.options.bar.resources.gpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpuTemp
                percentage: ResourceUsage.gpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowVram
                percentage: ResourceUsage.vramUsedPercentage
                warningThreshold: Config.options.bar.resources.vramWarningThreshold
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "monitor"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpu
                percentage: ResourceUsage.gpuUsage
                warningThreshold: Config.options.bar.resources.gpuWarningThreshold
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowGpuTemp
                percentage: ResourceUsage.gpuTemp / 100
            }
            Resource {
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowVram
                percentage: ResourceUsage.vramUsedPercentage
                warningThreshold: Config.options.bar.resources.vramWarningThreshold
            }
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}