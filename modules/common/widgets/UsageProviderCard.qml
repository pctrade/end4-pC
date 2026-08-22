pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    required property var provider
    property color accentColor: Appearance.colors.colPrimary
    property color unavailableColor: Appearance.colors.colOnSurfaceVariant
    property int contentMargin: 10
    property real progressBarHeight: 5
    property bool horizontalTwoWindows: false

    readonly property var service: root.provider?.service
    readonly property var rawWindows: root.service?.windows ?? []
    readonly property bool available: root.service?.available ?? false
    readonly property bool loading: root.service?.loading ?? false
    readonly property int remainingPercent: root.service?.remainingPercent ?? -1
    readonly property int resetAt: root.service?.resetAt ?? 0
    readonly property int clockSeconds: root.service?.clockSeconds ?? 0
    readonly property var windows: UsageDisplay.windowEntries(
        root.rawWindows,
        root.available,
        root.remainingPercent,
        root.resetAt,
    )
    readonly property color valueColor: UsageDisplay.colorForRemaining(
        root.available ? root.remainingPercent : -1,
        root.accentColor,
        root.unavailableColor,
    )
    readonly property bool useHorizontalWindows: root.horizontalTwoWindows && root.windows.length === 2

    Layout.fillWidth: true
    implicitWidth: cardContent.implicitWidth + root.contentMargin * 2
    implicitHeight: cardContent.implicitHeight + root.contentMargin * 2
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh

    component UsageWindow: ColumnLayout {
        id: usageWindow

        property var usage: null
        readonly property string label: String(usage?.label ?? "")
        readonly property int usageRemainingPercent: Number(usage?.remainingPercent ?? 0)
        readonly property int usageResetAt: Number(usage?.resetAt ?? 0)
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: usageWindow.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
            }

            StyledText {
                text: `${usageWindow.usageRemainingPercent}%`
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: UsageDisplay.colorForRemaining(
                    root.available ? usageWindow.usageRemainingPercent : -1,
                    root.accentColor,
                    root.unavailableColor,
                )
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true
            value: Math.max(0, Math.min(1, usageWindow.usageRemainingPercent / 100))
            highlightColor: UsageDisplay.colorForRemaining(
                root.available ? usageWindow.usageRemainingPercent : -1,
                root.accentColor,
                root.unavailableColor,
            )
            trackColor: Appearance.colors.colSurfaceContainerHighest
            valueBarHeight: root.progressBarHeight
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: Translation.tr("Reset")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.7
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: UsageDisplay.resetText(root.service, usageWindow.usageResetAt, root.clockSeconds)
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        id: cardContent
        anchors.fill: parent
        anchors.margins: root.contentMargin
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.provider?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
            }

            CustomIcon {
                Layout.preferredWidth: Appearance.font.pixelSize.normal
                Layout.preferredHeight: Appearance.font.pixelSize.normal
                source: root.provider?.icon ?? ""
                colorize: true
                smooth: true
                color: root.valueColor
            }
        }

        ColumnLayout {
            visible: root.windows.length > 0 && !root.useHorizontalWindows
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.windows

                delegate: UsageWindow {
                    required property var modelData
                    usage: modelData
                }
            }
        }

        RowLayout {
            visible: root.useHorizontalWindows
            Layout.fillWidth: true
            spacing: 12

            UsageWindow {
                usage: root.windows[0]
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Appearance.colors.colOutlineVariant
                opacity: 0.5
            }

            UsageWindow {
                usage: root.windows[1]
            }
        }

        StyledText {
            visible: root.windows.length === 0
            text: root.loading ? Translation.tr("Loading") : Translation.tr("Unavailable")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
            opacity: 0.7
        }
    }
}
