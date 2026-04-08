import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Io

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    Row {
        spacing: 5

        Column {
            spacing: 5

            ResourceCard {
                label: "RAM"
                iconText: "memory"
                iconShape: MaterialShape.Shape.Clover4Leaf
                value: ResourceUsage.memoryUsed / ResourceUsage.memoryTotal
                sublabel: root.formatKB(ResourceUsage.memoryUsed) + " / " + root.formatKB(ResourceUsage.memoryTotal)
            }

            ResourceCard {
                label: "CPU"
                iconText: "planner_review"
                iconShape: MaterialShape.Shape.Gem
                value: ResourceUsage.cpuUsage
                sublabel: `${Math.round(ResourceUsage.cpuTemp)}°C`
                sublabelColor: ResourceUsage.cpuTemp > 80 ? Appearance.colors.colError
                    : ResourceUsage.cpuTemp > 60 ? Appearance.m3colors.m3tertiary
                    : Appearance.colors.colOnLayer1
            }
        }

        Column {
            spacing: 5

            ResourceCard {
                label: "Swap"
                iconText: "swap_horiz"
                iconShape: MaterialShape.Shape.Bun
                value: ResourceUsage.swapUsedPercentage
                sublabel: root.formatKB(ResourceUsage.swapUsed) + " / " + root.formatKB(ResourceUsage.swapTotal)
            }

            ResourceCard {
                label: "Disk"
                iconText: "hard_drive"
                iconShape: MaterialShape.Shape.Circle
                value: ResourceUsage.diskUsedPercentage
                sublabel: root.formatKB(ResourceUsage.diskUsed) + " / " + root.formatKB(ResourceUsage.diskTotal)
            }
        }
    }
}