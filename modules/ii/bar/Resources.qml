import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcherArea {
    Component.onCompleted: ResourceUsage.consumers++
    Component.onDestruction: ResourceUsage.consumers--
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool alwaysShowAllResources: false
    horizontalExtraPadding: 12

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    rowDefault: Component {
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory"
                label: "RAM"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                label: "CPU"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                label: "TMP"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                label: "DSK"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                label: "SWP"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory"
                label: "RAM"
                shown: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                label: "CPU"
                shown: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                label: "TMP"
                shown: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                label: "DSK"
                shown: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                label: "SWP"
                shown: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
        }
    }

    colDefault: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                label: "RAM"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                label: "CPU"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                label: "TMP"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                label: "DSK"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                label: "SWP"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            spacing: 7
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "memory"
                label: "RAM"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: Config.options.bar.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                label: "CPU"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                label: "TMP"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                label: "DSK"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                label: "SWP"
                vertical: true
                visible: Config.options.bar.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: Config.options.bar.resources.swapWarningThreshold
            }
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}