import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: false
    property bool alwaysShowAllResources: false

    implicitWidth:  vertical ? columnLayout.implicitWidth  : rowLayout.implicitWidth + 4
    implicitHeight: vertical ? columnLayout.implicitHeight + 20 : Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // Horizontal Layout
    RowLayout {
        id: rowLayout
        visible: !root.vertical
        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 4

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
    }

    // Vertical Layout
    ColumnLayout {
        id: columnLayout
        visible: root.vertical
        spacing: 5
        anchors.fill: parent

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
    }

    ResourcesPopup {
        hoverTarget: root
    }
}