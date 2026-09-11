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

    readonly property var providers: UsageProviders.activeProviders
    readonly property int availableProviderCount: providers.filter(provider => provider.service.available).length
    readonly property int overallRemainingPercent: {
        const available = providers
            .filter(provider => provider.service.available)
            .map(provider => provider.service.remainingPercent)
        return available.length > 0 ? Math.min(...available) : -1
    }
    readonly property color usageColor: root.isMaterial
        ? Appearance.colors.colPrimary
        : Appearance.colors.colOnLayer1
    readonly property color overallColor: UsageDisplay.colorForRemaining(
        root.overallRemainingPercent,
        root.usageColor,
        Appearance.colors.colOnLayer1,
    )

    visible: root.providers.length > 0
    implicitWidth: !root.visible
        ? 0
        : root.vertical
            ? Appearance.sizes.verticalBarWidth
            : (contentLoader.item?.implicitWidth ?? 0) + 8
    implicitHeight: !root.visible
        ? 0
        : root.vertical
            ? (contentLoader.item?.implicitHeight ?? 0)
            : Appearance.sizes.barHeight

    acceptedButtons: Qt.LeftButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    function providerText(provider) {
        const service = provider.service
        return UsageDisplay.usageText(
            service.available,
            service.loading,
            service.remainingPercent,
        )
    }

    function providerColor(provider) {
        return UsageDisplay.colorForRemaining(
            provider.service.available ? provider.service.remainingPercent : -1,
            root.usageColor,
            Appearance.colors.colOnLayer1,
        )
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        RowLayout {
            spacing: 7

            Repeater {
                model: root.providers

                delegate: RowLayout {
                    required property var modelData
                    spacing: 3

                    CustomIcon {
                        Layout.preferredWidth: Appearance.font.pixelSize.normal
                        Layout.preferredHeight: Appearance.font.pixelSize.normal
                        source: modelData.icon
                        colorize: true
                        smooth: true
                        color: root.providerColor(modelData)
                    }

                    StyledText {
                        text: root.providerText(modelData)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: root.providerColor(modelData)
                    }
                }
            }
        }
    }

    Component {
        id: verticalContent

        ColumnLayout {
            spacing: 3

            Repeater {
                model: root.providers

                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 1

                    CustomIcon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Appearance.font.pixelSize.normal
                        Layout.preferredHeight: Appearance.font.pixelSize.normal
                        source: modelData.icon
                        colorize: true
                        smooth: true
                        color: root.providerColor(modelData)
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.providerText(modelData)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: root.providerColor(modelData)
                    }
                }
            }
        }
    }

    StyledPopup {
        id: usagePopup
        hoverTarget: root

        ColumnLayout {
            implicitWidth: 340
            spacing: 8

            GridLayout {
                columns: 1
                columnSpacing: 4
                rowSpacing: 4
                Layout.fillWidth: true

                Repeater {
                    model: root.providers

                    delegate: UsageProviderCard {
                        required property var modelData
                        provider: modelData
                        accentColor: root.usageColor
                    }
                }
            }

            StyledText {
                visible: root.providers.length === 0
                Layout.fillWidth: true
                text: Translation.tr("No usage providers selected")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
