pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcher {
    id: root

    readonly property bool isRunning: Docker.runningCount > 0
    readonly property bool hasUnhealthy: Docker.unhealthyCount > 0

    horizontalExtraPadding: 8

    rowDefault: Component {
        RowLayout {
            spacing: 6
            MaterialSymbol {
                text: "deployed_code"
                iconSize: Appearance.font.pixelSize.medium
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
            }

            StyledText {
                text: "" + Docker.runningCount
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 6
            MaterialSymbol {
                text: "deployed_code"
                iconSize: Appearance.font.pixelSize.medium
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface)
            }

            StyledText {
                text: "" + Docker.runningCount
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface)
            }
        }
    }

    colDefault: Component {
        ColumnLayout {
            spacing: 2
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "deployed_code"
                iconSize: Appearance.font.pixelSize.medium
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "" + Docker.runningCount
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            spacing: 2
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "deployed_code"
                iconSize: Appearance.font.pixelSize.medium
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface)
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "" + Docker.runningCount
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: root.hasUnhealthy 
                    ? Appearance.colors.colError 
                    : (root.isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Docker.popupVisible = !Docker.popupVisible;
        }

        StyledToolTip {
            extraVisibleCondition: mouseArea.containsMouse
            alternativeVisibleCondition: mouseArea.containsMouse
            text: Docker.runningCount + " running containers (Click or SUPER+Shift+D)"
        }
    }
}
