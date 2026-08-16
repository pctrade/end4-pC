pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

MouseArea {
    id: root

    property bool vertical: false
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property bool hasUsage: CodexUsageService.available
    readonly property int remainingPercent: CodexUsageService.weeklyRemainingPercent
    readonly property color accentColor: !root.hasUsage
        ? Appearance.colors.colOnLayer1
        : root.remainingPercent <= 10
            ? Appearance.m3colors.m3error
            : root.remainingPercent <= 25
                ? Appearance.colors.colTertiary
                : (root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)
    readonly property string displayText: CodexUsageService.loading
        ? "..."
        : root.hasUsage
            ? `${root.remainingPercent}%`
            : "--"

    implicitWidth: root.vertical
        ? Appearance.sizes.verticalBarWidth
        : (contentLoader.item?.implicitWidth ?? 0) + 8
    implicitHeight: root.vertical
        ? (contentLoader.item?.implicitHeight ?? 0)
        : Appearance.sizes.barHeight

    acceptedButtons: Qt.LeftButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onClicked: Quickshell.execDetached(["xdg-open", "https://chatgpt.com/codex/settings/usage"])

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        RowLayout {
            spacing: 4

            CustomIcon {
                width: Appearance.font.pixelSize.normal
                height: Appearance.font.pixelSize.normal
                source: "openai-symbolic"
                colorize: true
                color: root.accentColor
            }

            StyledText {
                text: root.displayText
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
                color: root.accentColor
            }
        }
    }

    Component {
        id: verticalContent

        ColumnLayout {
            spacing: 1

            CustomIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Appearance.font.pixelSize.normal
                Layout.preferredHeight: Appearance.font.pixelSize.normal
                source: "openai-symbolic"
                colorize: true
                color: root.accentColor
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.displayText
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
                color: root.accentColor
            }
        }
    }

    StyledPopup {
        id: usagePopup
        hoverTarget: root

        ColumnLayout {
            implicitWidth: 250
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                MaterialShape {
                    implicitSize: 36
                    color: Appearance.colors.colPrimaryContainer
                    shape: MaterialShape.Shape.Circle

                    CustomIcon {
                        anchors.centerIn: parent
                        width: Appearance.font.pixelSize.large
                        height: Appearance.font.pixelSize.large
                        source: "openai-symbolic"
                        colorize: true
                        color: Appearance.colors.colPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        text: Translation.tr("Codex weekly usage")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        text: CodexUsageService.planType.length > 0
                            ? CodexUsageService.planType
                            : Translation.tr("ChatGPT account")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                        opacity: 0.6
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: CodexUsageService.available
                    ? `${CodexUsageService.weeklyRemainingPercent}% ${Translation.tr("remaining")}`
                    : CodexUsageService.loading
                        ? Translation.tr("Loading usage…")
                        : (CodexUsageService.error || Translation.tr("Usage unavailable"))
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: root.accentColor
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Appearance.colors.colSurfaceContainerHighest

                Rectangle {
                    width: parent.width * (CodexUsageService.available
                        ? CodexUsageService.weeklyRemainingPercent / 100
                        : 0)
                    height: parent.height
                    radius: parent.radius
                    color: root.accentColor
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: Translation.tr("Resets")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.65
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: CodexUsageService.resetText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

        }
    }
}
