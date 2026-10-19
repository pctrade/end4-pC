import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import QtQuick.Layouts

BarWidgetSwitcherArea {
    Component.onCompleted: ResourceUsage.consumers++
    Component.onDestruction: ResourceUsage.consumers--
    id: root
    readonly property string barScreenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var barConfig: Config.barForScreen(root.barScreenName)
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool alwaysShowAllResources: false
    horizontalExtraPadding: 12

    hoverEnabled: !root.barConfig.tooltips.clickToShow

    rowDefault: Component {
        RowLayout {
            spacing: 0
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "memory"
                label: "RAM"
                shown: root.barConfig.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: root.barConfig.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                label: "CPU"
                shown: root.barConfig.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: root.barConfig.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                label: "TMP"
                shown: root.barConfig.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                label: "DSK"
                shown: root.barConfig.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                label: "SWP"
                shown: root.barConfig.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: root.barConfig.resources.swapWarningThreshold
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
                shown: root.barConfig.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: root.barConfig.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "planner_review"
                label: "CPU"
                shown: root.barConfig.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: root.barConfig.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "thermostat"
                label: "TMP"
                shown: root.barConfig.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "hard_drive"
                label: "DSK"
                shown: root.barConfig.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                iconName: "swap_horiz"
                label: "SWP"
                shown: root.barConfig.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                Layout.leftMargin: shown ? 6 : 0
                warningThreshold: root.barConfig.resources.swapWarningThreshold
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
                visible: root.barConfig.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: root.barConfig.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                label: "CPU"
                vertical: true
                visible: root.barConfig.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: root.barConfig.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                label: "TMP"
                vertical: true
                visible: root.barConfig.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                label: "DSK"
                vertical: true
                visible: root.barConfig.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                label: "SWP"
                vertical: true
                visible: root.barConfig.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: root.barConfig.resources.swapWarningThreshold
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
                visible: root.barConfig.resources.alwaysShowRam
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: root.barConfig.resources.memoryWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "planner_review"
                label: "CPU"
                vertical: true
                visible: root.barConfig.resources.alwaysShowCpu
                percentage: ResourceUsage.cpuUsage
                warningThreshold: root.barConfig.resources.cpuWarningThreshold
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "thermostat"
                label: "TMP"
                vertical: true
                visible: root.barConfig.resources.alwaysShowCpuTemp
                percentage: ResourceUsage.cpuTemp / 100
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "hard_drive"
                label: "DSK"
                vertical: true
                visible: root.barConfig.resources.alwaysShowDisk
                percentage: ResourceUsage.diskUsedPercentage
            }
            Resource {
                contentColor: root.contentColor
                contentColorOverridden: root.contentColorOverridden
                Layout.alignment: Qt.AlignHCenter
                iconName: "swap_horiz"
                label: "SWP"
                vertical: true
                visible: root.barConfig.resources.alwaysShowSwap
                percentage: ResourceUsage.swapUsedPercentage
                warningThreshold: root.barConfig.resources.swapWarningThreshold
            }
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}