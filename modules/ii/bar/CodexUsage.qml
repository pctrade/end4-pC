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
    readonly property color overallColor: root.overallRemainingPercent < 0
        ? Appearance.colors.colOnLayer1
        : root.overallRemainingPercent <= 10
            ? Appearance.m3colors.m3error
            : root.overallRemainingPercent <= 25
                ? Appearance.colors.colTertiary
                : (root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1)

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
        return service.available
            ? `${service.remainingPercent}%`
            : service.loading
                ? "..."
                : "--"
    }

    function providerWindows(provider) {
        const windows = provider.service.windows
        if (Array.isArray(windows) && windows.length > 0)
            return windows
        if (provider.service.available) {
            return [{
                id: "usage",
                label: Translation.tr("Usage"),
                remainingPercent: provider.service.remainingPercent,
                resetAt: provider.service.resetAt,
            }]
        }
        return []
    }

    function colorForRemaining(remainingPercent) {
        if (remainingPercent < 0)
            return Appearance.colors.colOnLayer1
        if (remainingPercent <= 10)
            return Appearance.m3colors.m3error
        if (remainingPercent <= 25)
            return Appearance.colors.colTertiary
        return root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
    }

    function providerColor(provider) {
        return root.colorForRemaining(provider.service.available
            ? provider.service.remainingPercent
            : -1)
    }

    function windowColor(provider, window) {
        return root.colorForRemaining(provider.service.available
            ? Number(window.remainingPercent)
            : -1)
    }

    function windowResetText(provider, window) {
        if (!window.resetAt || !provider.service.formatReset)
            return Translation.tr("Reset unavailable")
        return provider.service.formatReset(Number(window.resetAt), provider.service.clockSeconds)
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

        component UsageCard: Rectangle {
            id: card

            required property var provider
            readonly property var service: provider.service
            readonly property color valueColor: service.available
                ? root.providerColor(card.provider)
                : Appearance.colors.colOnSurfaceVariant

            Layout.fillWidth: true
            implicitWidth: cardContent.implicitWidth + 20
            implicitHeight: cardContent.implicitHeight + 20
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: card.provider.name
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    CustomIcon {
                        Layout.preferredWidth: Appearance.font.pixelSize.normal
                        Layout.preferredHeight: Appearance.font.pixelSize.normal
                        source: card.provider.icon
                        colorize: true
                        smooth: true
                        color: card.valueColor
                    }
                }

                Repeater {
                    model: root.providerWindows(card.provider)

                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: `${modelData.remainingPercent}%`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: root.windowColor(card.provider, modelData)
                            }
                        }

                        StyledProgressBar {
                            Layout.fillWidth: true
                            value: Math.max(0, Math.min(1, Number(modelData.remainingPercent) / 100))
                            highlightColor: root.windowColor(card.provider, modelData)
                            trackColor: Appearance.colors.colSurfaceContainerHighest
                            valueBarHeight: 5
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: Translation.tr("Remaining")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.7
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.windowResetText(card.provider, modelData)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnSurfaceVariant
                                opacity: 0.7
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.providerWindows(card.provider).length === 0
                    text: card.service.loading
                        ? Translation.tr("Loading")
                        : Translation.tr("Unavailable")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.7
                }

            }
        }

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

                    delegate: UsageCard {
                        required property var modelData
                        provider: modelData
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
