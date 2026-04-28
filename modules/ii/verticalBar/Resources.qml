import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar as Bar

MouseArea {
    id: root
    property bool alwaysShowAllResources: false
    implicitHeight: columnLayout.implicitHeight + 20
    implicitWidth: columnLayout.implicitWidth
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    ColumnLayout {
        id: columnLayout
        spacing: 5
        anchors.fill: parent

        Resource {
			Layout.alignment: Qt.AlignHCenter
			iconName: "memory"
			visible: Config.options.bar.resources.alwaysShowRam
			percentage: ResourceUsage.memoryUsedPercentage
			warningThreshold: Config.options.bar.resources.memoryWarningThreshold
		}
		Resource {
			Layout.alignment: Qt.AlignHCenter
			visible: Config.options.bar.resources.alwaysShowCpu
			iconName: "planner_review"
			percentage: ResourceUsage.cpuUsage
			warningThreshold: Config.options.bar.resources.cpuWarningThreshold
		}
		Resource {
			Layout.alignment: Qt.AlignHCenter
			iconName: "thermostat"
			visible: Config.options.bar.resources.alwaysShowCpuTemp
			percentage: ResourceUsage.cpuTemp / 100
		}
		Resource {
			Layout.alignment: Qt.AlignHCenter
			iconName: "hard_drive"
			visible: Config.options.bar.resources.alwaysShowDisk
			percentage: ResourceUsage.diskUsedPercentage
		}
		Resource {
			Layout.alignment: Qt.AlignHCenter
			iconName: "swap_horiz"
			visible: Config.options.bar.resources.alwaysShowSwap
			percentage: ResourceUsage.swapUsedPercentage
			warningThreshold: Config.options.bar.resources.swapWarningThreshold
		}
    }

    Bar.ResourcesPopup {
        hoverTarget: root
    }
}
